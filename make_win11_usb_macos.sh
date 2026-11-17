#!/usr/bin/env bash
# Création d'une clé USB bootable Windows 11 (UEFI, FAT32) à partir d'un ISO — macOS
#
# Prérequis : wimlib   ->   brew install wimlib
#             (diskutil, hdiutil, find, cp... sont fournis par macOS)
# Usage     : cd <dossier contenant l'ISO> && sudo bash make_win11_usb_macos.sh
#
# Compatible bash 3.2 (version livrée avec macOS).

# ==== FONCTIONS ====
rouge=$'\033[31m'; vert=$'\033[32m'; jaune=$'\033[33m'; cyan=$'\033[36m'; raz=$'\033[0m'
info()   { printf '%s%s%s\n' "$cyan"  "$*" "$raz"; }
ok()     { printf '%s%s%s\n' "$vert"  "$*" "$raz"; }
avert()  { printf '%s%s%s\n' "$jaune" "$*" "$raz"; }
erreur() { printf '%s%s%s\n' "$rouge" "$*" "$raz" >&2; }

# ---- Internationalisation : menus dans la langue du système (repli : anglais) ----
# Forcer une langue : WIN11_LANG=en sudo -E bash ...   Ajouter une langue : ajouter une fonction msg_xx.
LANGUE_UI="en"
msg() {
    local f
    if f=$("msg_$LANGUE_UI" "$1" 2>/dev/null) && [ -n "$f" ]; then :; else f=$(msg_en "$1"); fi
    shift
    # shellcheck disable=SC2059
    printf "$f" "$@"
}
choisir_langue_ui() {
    local l=${WIN11_LANG:-}
    [ -n "$l" ] || l=$(langue_systeme)
    l=$(printf '%s' "$l" | tr 'A-Z_' 'a-z-')
    l=${l%%-*}
    if [ "$(type -t "msg_$l")" = "function" ]; then LANGUE_UI="$l"; else LANGUE_UI="en"; fi
}
msg_fr() {
    case "$1" in
        need_sudo) printf '%s' "Lance le script avec sudo : sudo bash %s" ;;
        tools_missing) printf '%s' "Outils manquants :%s" ;;
        install_wimlib) printf '%s' "Installe wimlib (sans sudo) : brew install wimlib" ;;
        no_iso) printf '%s' "Aucun fichier .iso trouvé dans %s." ;;
        ask_no_iso) printf '%s' "T pour télécharger l'ISO depuis Microsoft, ou chemin complet de l'ISO : " ;;
        isos_found) printf '%s' "ISO trouvés dans %s :" ;;
        menu_download) printf '%s' "  [T] Télécharger un ISO Windows 11 depuis Microsoft" ;;
        ask_iso) printf '%s' "Numéro de l'ISO à utiliser (ou T) : " ;;
        bad_choice) printf '%s' "Choix invalide." ;;
        iso_selected) printf '%s' "ISO sélectionné : %s" ;;
        iso_missing) printf '%s' "ISO introuvable." ;;
        no_usb) printf '%s' "Aucune clé USB détectée." ;;
        usb_found) printf '%s' "Clés USB détectées :" ;;
        ask_usb) printf '%s' "Numéro de la clé USB à EFFACER : " ;;
        not_in_list) printf '%s' "Ce numéro n'est pas dans la liste." ;;
        internal_disk) printf '%s' "%s est un disque interne : abandon." ;;
        root_disk) printf '%s' "%s contient le système de fichiers racine : abandon." ;;
        too_small) printf '%s' "Clé trop petite : %s Go pour un ISO de %s Go." ;;
        confirm_erase) printf '%s' "Confirmer l'effacement de '%s' (%s) ? (O/N) " ;;
        preparing) printf '%s' "Préparation de la clé (%s)..." ;;
        partition_fail) printf '%s' "Échec du partitionnement de %s." ;;
        no_mountpoint) printf '%s' "Impossible de trouver le point de montage de la clé." ;;
        part_missing) printf '%s' "Partition introuvable après le partitionnement." ;;
        mkfs_fail) printf '%s' "Échec du formatage FAT32 de %s." ;;
        mount_fail) printf '%s' "Impossible de monter %s." ;;
        iso_mount_fail_mac) printf '%s' "Impossible de monter l'ISO." ;;
        iso_mount_fail_linux) printf '%s' "Impossible de monter l'ISO (essaie : sudo modprobe udf)." ;;
        sources_missing) printf '%s' "Dossier 'sources' introuvable dans l'ISO monté : ISO invalide ou monté dans un format incomplet." ;;
        copying) printf '%s' "Copie des fichiers..." ;;
        copy_err_file) printf '%s' "ERREUR de copie : %s" ;;
        copy_err) printf '%s' "La copie a rencontré une erreur. Voir %s" ;;
        bootwim_missing) printf '%s' "sources/boot.wim absent de la clé : copie incomplète. Voir %s" ;;
        write_ok) printf '%s' "Écriture sur la clé : OK" ;;
        write_fail) printf '%s' "Écriture impossible sur %s" ;;
        splitting) printf '%s' "Découpage de install.wim..." ;;
        split_done) printf '%s' "Découpage terminé." ;;
        split_fail) printf '%s' "Échec de wimlib (code %s). Dernières lignes de %s :" ;;
        esd_copy) printf '%s' "install.esd détecté : copie directe." ;;
        esd_fail) printf '%s' "Échec de la copie de install.esd" ;;
        no_image) printf '%s' "Ni install.wim ni install.esd trouvé dans l'ISO." ;;
        done_mac) printf '%s' "Terminé : clé prête sur %s" ;;
        logs) printf '%s' "Journaux : %s, %s (si découpage) et %s" ;;
        eject_hint) printf '%s' "Pour l'éjecter proprement : diskutil eject %s" ;;
        syncing) printf '%s' "Synchronisation de la clé (ne la retire pas encore)..." ;;
        umount_fail) printf '%s' "Impossible de démonter la clé : ne la retire pas." ;;
        done_linux) printf '%s' "Terminé : clé prête (%s). Tu peux la retirer." ;;
        bar_size) printf '%s' "%d Mo / %d Mo" ;;
        bar_speed) printf '%s' "%s Mo/s" ;;
        copy_line_speed) printf '%s' "  — %s Mo/s en moyenne" ;;
        copy_summary) printf '%s' "Copie terminée : %s Mo en %s — %s Mo/s en moyenne." ;;
        split_summary) printf '%s' "Découpage : %s Mo en %s — %s Mo/s." ;;
        total_speed) printf '%s' "Écriture totale sur la clé : %s Go en %s — %s Mo/s (cache d'écriture vidé)." ;;
        slow_drive) printf '%s' "Clé lente (%s Mo/s) : une clé USB 3.x sur un port USB 3 irait bien plus vite." ;;
        curl_needed) printf '%s' "curl est nécessaire pour télécharger l'ISO." ;;
        dl_title) printf '%s' "Téléchargement de l'ISO Windows 11 depuis Microsoft" ;;
        ask_lang) printf '%s' "Langue de la page Microsoft [%s] (Entrée pour valider, ou autre code, ex. en-us) : " ;;
        bad_code) printf '%s' "Code invalide : langue détectée conservée (%s)." ;;
        official_page) printf '%s' "Page officielle : %s" ;;
        no_fixed_link) printf '%s' "Microsoft ne publie pas de lien fixe : le lien direct est généré à chaque téléchargement\net n'est valable que 24 heures." ;;
        step1) printf '%s' "  1. Ouvre la page officielle ci-dessus dans ton navigateur." ;;
        step2) printf '%s' "  2. Dans « Télécharger l'image disque Windows 11 (ISO) pour les appareils x64 », choisis l'ISO\n     multi-éditions, puis la langue du produit (ta langue système : %s) et clique sur « Confirmer »." ;;
        step3) printf '%s' "  3. Clic droit sur le bouton de téléchargement 64 bits > « Copier l'adresse du lien » : le script la détecte tout seul.\n     Colle le lien ENTIER, y compris ce qui suit « .iso? » : c'est ce qui l'autorise." ;;
        clip_unreadable) printf '%s' "Presse-papiers illisible ici (outil absent) : colle le lien à la main." ;;
        ask_url) printf '%s' "Colle ici l'URL du lien (https://...microsoft.com/....iso) : " ;;
        url_refused) printf '%s' "URL refusée : elle doit être en https, sur un domaine *.microsoft.com, et son chemin doit se terminer par .iso." ;;
        file_exists) printf '%s' "%s existe déjà dans %s : utilisation du fichier existant." ;;
        querying) printf '%s' "Interrogation du serveur Microsoft..." ;;
        size_unknown) printf '%s' "Taille de l'ISO non communiquée : hypothèse de %s Go." ;;
        http_err) printf '%s' "Le serveur Microsoft a répondu HTTP %s (000 = pas de réponse) : lien expiré, incomplet (sans la partie après « .iso? ») ou réseau injoignable.\nGénère un nouveau lien sur la page officielle." ;;
        size_line) printf '%s' "  Taille de l'ISO     : %s Go" ;;
        need_line) printf '%s' "  Espace nécessaire   : %s Go (ISO + marge ; pas de copie temporaire pour le découpage)" ;;
        free_line) printf '%s' "  Espace libre        : %s Go (%s)" ;;
        insufficient) printf '%s' "Espace disque insuffisant : il manque %s Go." ;;
        confirm_dl) printf '%s' "Lancer le téléchargement vers %s ? (O/N) " ;;
        dl_running) printf '%s' "Téléchargement (reprise possible si interrompu)..." ;;
        dl_fail) printf '%s' "Échec du téléchargement (lien expiré ou réseau ?). Génère un nouveau lien sur la page Microsoft." ;;
        dl_done) printf '%s' "Téléchargement terminé : %s" ;;
        dl_speed) printf '%s' "Vitesse de téléchargement moyenne : %s Mo/s" ;;
        sha_calc) printf '%s' "Calcul de l'empreinte SHA-256 (quelques minutes)..." ;;
        sha_ok) printf '%s' "Empreinte conforme à celle publiée par Microsoft (%s)." ;;
        sha_unknown) printf '%s' "Empreinte non reconnue (version ou langue absente de iso_hashes.txt, ou fichier altéré)." ;;
        sha_computed) printf '%s' "SHA-256 calculé : %s" ;;
        ask_sha) printf '%s' "Empreinte SHA-256 affichée par Microsoft pour cette langue (Entrée pour ignorer) : " ;;
        sha_match) printf '%s' "Empreinte conforme." ;;
        sha_bad) printf '%s' "Empreinte différente : fichier corrompu ou incomplet. Supprime-le et recommence." ;;
        wait_link) printf '%s' "En attente du lien : clique sur « Copier l'adresse du lien » dans le navigateur.\n(Entrée = coller le lien à la main)" ;;
        clip_found) printf '%s' "Lien détecté dans le presse-papiers : %s. L'utiliser ? (O/n) " ;;
        wait_timeout) printf '%s' "Délai dépassé (5 minutes) : colle le lien à la main." ;;
        published_found) printf '%s' "Lien déjà généré (iso_links.txt) : build %s, encore valable %s. L'utiliser ? (O/n) " ;;
        published_dead) printf '%s' "Ce lien publié ne répond pas (HTTP %s) : retour à la méthode manuelle." ;;
        *) return 1 ;;
    esac
}
msg_en() {
    case "$1" in
        need_sudo) printf '%s' "Run the script with sudo: sudo bash %s" ;;
        tools_missing) printf '%s' "Missing tools:%s" ;;
        install_wimlib) printf '%s' "Install wimlib (without sudo): brew install wimlib" ;;
        no_iso) printf '%s' "No .iso file found in %s." ;;
        ask_no_iso) printf '%s' "T to download the ISO from Microsoft, or the full path of the ISO: " ;;
        isos_found) printf '%s' "ISO files found in %s:" ;;
        menu_download) printf '%s' "  [T] Download a Windows 11 ISO from Microsoft" ;;
        ask_iso) printf '%s' "Number of the ISO to use (or T): " ;;
        bad_choice) printf '%s' "Invalid choice." ;;
        iso_selected) printf '%s' "Selected ISO: %s" ;;
        iso_missing) printf '%s' "ISO not found." ;;
        no_usb) printf '%s' "No USB drive detected." ;;
        usb_found) printf '%s' "USB drives detected:" ;;
        ask_usb) printf '%s' "Number of the USB drive to ERASE: " ;;
        not_in_list) printf '%s' "This number is not in the list." ;;
        internal_disk) printf '%s' "%s is an internal disk: aborting." ;;
        root_disk) printf '%s' "%s holds the root filesystem: aborting." ;;
        too_small) printf '%s' "USB drive too small: %s GB for a %s GB ISO." ;;
        confirm_erase) printf '%s' "Confirm erasing '%s' (%s)? (Y/N) " ;;
        preparing) printf '%s' "Preparing the USB drive (%s)..." ;;
        partition_fail) printf '%s' "Partitioning of %s failed." ;;
        no_mountpoint) printf '%s' "Could not find the drive's mount point." ;;
        part_missing) printf '%s' "Partition not found after partitioning." ;;
        mkfs_fail) printf '%s' "FAT32 formatting of %s failed." ;;
        mount_fail) printf '%s' "Could not mount %s." ;;
        iso_mount_fail_mac) printf '%s' "Could not mount the ISO." ;;
        iso_mount_fail_linux) printf '%s' "Could not mount the ISO (try: sudo modprobe udf)." ;;
        sources_missing) printf '%s' "'sources' folder not found in the mounted ISO: invalid ISO, or mounted in an incomplete format." ;;
        copying) printf '%s' "Copying files..." ;;
        copy_err_file) printf '%s' "COPY ERROR: %s" ;;
        copy_err) printf '%s' "The copy hit an error. See %s" ;;
        bootwim_missing) printf '%s' "sources/boot.wim is missing from the drive: incomplete copy. See %s" ;;
        write_ok) printf '%s' "Write test on the drive: OK" ;;
        write_fail) printf '%s' "Cannot write to %s" ;;
        splitting) printf '%s' "Splitting install.wim..." ;;
        split_done) printf '%s' "Split complete." ;;
        split_fail) printf '%s' "wimlib failed (code %s). Last lines of %s:" ;;
        esd_copy) printf '%s' "install.esd detected: copying it directly." ;;
        esd_fail) printf '%s' "Failed to copy install.esd" ;;
        no_image) printf '%s' "Neither install.wim nor install.esd found in the ISO." ;;
        done_mac) printf '%s' "Done: the drive is ready at %s" ;;
        logs) printf '%s' "Logs: %s, %s (if split) and %s" ;;
        eject_hint) printf '%s' "To eject it safely: diskutil eject %s" ;;
        syncing) printf '%s' "Syncing the drive (do not remove it yet)..." ;;
        umount_fail) printf '%s' "Could not unmount the drive: do not remove it." ;;
        done_linux) printf '%s' "Done: the drive is ready (%s). You can remove it." ;;
        bar_size) printf '%s' "%d MB / %d MB" ;;
        bar_speed) printf '%s' "%s MB/s" ;;
        copy_line_speed) printf '%s' "  — %s MB/s average" ;;
        copy_summary) printf '%s' "Copy finished: %s MB in %s — %s MB/s on average." ;;
        split_summary) printf '%s' "Split: %s MB in %s — %s MB/s." ;;
        total_speed) printf '%s' "Total written to the drive: %s GB in %s — %s MB/s (write cache flushed)." ;;
        slow_drive) printf '%s' "Slow drive (%s MB/s): a USB 3.x drive in a USB 3 port would be much faster." ;;
        curl_needed) printf '%s' "curl is required to download the ISO." ;;
        dl_title) printf '%s' "Downloading the Windows 11 ISO from Microsoft" ;;
        ask_lang) printf '%s' "Microsoft page language [%s] (Enter to accept, or another code, e.g. fr-fr): " ;;
        bad_code) printf '%s' "Invalid code: keeping the detected language (%s)." ;;
        official_page) printf '%s' "Official page: %s" ;;
        no_fixed_link) printf '%s' "Microsoft does not publish a fixed link: the direct link is generated for each download\nand is only valid for 24 hours." ;;
        step1) printf '%s' "  1. Open the official page above in your browser." ;;
        step2) printf '%s' "  2. Under \"Download Windows 11 Disk Image (ISO) for x64 devices\", choose the multi-edition\n     ISO, then the product language (your system language: %s) and click \"Confirm\"." ;;
        step3) printf '%s' "  3. Right-click the 64-bit download button > \"Copy link address\": the script detects it by itself.\n     Paste the WHOLE link, including what follows \".iso?\": that part is what authorizes it." ;;
        clip_unreadable) printf '%s' "Clipboard not readable here (tool missing): paste the link by hand." ;;
        ask_url) printf '%s' "Paste the link URL here (https://...microsoft.com/....iso): " ;;
        url_refused) printf '%s' "URL rejected: it must be https, on a *.microsoft.com domain, and its path must end with .iso." ;;
        file_exists) printf '%s' "%s already exists in %s: using the existing file." ;;
        querying) printf '%s' "Querying the Microsoft server..." ;;
        size_unknown) printf '%s' "ISO size not provided by the server: assuming %s GB." ;;
        http_err) printf '%s' "The Microsoft server answered HTTP %s (000 = no answer): link expired, incomplete (missing the part after \".iso?\") or network unreachable.\nGenerate a new link on the official page." ;;
        size_line) printf '%s' "  ISO size            : %s GB" ;;
        need_line) printf '%s' "  Space needed        : %s GB (ISO + margin; no temporary copy for the split)" ;;
        free_line) printf '%s' "  Free space          : %s GB (%s)" ;;
        insufficient) printf '%s' "Not enough disk space: %s GB missing." ;;
        confirm_dl) printf '%s' "Start the download to %s? (Y/N) " ;;
        dl_running) printf '%s' "Downloading (resumable if interrupted)..." ;;
        dl_fail) printf '%s' "Download failed (expired link or network?). Generate a new link on the Microsoft page." ;;
        dl_done) printf '%s' "Download finished: %s" ;;
        dl_speed) printf '%s' "Average download speed: %s MB/s" ;;
        sha_calc) printf '%s' "Computing the SHA-256 hash (a few minutes)..." ;;
        sha_ok) printf '%s' "Hash matches the one published by Microsoft (%s)." ;;
        sha_unknown) printf '%s' "Hash not recognized (version or language missing from iso_hashes.txt, or altered file)." ;;
        sha_computed) printf '%s' "Computed SHA-256: %s" ;;
        ask_sha) printf '%s' "SHA-256 hash shown by Microsoft for this language (Enter to skip): " ;;
        sha_match) printf '%s' "Hash matches." ;;
        sha_bad) printf '%s' "Hash differs: corrupted or incomplete file. Delete it and start over." ;;
        wait_link) printf '%s' "Waiting for the link: click \"Copy link address\" in the browser.\n(Enter = paste the link by hand)" ;;
        clip_found) printf '%s' "Link detected in the clipboard: %s. Use it? (Y/n) " ;;
        wait_timeout) printf '%s' "Timed out (5 minutes): paste the link by hand." ;;
        published_found) printf '%s' "Ready-made link found (iso_links.txt): build %s, still valid for %s. Use it? (Y/n) " ;;
        published_dead) printf '%s' "That published link does not answer (HTTP %s): falling back to the manual method." ;;
        *) return 1 ;;
    esac
}

# Vitesse en Mo/s (1 décimale) : $1 = octets, $2 = secondes
vitesse() { awk -v b="$1" -v s="$2" 'BEGIN{ if (s < 1) s = 1; printf "%.1f", b / 1048576 / s }'; }
# Durée « m:ss » à partir de secondes
duree() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }
# Durée restante « H h MM min » à partir de secondes
duree_restante() { printf '%d h %02d min' $(($1 / 3600)) $(($1 % 3600 / 60)); }
# Seuil (Mo/s) en dessous duquel la clé est signalée comme lente
SEUIL_LENT=10

# Taille cumulée (octets) des morceaux install*.swm déjà écrits dans le dossier $1
taille_swm() {
    local s=0 f n
    for f in "$1"/install*.swm; do
        if [ -f "$f" ]; then
            n=$(wc -c < "$f")
            s=$((s + n))
        fi
    done
    echo "$s"
}

# Barre de progression avec vitesse d'écriture : $1 = octets faits, $2 = octets totaux
# (la vitesse est recalculée toutes les 2 s ; initialiser avec barre_init)
barre_init() { b_t=$SECONDS; b_fait=0; b_vit="..."; }
barre() {
    local fait=$1 total=$2 pct plein dt
    [ "$total" -gt 0 ] || total=1
    dt=$((SECONDS - b_t))
    if [ "$dt" -ge 2 ]; then
        b_vit=$(vitesse $((fait - b_fait)) "$dt")
        b_t=$SECONDS
        b_fait=$fait
    fi
    pct=$(( fait * 100 / total ))
    [ "$pct" -gt 99 ] && pct=99
    plein=$(( pct * 40 / 100 ))
    printf '\r[%s%s] %3d%%  %s  %s   ' \
        "$(printf '%*s' "$plein" '' | tr ' ' '#')" \
        "$(printf '%*s' $((40 - plein)) '' | tr ' ' '.')" \
        "$pct" "$(msg bar_size $((fait / 1048576)) $((total / 1048576)))" "$(msg bar_speed "$b_vit")"
}

# Copie tout le contenu de $1 vers $2, sauf install.wim et autorun.inf (insensible à la casse).
# Affiche chaque fichier copié avec la vitesse moyenne d'écriture, puis un résumé.
copier_fichiers() {
    local src=$1 dst=$2 total n=0 f d rel reld octets=0 t0 dt taille
    find "$src" -type d -print0 | while IFS= read -r -d '' d; do
        reld=${d#"$src"}
        mkdir -p "$dst/$reld"
    done
    total=$(find "$src" -type f ! -iname 'install.wim' ! -iname 'autorun.inf' | wc -l | tr -d ' ')
    t0=$SECONDS
    while IFS= read -r -d '' f; do
        rel=${f#"$src"/}
        n=$((n + 1))
        dt=$((SECONDS - t0))
        if [ "$dt" -ge 2 ]; then
            printf '[%d/%d] %s%s\n' "$n" "$total" "$rel" "$(msg copy_line_speed "$(vitesse "$octets" "$dt")")"
        else
            printf '[%d/%d] %s\n' "$n" "$total" "$rel"
        fi
        if ! cp "$f" "$dst/$rel"; then
            msg copy_err_file "$rel"; printf '\n'
            return 1
        fi
        taille=$(wc -c < "$f")
        octets=$((octets + taille))
    done < <(find "$src" -type f ! -iname 'install.wim' ! -iname 'autorun.inf' -print0)
    dt=$((SECONDS - t0))
    msg copy_summary $((octets / 1048576)) "$(duree "$dt")" "$(vitesse "$octets" "$dt")"; printf '\n'
    return 0
}

# Informations sur un disque macOS : $1 = /dev/diskN, $2 = nom | taille | octets
info_disque() {
    case "$2" in
        nom)    diskutil info "$1" | sed -En 's|^ *Device / Media Name: *||p' | head -1 | tr -cd '[:print:]' ;;
        taille) diskutil info "$1" | sed -En 's/^ *(Disk|Total) Size: *([^(]*)\(.*/\2/p' | head -1 ;;
        octets) diskutil info "$1" | sed -En 's/^ *(Disk|Total) Size:.*\(([0-9]+) Bytes\).*/\2/p' | head -1 ;;
    esac
}
# ---- Téléchargement de l'ISO depuis Microsoft ----
URL_MICROSOFT="https://www.microsoft.com/fr-fr/software-download/windows11"
URL_HASHES="https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/iso_hashes.txt"
URL_LIENS="https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/iso_links.txt"
VALIDITE_MIN_S=1800   # un lien publié doit rester valable au moins 30 minutes
MARGE_OCTETS=$((512 * 1024 * 1024))

# Espace libre (octets) du système de fichiers qui contient le dossier $1
espace_libre() {
    local ko
    ko=$(df -Pk "$1" | awk 'NR==2 {print $4}')
    echo $((ko * 1024))
}

# Octets -> Go avec 2 décimales
en_go() { awk -v s="$1" 'BEGIN{printf "%.2f", s/1073741824}'; }

# N'accepte qu'une URL https d'un domaine *.microsoft.com dont le chemin se termine par .iso
url_valide() {
    local hote chemin
    case "$1" in https://*) ;; *) return 1 ;; esac
    hote=${1#https://}; hote=${hote%%/*}
    case "$hote" in ''|*[!A-Za-z0-9.-]*) return 1 ;; esac
    case "$hote" in *.microsoft.com) ;; *) return 1 ;; esac
    chemin=${1#https://"$hote"}; chemin=${chemin%%\?*}
    case "$chemin" in *.iso|*.ISO) return 0 ;; esac
    return 1
}

# Nom du fichier ISO d'après l'URL (caractères sûrs uniquement)
nom_fichier_url() {
    local chemin n
    chemin=${1%%\?*}
    n=${chemin##*/}
    n=$(printf '%s' "$n" | tr -cd 'A-Za-z0-9._-')
    [ -n "$n" ] || n="Win11.iso"
    echo "$n"
}

# Taille (octets) annoncée par le serveur pour l'URL $1, 0 si inconnue
taille_distante() {
    local sortie code t
    sortie=$(curl -sSIL -m 30 -w '\nCODEHTTP:%{http_code}\n' "$1" 2>/dev/null | tr -d '\r')
    code=$(printf '%s\n' "$sortie" | sed -n 's/^CODEHTTP://p' | tail -1)
    case "$code" in 2??) ;; *) echo 0; return ;; esac
    t=$(printf '%s\n' "$sortie" | awk 'tolower($1)=="content-length:" {print $2}' | tail -1)
    case "$t" in ''|*[!0-9]*) echo 0 ;; *) echo "$t" ;; esac
}

# Compare l'empreinte SHA-256 du fichier $1 avec $2 (insensible à la casse et aux espaces)
verifier_sha256() {
    local calc attendu
    if command -v sha256sum >/dev/null 2>&1; then
        calc=$(sha256sum "$1" | awk '{print $1}')
    else
        calc=$(shasum -a 256 "$1" | awk '{print $1}')
    fi
    calc=$(printf '%s' "$calc" | tr 'A-F' 'a-f')
    attendu=$(printf '%s' "$2" | tr -d '[:space:]' | tr 'A-F' 'a-f')
    [ "$calc" = "$attendu" ]
}

# Normalise un code de langue système (fr_FR.UTF-8, fr-FR, zh-Hans-CN, fr...) en « xx-xx » minuscule
normaliser_langue() {
    local l=${1%%.*}
    l=${l%%@*}
    l=$(printf '%s' "$l" | tr 'A-Z_' 'a-z-')
    case "$l" in ''|c|posix) echo "en-us"; return ;; esac
    case "$l" in
        *-*) echo "${l%%-*}-${l##*-}" ;;
        en) echo "en-us" ;;
        pt) echo "pt-pt" ;;
        zh) echo "zh-cn" ;;
        ja) echo "ja-jp" ;;
        ko) echo "ko-kr" ;;
        cs) echo "cs-cz" ;;
        da) echo "da-dk" ;;
        el) echo "el-gr" ;;
        sv) echo "sv-se" ;;
        uk) echo "uk-ua" ;;
        he) echo "he-il" ;;
        ar) echo "ar-sa" ;;
        et) echo "et-ee" ;;
        sl) echo "sl-si" ;;
        nb|no) echo "nb-no" ;;
        *) echo "$l-$l" ;;
    esac
}

# Langue du système (macOS) : première langue de la liste des préférences de l'utilisateur
langue_systeme() {
    local l=""
    if [ -n "${SUDO_USER:-}" ]; then
        l=$(sudo -u "$SUDO_USER" defaults read -g AppleLanguages 2>/dev/null | sed -n '2p' | tr -d ' ",')
    else
        l=$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2p' | tr -d ' ",')
    fi
    [ -n "$l" ] || l="${LC_ALL:-${LANG:-}}"
    normaliser_langue "$l"
}

# Code HTTP final renvoyé par le serveur pour l'URL $1 (000 = pas de réponse)
code_http() {
    local c
    c=$(curl -sIL -m 30 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null)
    echo "${c:-000}"
}

# Empreinte SHA-256 (hexadécimal) du fichier $1
calculer_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Ouvre l'URL $1 dans le navigateur par défaut de l'utilisateur (échec silencieux)
ouvrir_page() {
    if [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" open "$1" >/dev/null 2>&1
    else
        open "$1" >/dev/null 2>&1
    fi
    return 0
}

# 0 si le presse-papiers est lisible
presse_papiers_disponible() { command -v pbpaste >/dev/null 2>&1; }

# Contenu du presse-papiers de l'utilisateur
lire_presse_papiers() {
    if [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" pbpaste 2>/dev/null
    else
        pbpaste 2>/dev/null
    fi
}

# Cherche dans iso_links.txt (GitHub) un lien de la langue $1 encore valable assez longtemps.
# Affiche « build;expiration;url » (rien si aucun). Format du fichier : langue;build;expiration;url
lien_publie() {
    local now
    now=$(date +%s)
    curl -fsSL -m 15 "$URL_LIENS" 2>/dev/null | tr -d '\r' | grep -v '^[[:space:]]*#' |
        awk -F';' -v l="$1" -v now="$now" -v min="$VALIDITE_MIN_S" \
            'NF >= 4 && tolower($1) == l && ($3 + 0) - now >= min {print $2 ";" $3 ";" $4; exit}'
}

# Attend que l'utilisateur copie le lien dans le presse-papiers. Renseigne $url si un lien valide est confirmé.
# Entrée = abandonner l'attente (le lien sera alors collé à la main). Délai maximal : 5 minutes.
attendre_lien() {
    local dernier="" c saisie rep nom rc i=0 max=300
    msg wait_link; printf '\n'
    while [ "$i" -lt "$max" ]; do
        c=$(lire_presse_papiers 2>/dev/null | head -c 8192 | tr -d '[:space:]"')
        if [ -n "$c" ] && [ "$c" != "$dernier" ] && url_valide "$c"; then
            nom=$(nom_fichier_url "$c")
            read -r -p "$(msg clip_found "$nom")" rep
            case "$rep" in
                [nN]*) dernier="$c" ;;
                *) url="$c"; return 0 ;;
            esac
        fi
        read -r -t 1 saisie
        rc=$?
        if [ "$rc" -eq 0 ]; then
            saisie=$(printf '%s' "$saisie" | tr -d '[:space:]"')
            [ -n "$saisie" ] && url="$saisie"
            return 0
        elif [ "$rc" -le 128 ]; then
            return 0          # fin de saisie : on passe à la saisie manuelle
        fi
        i=$((i + 1))
    done
    avert "$(msg wait_timeout)"
    return 0
}

# Méthode manuelle : ouvre la page Microsoft ($1), explique les étapes ($2 = langue) puis attend le lien.
# Renseigne $url (variable de l'appelant).
obtenir_lien_manuel() {
    local page=$1 loc=$2
    echo "$(msg official_page "$page")"
    msg no_fixed_link; printf '\n'
    msg step1; printf '\n'
    msg step2 "$loc"; printf '\n'
    msg step3; printf '\n'
    ouvrir_page "$page"
    url=""
    if presse_papiers_disponible; then
        attendre_lien
    else
        avert "$(msg clip_unreadable)"
    fi
    if [ -z "$url" ]; then
        read -r -p "$(msg ask_url)" url
        url=$(printf '%s' "$url" | tr -d '[:space:]"')
    fi
    return 0
}

# Télécharge l'ISO depuis Microsoft dans $dossier. Renseigne la variable globale $iso.
# Retourne 1 en cas d'abandon ou d'échec.
telecharger_depuis_microsoft() {
    local url nom taille besoin libre rep attendu code calc reconnu loc page publie origine="" b e t0 dt
    if ! command -v curl >/dev/null 2>&1; then
        erreur "$(msg curl_needed)"
        return 1
    fi
    info "$(msg dl_title)"
    loc=$(langue_systeme)
    read -r -p "$(msg ask_lang "$loc")" rep
    rep=$(printf '%s' "$rep" | tr 'A-Z_' 'a-z-' | tr -d '[:space:]')
    if [ -n "$rep" ]; then
        if printf '%s' "$rep" | grep -Eq '^[a-z]{2,3}(-[a-z0-9]{2,4}){1,2}$'; then
            loc="$rep"
        else
            avert "$(msg bad_code "$loc")"
        fi
    fi
    page="https://www.microsoft.com/$loc/software-download/windows11"
    url=""

    # 1. Lien déjà généré par la routine quotidienne et publié dans iso_links.txt
    publie=$(lien_publie "$loc")
    if [ -n "$publie" ]; then
        b=${publie%%;*}; publie=${publie#*;}
        e=${publie%%;*}; publie=${publie#*;}
        if url_valide "$publie"; then
            read -r -p "$(msg published_found "$b" "$(duree_restante $((e - $(date +%s))))")" rep
            case "$rep" in
                [nN]*) ;;
                *) url="$publie"; origine="publie" ;;
            esac
        fi
    fi
    # 2. Sinon : méthode manuelle (page ouverte, lien copié dans le presse-papiers)
    if [ -z "$url" ]; then
        obtenir_lien_manuel "$page" "$loc"
    fi

    while :; do
        if ! url_valide "$url"; then
            erreur "$(msg url_refused)"
            return 1
        fi
        nom=$(nom_fichier_url "$url")
        if [ -f "$dossier/$nom" ]; then
            avert "$(msg file_exists "$nom" "$dossier")"
            iso="$dossier/$nom"
            return 0
        fi
        info "$(msg querying)"
        taille=$(taille_distante "$url")
        [ "$taille" -eq 0 ] || break
        code=$(code_http "$url")
        case "$code" in
            2??)
                taille=$((8 * 1024 * 1024 * 1024))
                avert "$(msg size_unknown "$(en_go "$taille")")"
                break
                ;;
        esac
        if [ -n "$origine" ]; then
            avert "$(msg published_dead "$code")"
            origine=""
            obtenir_lien_manuel "$page" "$loc"
            continue
        fi
        erreur "$(msg http_err "$code")"
        return 1
    done

    # L'ISO est monté (pas extrait) et install.wim est découpé directement sur la clé :
    # il faut donc seulement la place de l'ISO, plus une marge pour les journaux.
    besoin=$((taille + MARGE_OCTETS))
    libre=$(espace_libre "$dossier")
    msg size_line "$(en_go "$taille")"; printf '\n'
    msg need_line "$(en_go "$besoin")"; printf '\n'
    msg free_line "$(en_go "$libre")" "$dossier"; printf '\n'
    if [ "$libre" -lt "$besoin" ]; then
        erreur "$(msg insufficient "$(en_go $((besoin - libre)))")"
        return 1
    fi
    read -r -p "$(msg confirm_dl "$dossier/$nom")" rep
    case "$rep" in [oOyY]*) ;; *) return 1 ;; esac

    info "$(msg dl_running)"
    t0=$SECONDS
    if ! curl -L --fail -C - --progress-bar -o "$dossier/$nom.part" "$url"; then
        erreur "$(msg dl_fail)"
        [ -s "$dossier/$nom.part" ] || rm -f "${dossier:?}/${nom:?}.part"
        return 1
    fi
    dt=$((SECONDS - t0))
    mv "$dossier/$nom.part" "$dossier/$nom" || return 1
    ok "$(msg dl_done "$dossier/$nom")"
    echo "$(msg dl_speed "$(vitesse "$(wc -c < "$dossier/$nom" | tr -d ' ')" "$dt")")"

    info "$(msg sha_calc)"
    calc=$(calculer_sha256 "$dossier/$nom")
    reconnu=$(curl -fsSL -m 15 "$URL_HASHES" 2>/dev/null | tr -d '\r' | grep -v '^[[:space:]]*#' |
              awk -F';' -v h="$calc" 'toupper($3)==toupper(h) {print $1 " - " $2; exit}')
    if [ -n "$reconnu" ]; then
        ok "$(msg sha_ok "$reconnu")"
    else
        avert "$(msg sha_unknown)"
        echo "$(msg sha_computed "$calc")"
        read -r -p "$(msg ask_sha)" attendu
        if [ -n "$attendu" ]; then
            if verifier_sha256 "$dossier/$nom" "$attendu"; then
                ok "$(msg sha_match)"
            else
                erreur "$(msg sha_bad)"
                return 1
            fi
        fi
    fi
    iso="$dossier/$nom"
    return 0
}
# ==== FIN FONCTIONS ====

# ==== PROGRAMME ====
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

# --- Langue des menus (langue du système, repli : anglais) ---
choisir_langue_ui

# --- Droits administrateur ---
if [ "$(id -u)" -ne 0 ]; then
    erreur "$(msg need_sudo "$0")"
    exit 1
fi

# --- Outils nécessaires ---
manquants=""
for outil in diskutil hdiutil wimlib-imagex; do
    command -v "$outil" >/dev/null 2>&1 || manquants="$manquants $outil"
done
if [ -n "$manquants" ]; then
    erreur "$(msg tools_missing "$manquants")"
    case "$manquants" in
        *wimlib-imagex*) erreur "$(msg install_wimlib)" ;;
    esac
    exit 1
fi

dossier="$PWD"
isomnt="$dossier/iso_mnt"

# --- Nettoyage en sortie (succès, erreur ou Ctrl-C) ---
nettoyage() {
    cd "$dossier" 2>/dev/null
    hdiutil detach "$isomnt" -force >/dev/null 2>&1
    rmdir "$isomnt" 2>/dev/null
    if [ -n "${SUDO_UID:-}" ]; then
        for f in copie_cle.log wimlib_split.log contenu_cle.txt; do
            [ -e "$dossier/$f" ] && chown "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$dossier/$f"
        done
    fi
}
trap nettoyage EXIT
trap 'exit 130' INT TERM

# --- Recherche des ISO dans le répertoire courant ---
isos=()
while IFS= read -r f; do isos+=("$f"); done < <(find "$dossier" -maxdepth 1 -type f -iname '*.iso' | sort)

if [ "${#isos[@]}" -eq 0 ]; then
    avert "$(msg no_iso "$dossier")"
    read -r -p "$(msg ask_no_iso)" iso
    case "$iso" in
        [tT]) telecharger_depuis_microsoft || exit 1 ;;
        *)    iso="${iso//\\ / }"; iso="${iso%\"}"; iso="${iso#\"}" ;;
    esac
else
    info "$(msg isos_found "$dossier")"
    i=1
    for f in "${isos[@]}"; do
        octets=$(wc -c < "$f")
        printf '  [%d] %s  (%s Go)\n' "$i" "$(basename "$f")" "$(en_go "$octets")"
        i=$((i + 1))
    done
    msg menu_download; printf '\n'
    read -r -p "$(msg ask_iso)" choix
    case "$choix" in
        [tT]) telecharger_depuis_microsoft || exit 1 ;;
        ''|*[!0-9]*) erreur "$(msg bad_choice)"; exit 1 ;;
        *)
            if [ "$choix" -lt 1 ] || [ "$choix" -gt "${#isos[@]}" ]; then
                erreur "$(msg bad_choice)"
                exit 1
            fi
            iso="${isos[$((choix - 1))]}"
            ;;
    esac
    ok "$(msg iso_selected "$iso")"
fi
[ -f "$iso" ] || { erreur "$(msg iso_missing)"; exit 1; }

# --- Choix de la clé USB ---
disques=()
while IFS= read -r d; do disques+=("$d"); done < <(diskutil list external physical | awk '/^\/dev\/disk/ {print $1}')
if [ "${#disques[@]}" -eq 0 ]; then
    erreur "$(msg no_usb)"
    exit 1
fi
info "$(msg usb_found)"
i=1
for d in "${disques[@]}"; do
    printf '  [%d] %s  %s  %s\n' "$i" "$d" "$(info_disque "$d" nom)" "$(info_disque "$d" taille)"
    i=$((i + 1))
done
read -r -p "$(msg ask_usb)" choix
case "$choix" in ''|*[!0-9]*) erreur "$(msg bad_choice)"; exit 1 ;; esac
if [ "$choix" -lt 1 ] || [ "$choix" -gt "${#disques[@]}" ]; then
    erreur "$(msg not_in_list)"
    exit 1
fi
dev="${disques[$((choix - 1))]}"
if diskutil info "$dev" | grep -Eqi 'Internal:[[:space:]]+Yes'; then
    erreur "$(msg internal_disk "$dev")"
    exit 1
fi
octets_cle=$(info_disque "$dev" octets)
iso_octets=$(wc -c < "$iso" | tr -d ' ')
if [ "${octets_cle:-0}" -gt 0 ] && [ "$octets_cle" -lt "$iso_octets" ]; then
    erreur "$(msg too_small "$(en_go "$octets_cle")" "$(en_go "$iso_octets")")"
    exit 1
fi
read -r -p "$(msg confirm_erase "$(info_disque "$dev" nom)" "$dev")" rep
case "$rep" in [oOyY]*) ;; *) exit 0 ;; esac

# --- Préparation de la clé ---
# MBR + FAT32 : avec GPT, macOS ajoute une partition EFI vide qui peut gêner le démarrage UEFI.
if [ "${octets_cle:-0}" -gt 32000000000 ]; then taille_part="32G"; else taille_part="R"; fi
info "$(msg preparing "$dev")"
diskutil unmountDisk force "$dev" >/dev/null 2>&1
if ! diskutil partitionDisk "$dev" MBR FAT32 WIN11 "$taille_part"; then
    erreur "$(msg partition_fail "$dev")"
    exit 1
fi
sleep 2
usb=$(diskutil info "${dev}s1" | sed -En 's/^ *Mount Point: *//p' | head -1)
if [ -z "$usb" ] || [ ! -d "$usb" ]; then
    diskutil mount "${dev}s1" >/dev/null 2>&1
    usb=$(diskutil info "${dev}s1" | sed -En 's/^ *Mount Point: *//p' | head -1)
fi
if [ -z "$usb" ] || [ ! -d "$usb" ]; then
    erreur "$(msg no_mountpoint)"
    exit 1
fi
mdutil -i off "$usb" >/dev/null 2>&1   # pas d'indexation Spotlight sur la clé

# --- Montage de l'ISO ---
hdiutil detach "$isomnt" -force >/dev/null 2>&1
mkdir -p "$isomnt"
if ! hdiutil attach -nobrowse -readonly -noverify -mountpoint "$isomnt" "$iso" >/dev/null; then
    erreur "$(msg iso_mount_fail_mac)"
    exit 1
fi
src="$isomnt"
if [ ! -d "$src/sources" ]; then
    erreur "$(msg sources_missing)"
    exit 1
fi

# --- Copie (tout sauf install.wim et autorun.inf), liste affichée + journal ---
info "$(msg copying)"
log="$dossier/copie_cle.log"
t_debut=$SECONDS
copier_fichiers "$src" "$usb" 2>&1 | tee "$log"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    erreur "$(msg copy_err "$log")"
    exit 1
fi
if [ -z "$(find "$usb/sources" -maxdepth 1 -iname 'boot.wim' 2>/dev/null)" ]; then
    erreur "$(msg bootwim_missing "$log")"
    exit 1
fi

# --- Image d'installation ---
wim=$(find "$src/sources" -maxdepth 1 -type f -iname 'install.wim' | head -1)
esd=$(find "$src/sources" -maxdepth 1 -type f -iname 'install.esd' | head -1)
dst="$usb/sources"
dlog="$dossier/wimlib_split.log"

if [ -n "$wim" ]; then
    # 1. Vérifier qu'on peut écrire sur la clé
    mkdir -p "$dst"
    if printf ok > "$dst/test.tmp" 2>/dev/null && rm -f "$dst/test.tmp"; then
        ok "$(msg write_ok)"
    else
        erreur "$(msg write_fail "$dst")"
        exit 1
    fi

    # 2. Découpage (limite FAT32 : 4 Go) directement sur la clé, avec barre de progression
    total=$(wc -c < "$wim" | tr -d ' ')
    info "$(msg splitting)"
    barre_init
    t_split=$SECONDS
    wimlib-imagex split "$wim" "$dst/install.swm" 3800 > "$dlog" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        barre "$(taille_swm "$dst")" "$total"
        sleep 0.5
    done
    wait "$pid"
    rc=$?
    printf '\n'
    if [ "$rc" -eq 0 ]; then
        ok "$(msg split_done)"
        echo "$(msg split_summary $((total / 1048576)) "$(duree $((SECONDS - t_split)))" "$(vitesse "$total" $((SECONDS - t_split)))")"
    else
        erreur "$(msg split_fail "$rc" "$dlog")"
        tail -n 15 "$dlog"
        rm -f "$dst"/install*.swm
        exit 1
    fi
elif [ -n "$esd" ]; then
    avert "$(msg esd_copy)"
    cp "$esd" "$dst/" || { erreur "$(msg esd_fail)"; exit 1; }
else
    erreur "$(msg no_image)"
    exit 1
fi

# --- Écriture définitive, vitesse, puis nettoyage des fichiers système macOS et inventaire ---
sync

# --- Vitesse d'écriture réelle (le cache d'écriture est vidé : sync terminé) ---
ecrit=$(( $(du -sk "$usb" 2>/dev/null | awk '{print $1}') * 1024 ))
duree_tot=$((SECONDS - t_debut))
v_tot=$(vitesse "$ecrit" "$duree_tot")
ok "$(msg total_speed "$(en_go "$ecrit")" "$(duree "$duree_tot")" "$v_tot")"
if awk -v v="$v_tot" -v s="$SEUIL_LENT" 'BEGIN{exit !(v < s)}'; then
    avert "$(msg slow_drive "$v_tot")"
fi
rm -rf "$usb/.fseventsd" "$usb/.Spotlight-V100" "$usb/.Trashes" "$usb/.DS_Store" 2>/dev/null
(
    cd "$usb" && find . -type f -print0 | while IFS= read -r -d '' f; do
        printf '%s\t%s Mo\n' "${f#./}" "$(awk -v s="$(wc -c < "$f")" 'BEGIN{printf "%.1f", s/1048576}')"
    done
) > "$dossier/contenu_cle.txt"

sync
ok "$(msg done_mac "$usb")"
echo "$(msg logs "$log" "$dlog" "$dossier/contenu_cle.txt")"
echo "$(msg eject_hint "$dev")"
