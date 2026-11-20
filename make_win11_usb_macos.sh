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
# Langues : fr, en, es, de, it, pt. Forcer une langue : sudo env WIN11_LANG=en bash ...   Ajouter une langue : ajouter une fonction msg_xx.
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
        keep_confirm) printf '%s' "'%s' contient déjà une disposition compatible : seule la partition FAT32 sera reformatée, les %s autre(s) partition(s) sont conservées. Continuer ? (O/N) " ;;
        data_warn) printf '%s' "ATTENTION : cette clé contient des fichiers dans une partition de données, et sa partition FAT32 est trop petite pour cet ISO (%s Go nécessaires). Continuer repartitionne la clé et EFFACE ces fichiers." ;;
        data_ask) printf '%s' "Pour les effacer quand même, tape %s (Entrée pour annuler) :  " ;;
        erase_word) printf '%s' "EFFACER" ;;
        data_created) printf '%s' "Partition de données exFAT « DONNEES » créée : %s Go pour tes fichiers (la FAT32 garde de la marge pour les futures versions de Windows)." ;;
        kept) printf '%s' "Disposition conservée : seule la partition FAT32 est reformatée." ;;
        eject_ask) printf '%s' "Éjecter la clé USB en toute sécurité maintenant ? (O/N) " ;;
        eject_ok) printf '%s' "Clé éjectée : tu peux la débrancher." ;;
        eject_fail) printf '%s' "Éjection impossible (clé encore utilisée ?). Ferme les fenêtres qui l'utilisent puis éjecte-la depuis le système avant de la débrancher." ;;
        bypass_ask) printf '%s' "Ignorer les questions de l'installation de Windows (compte local, sans compte Microsoft ni offres Microsoft 365) ? (O/N) " ;;
        bypass_name) printf '%s' "Nom du compte local Windows à créer (appuyez sur Entrée sans rien taper pour utiliser : %s) : " ;;
        bypass_done) printf '%s' "Réponses automatiques écrites sur la clé : autounattend.xml (compte local « %s »). Les écrans langue, édition et disque restent affichés." ;;
        ua_pc) printf '%s' "Nom de la machine (tapez un nom, ou appuyez sur Entrée pour laisser Windows en choisir un) : " ;;
        ua_lang) printf '%s' "Langue, clavier et fuseau : 0 = me le demander, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (appuyez sur le chiffre voulu, Entrée = 0) : " ;;
        ua_edition) printf '%s' "Édition : 0 = me la demander, 1 = Pro, 2 = Famille/Home (appuyez sur le chiffre voulu, Entrée = 0) : " ;;
        ua_auto) printf '%s' "Ouvrir la session automatiquement, sans mot de passe, au premier démarrage ? (O/N) " ;;
        ua_updates) printf '%s' "Mettre en pause les mises à jour automatiques (moins sûr) ? (O/N) " ;;
        ua_hw) printf '%s' "Ignorer les contrôles de compatibilité Windows 11 (TPM, Secure Boot, mémoire, processeur) ? (O/N) " ;;
        recap_key) printf '%s' "Clé de %s Go : repérez cette taille dans la liste des disques de l'installateur Windows." ;;
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
        sha_unknown) printf '%s' "Empreinte non reconnue (version ou langue absente de versions_iso.txt, ou fichier altéré)." ;;
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
        keep_confirm) printf '%s' "'%s' already has a compatible layout: only the FAT32 partition will be reformatted, the %s other partition(s) are kept. Continue? (Y/N) " ;;
        data_warn) printf '%s' "WARNING: this drive holds files in a data partition, and its FAT32 partition is too small for this ISO (%s GB needed). Continuing repartitions the drive and ERASES those files." ;;
        data_ask) printf '%s' "To erase them anyway, type %s (Enter to cancel):  " ;;
        erase_word) printf '%s' "ERASE" ;;
        data_created) printf '%s' "exFAT data partition 'DONNEES' created: %s GB for your files (the FAT32 partition keeps headroom for future Windows versions)." ;;
        kept) printf '%s' "Layout kept: only the FAT32 partition is reformatted." ;;
        eject_ask) printf '%s' "Safely eject the USB drive now? (Y/N) " ;;
        eject_ok) printf '%s' "Drive ejected: you can unplug it." ;;
        eject_fail) printf '%s' "Could not eject (drive still in use?). Close any window using it, then eject it from the system before unplugging." ;;
        bypass_ask) printf '%s' "Skip the Windows setup questions (local account, no Microsoft account or Microsoft 365 offers)? (Y/N) " ;;
        bypass_name) printf '%s' "Name of the local Windows account to create (press Enter without typing anything to use: %s): " ;;
        bypass_done) printf '%s' "Answer file written to the drive: autounattend.xml (local account '%s'). The language, edition and disk screens are still shown." ;;
        ua_pc) printf '%s' "Computer name (type a name, or press Enter to let Windows choose one): " ;;
        ua_lang) printf '%s' "Language, keyboard and time zone: 0 = ask me during setup, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (press the number, Enter = 0): " ;;
        ua_edition) printf '%s' "Edition: 0 = ask me during setup, 1 = Pro, 2 = Home (press the number, Enter = 0): " ;;
        ua_auto) printf '%s' "Sign in automatically (no password) on first start? (Y/N) " ;;
        ua_updates) printf '%s' "Pause automatic updates (less secure)? (Y/N) " ;;
        ua_hw) printf '%s' "Skip the Windows 11 compatibility checks (TPM, Secure Boot, memory, CPU)? (Y/N) " ;;
        recap_key) printf '%s' "%s GB drive: look for this size in the Windows setup disk list." ;;
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
        sha_unknown) printf '%s' "Hash not recognized (version or language missing from versions_iso.txt, or altered file)." ;;
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
msg_es() {
    case "$1" in
        need_sudo) printf '%s' "Ejecuta el script con sudo: sudo bash %s" ;;
        tools_missing) printf '%s' "Faltan herramientas:%s" ;;
        install_wimlib) printf '%s' "Instala wimlib (sin sudo): brew install wimlib" ;;
        no_iso) printf '%s' "No se encontró ningún archivo .iso en %s." ;;
        ask_no_iso) printf '%s' "T para descargar el ISO desde Microsoft, o ruta completa del ISO: " ;;
        isos_found) printf '%s' "ISO encontrados en %s:" ;;
        menu_download) printf '%s' "  [T] Descargar un ISO de Windows 11 desde Microsoft" ;;
        ask_iso) printf '%s' "Número del ISO a usar (o T): " ;;
        bad_choice) printf '%s' "Opción no válida." ;;
        iso_selected) printf '%s' "ISO seleccionado: %s" ;;
        iso_missing) printf '%s' "ISO no encontrado." ;;
        no_usb) printf '%s' "No se detectó ninguna unidad USB." ;;
        usb_found) printf '%s' "Unidades USB detectadas:" ;;
        ask_usb) printf '%s' "Número de la unidad USB que se BORRARÁ: " ;;
        not_in_list) printf '%s' "Ese número no está en la lista." ;;
        internal_disk) printf '%s' "%s es un disco interno: se cancela." ;;
        root_disk) printf '%s' "%s contiene el sistema de archivos raíz: se cancela." ;;
        too_small) printf '%s' "Unidad demasiado pequeña: %s GB para un ISO de %s GB." ;;
        confirm_erase) printf '%s' "¿Confirmar el borrado de '%s' (%s)? (S/N) " ;;
        keep_confirm) printf '%s' "'%s' ya tiene una disposición compatible: solo se reformateará la partición FAT32; las %s otra(s) partición(es) se conservan. ¿Continuar? (S/N) " ;;
        data_warn) printf '%s' "ATENCIÓN: esta unidad tiene archivos en una partición de datos y su partición FAT32 es demasiado pequeña para este ISO (se necesitan %s GB). Continuar reparticiona la unidad y BORRA esos archivos." ;;
        data_ask) printf '%s' "Para borrarlos igualmente, escribe %s (Intro para cancelar):  " ;;
        erase_word) printf '%s' "BORRAR" ;;
        data_created) printf '%s' "Partición de datos exFAT 'DONNEES' creada: %s GB para tus archivos (la FAT32 conserva margen para futuras versiones de Windows)." ;;
        kept) printf '%s' "Disposición conservada: solo se reformatea la partición FAT32." ;;
        eject_ask) printf '%s' "¿Expulsar ahora la unidad USB de forma segura? (S/N) " ;;
        eject_ok) printf '%s' "Unidad expulsada: ya puedes desconectarla." ;;
        eject_fail) printf '%s' "No se pudo expulsar (¿unidad en uso?). Cierra las ventanas que la usen y exprúlsala desde el sistema antes de desconectarla." ;;
        bypass_ask) printf '%s' "¿Omitir las preguntas de la instalación de Windows (cuenta local, sin cuenta Microsoft ni ofertas de Microsoft 365)? (S/N) " ;;
        bypass_name) printf '%s' "Nombre de la cuenta local de Windows que se creará (pulsa Intro sin escribir nada para usar: %s): " ;;
        bypass_done) printf '%s' "Archivo de respuestas escrito en la unidad: autounattend.xml (cuenta local '%s'). Las pantallas de idioma, edición y disco siguen apareciendo." ;;
        ua_pc) printf '%s' "Nombre del equipo (escribe un nombre o pulsa Intro para que Windows elija uno): " ;;
        ua_lang) printf '%s' "Idioma, teclado y zona horaria: 0 = preguntármelo, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (pulsa el número, Intro = 0): " ;;
        ua_edition) printf '%s' "Edición: 0 = preguntármelo, 1 = Pro, 2 = Home (pulsa el número, Intro = 0): " ;;
        ua_auto) printf '%s' "¿Iniciar sesión automáticamente (sin contraseña) en el primer arranque? (S/N) " ;;
        ua_updates) printf '%s' "¿Pausar las actualizaciones automáticas (menos seguro)? (S/N) " ;;
        ua_hw) printf '%s' "¿Omitir las comprobaciones de compatibilidad de Windows 11 (TPM, Secure Boot, memoria, CPU)? (S/N) " ;;
        recap_key) printf '%s' "Unidad de %s GB: busca este tamaño en la lista de discos del instalador de Windows." ;;
        preparing) printf '%s' "Preparando la unidad (%s)..." ;;
        partition_fail) printf '%s' "Error al particionar %s." ;;
        no_mountpoint) printf '%s' "No se encontró el punto de montaje de la unidad." ;;
        part_missing) printf '%s' "No se encontró la partición tras el particionado." ;;
        mkfs_fail) printf '%s' "Error al formatear %s en FAT32." ;;
        mount_fail) printf '%s' "No se pudo montar %s." ;;
        iso_mount_fail_mac) printf '%s' "No se pudo montar el ISO." ;;
        iso_mount_fail_linux) printf '%s' "No se pudo montar el ISO (prueba: sudo modprobe udf)." ;;
        sources_missing) printf '%s' "No se encontró la carpeta 'sources' en el ISO montado: ISO no válido o montado en un formato incompleto." ;;
        copying) printf '%s' "Copiando archivos..." ;;
        copy_err_file) printf '%s' "ERROR de copia: %s" ;;
        copy_err) printf '%s' "La copia encontró un error. Consulta %s" ;;
        bootwim_missing) printf '%s' "Falta sources/boot.wim en la unidad: copia incompleta. Consulta %s" ;;
        write_ok) printf '%s' "Prueba de escritura en la unidad: OK" ;;
        write_fail) printf '%s' "No se puede escribir en %s" ;;
        splitting) printf '%s' "Dividiendo install.wim..." ;;
        split_done) printf '%s' "División completada." ;;
        split_fail) printf '%s' "wimlib falló (código %s). Últimas líneas de %s:" ;;
        esd_copy) printf '%s' "install.esd detectado: se copia directamente." ;;
        esd_fail) printf '%s' "Error al copiar install.esd" ;;
        no_image) printf '%s' "No se encontró ni install.wim ni install.esd en el ISO." ;;
        done_mac) printf '%s' "Terminado: la unidad está lista en %s" ;;
        logs) printf '%s' "Registros: %s, %s (si se dividió) y %s" ;;
        eject_hint) printf '%s' "Para expulsarla de forma segura: diskutil eject %s" ;;
        syncing) printf '%s' "Sincronizando la unidad (no la retires todavía)..." ;;
        umount_fail) printf '%s' "No se pudo desmontar la unidad: no la retires." ;;
        done_linux) printf '%s' "Terminado: la unidad está lista (%s). Ya puedes retirarla." ;;
        bar_size) printf '%s' "%d MB / %d MB" ;;
        bar_speed) printf '%s' "%s MB/s" ;;
        copy_line_speed) printf '%s' "  — %s MB/s de media" ;;
        copy_summary) printf '%s' "Copia terminada: %s MB en %s — %s MB/s de media." ;;
        split_summary) printf '%s' "División: %s MB en %s — %s MB/s." ;;
        total_speed) printf '%s' "Total escrito en la unidad: %s GB en %s — %s MB/s (caché de escritura vaciada)." ;;
        slow_drive) printf '%s' "Unidad lenta (%s MB/s): una unidad USB 3.x en un puerto USB 3 sería mucho más rápida." ;;
        curl_needed) printf '%s' "Se necesita curl para descargar el ISO." ;;
        dl_title) printf '%s' "Descarga del ISO de Windows 11 desde Microsoft" ;;
        ask_lang) printf '%s' "Idioma de la página de Microsoft [%s] (Intro para aceptar, u otro código, p. ej. fr-fr): " ;;
        bad_code) printf '%s' "Código no válido: se mantiene el idioma detectado (%s)." ;;
        official_page) printf '%s' "Página oficial: %s" ;;
        no_fixed_link) printf '%s' "Microsoft no publica un enlace fijo: el enlace directo se genera en cada descarga\ny solo es válido 24 horas." ;;
        step1) printf '%s' "  1. Abre la página oficial anterior en tu navegador." ;;
        step2) printf '%s' "  2. En «Descargar imagen de disco de Windows 11 (ISO) para dispositivos x64», elige el ISO\n     multiedición, luego el idioma del producto (idioma de tu sistema: %s) y pulsa «Confirmar»." ;;
        step3) printf '%s' "  3. Clic derecho en el botón de descarga de 64 bits > «Copiar dirección del vínculo»: el script lo detecta solo.\n     Pega el vínculo COMPLETO, incluido lo que sigue a «.iso?»: esa parte es la que lo autoriza." ;;
        clip_unreadable) printf '%s' "Portapapeles ilegible aquí (falta la herramienta): pega el enlace a mano." ;;
        ask_url) printf '%s' "Pega aquí la URL del enlace (https://...microsoft.com/....iso): " ;;
        url_refused) printf '%s' "URL rechazada: debe ser https, de un dominio *.microsoft.com, y su ruta debe terminar en .iso." ;;
        file_exists) printf '%s' "%s ya existe en %s: se usa el archivo existente." ;;
        querying) printf '%s' "Consultando el servidor de Microsoft..." ;;
        size_unknown) printf '%s' "Tamaño del ISO no comunicado: se supone %s GB." ;;
        http_err) printf '%s' "El servidor de Microsoft respondió HTTP %s (000 = sin respuesta): enlace caducado, incompleto (sin la parte posterior a «.iso?») o red inaccesible.\nGenera un nuevo enlace en la página oficial." ;;
        size_line) printf '%s' "  Tamaño del ISO       : %s GB" ;;
        need_line) printf '%s' "  Espacio necesario    : %s GB (ISO + margen; sin copia temporal para la división)" ;;
        free_line) printf '%s' "  Espacio libre        : %s GB (%s)" ;;
        insufficient) printf '%s' "Espacio en disco insuficiente: faltan %s GB." ;;
        confirm_dl) printf '%s' "¿Iniciar la descarga en %s? (S/N) " ;;
        dl_running) printf '%s' "Descargando (se puede reanudar si se interrumpe)..." ;;
        dl_fail) printf '%s' "Error en la descarga (¿enlace caducado o red?). Genera un nuevo enlace en la página de Microsoft." ;;
        dl_done) printf '%s' "Descarga terminada: %s" ;;
        dl_speed) printf '%s' "Velocidad media de descarga: %s MB/s" ;;
        sha_calc) printf '%s' "Calculando el hash SHA-256 (unos minutos)..." ;;
        sha_ok) printf '%s' "El hash coincide con el publicado por Microsoft (%s)." ;;
        sha_unknown) printf '%s' "Hash no reconocido (versión o idioma ausente de iso_hashes.txt, o archivo alterado)." ;;
        sha_computed) printf '%s' "SHA-256 calculado: %s" ;;
        ask_sha) printf '%s' "Hash SHA-256 que muestra Microsoft para este idioma (Intro para omitir): " ;;
        sha_match) printf '%s' "El hash coincide." ;;
        sha_bad) printf '%s' "El hash difiere: archivo dañado o incompleto. Bórralo y vuelve a empezar." ;;
        wait_link) printf '%s' "Esperando el enlace: haz clic en «Copiar dirección del vínculo» en el navegador.\n(Intro = pegar el enlace a mano)" ;;
        clip_found) printf '%s' "Enlace detectado en el portapapeles: %s. ¿Usarlo? (S/n) " ;;
        wait_timeout) printf '%s' "Tiempo agotado (5 minutos): pega el enlace a mano." ;;
        published_found) printf '%s' "Enlace ya generado (iso_links.txt): build %s, válido todavía %s. ¿Usarlo? (S/n) " ;;
        published_dead) printf '%s' "Ese enlace publicado no responde (HTTP %s): se vuelve al método manual." ;;
        *) return 1 ;;
    esac
}
msg_de() {
    case "$1" in
        need_sudo) printf '%s' "Starte das Skript mit sudo: sudo bash %s" ;;
        tools_missing) printf '%s' "Fehlende Werkzeuge:%s" ;;
        install_wimlib) printf '%s' "Installiere wimlib (ohne sudo): brew install wimlib" ;;
        no_iso) printf '%s' "Keine .iso-Datei in %s gefunden." ;;
        ask_no_iso) printf '%s' "T zum Herunterladen der ISO von Microsoft, oder vollständiger Pfad der ISO: " ;;
        isos_found) printf '%s' "ISO-Dateien in %s:" ;;
        menu_download) printf '%s' "  [T] Windows-11-ISO von Microsoft herunterladen" ;;
        ask_iso) printf '%s' "Nummer der zu verwendenden ISO (oder T): " ;;
        bad_choice) printf '%s' "Ungültige Auswahl." ;;
        iso_selected) printf '%s' "Gewählte ISO: %s" ;;
        iso_missing) printf '%s' "ISO nicht gefunden." ;;
        no_usb) printf '%s' "Kein USB-Laufwerk erkannt." ;;
        usb_found) printf '%s' "Erkannte USB-Laufwerke:" ;;
        ask_usb) printf '%s' "Nummer des USB-Laufwerks, das GELÖSCHT wird: " ;;
        not_in_list) printf '%s' "Diese Nummer steht nicht in der Liste." ;;
        internal_disk) printf '%s' "%s ist ein interner Datenträger: Abbruch." ;;
        root_disk) printf '%s' "%s enthält das Root-Dateisystem: Abbruch." ;;
        too_small) printf '%s' "USB-Laufwerk zu klein: %s GB für eine ISO mit %s GB." ;;
        confirm_erase) printf '%s' "Löschen von '%s' (%s) bestätigen? (J/N) " ;;
        keep_confirm) printf '%s' "'%s' hat bereits ein kompatibles Layout: nur die FAT32-Partition wird neu formatiert, die %s weitere(n) Partition(en) bleiben erhalten. Fortfahren? (J/N) " ;;
        data_warn) printf '%s' "ACHTUNG: Dieses Laufwerk enthält Dateien in einer Datenpartition, und die FAT32-Partition ist für diese ISO zu klein (%s GB nötig). Fortfahren partitioniert neu und LÖSCHT diese Dateien." ;;
        data_ask) printf '%s' "Zum Löschen trotzdem %s eingeben (Enter = abbrechen):  " ;;
        erase_word) printf '%s' "LÖSCHEN" ;;
        data_created) printf '%s' "exFAT-Datenpartition 'DONNEES' angelegt: %s GB für deine Dateien (die FAT32-Partition behält Reserve für künftige Windows-Versionen)." ;;
        kept) printf '%s' "Layout beibehalten: nur die FAT32-Partition wird neu formatiert." ;;
        eject_ask) printf '%s' "USB-Laufwerk jetzt sicher auswerfen? (J/N) " ;;
        eject_ok) printf '%s' "Laufwerk ausgeworfen: Du kannst es abziehen." ;;
        eject_fail) printf '%s' "Auswerfen nicht möglich (Laufwerk noch in Benutzung?). Schließe Fenster, die es nutzen, und wirf es im System aus, bevor du es abziehst." ;;
        bypass_ask) printf '%s' "Fragen der Windows-Einrichtung überspringen (lokales Konto, ohne Microsoft-Konto und Microsoft-365-Angebote)? (J/N) " ;;
        bypass_name) printf '%s' "Name des anzulegenden lokalen Windows-Kontos (Eingabetaste ohne Text drücken, um zu verwenden: %s): " ;;
        bypass_done) printf '%s' "Antwortdatei auf den Stick geschrieben: autounattend.xml (lokales Konto '%s'). Sprach-, Editions- und Datenträgerauswahl bleiben sichtbar." ;;
        ua_pc) printf '%s' "Computername (Namen eingeben oder Eingabetaste drücken, damit Windows einen wählt): " ;;
        ua_lang) printf '%s' "Sprache, Tastatur und Zeitzone: 0 = bei der Installation fragen, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (Ziffer drücken, Eingabe = 0): " ;;
        ua_edition) printf '%s' "Edition: 0 = bei der Installation fragen, 1 = Pro, 2 = Home (Ziffer drücken, Eingabe = 0): " ;;
        ua_auto) printf '%s' "Beim ersten Start automatisch anmelden (ohne Kennwort)? (J/N) " ;;
        ua_updates) printf '%s' "Automatische Updates pausieren (weniger sicher)? (J/N) " ;;
        ua_hw) printf '%s' "Windows-11-Kompatibilitätsprüfungen überspringen (TPM, Secure Boot, Speicher, CPU)? (J/N) " ;;
        recap_key) printf '%s' "Stick mit %s GB: Diese Größe in der Datenträgerliste des Windows-Setups suchen." ;;
        preparing) printf '%s' "USB-Laufwerk wird vorbereitet (%s)..." ;;
        partition_fail) printf '%s' "Partitionierung von %s fehlgeschlagen." ;;
        no_mountpoint) printf '%s' "Einhängepunkt des Laufwerks nicht gefunden." ;;
        part_missing) printf '%s' "Partition nach der Partitionierung nicht gefunden." ;;
        mkfs_fail) printf '%s' "FAT32-Formatierung von %s fehlgeschlagen." ;;
        mount_fail) printf '%s' "%s konnte nicht eingehängt werden." ;;
        iso_mount_fail_mac) printf '%s' "Die ISO konnte nicht eingehängt werden." ;;
        iso_mount_fail_linux) printf '%s' "Die ISO konnte nicht eingehängt werden (versuche: sudo modprobe udf)." ;;
        sources_missing) printf '%s' "Ordner 'sources' in der eingehängten ISO nicht gefunden: ungültige ISO oder unvollständiges Format." ;;
        copying) printf '%s' "Dateien werden kopiert..." ;;
        copy_err_file) printf '%s' "KOPIERFEHLER: %s" ;;
        copy_err) printf '%s' "Beim Kopieren ist ein Fehler aufgetreten. Siehe %s" ;;
        bootwim_missing) printf '%s' "sources/boot.wim fehlt auf dem Laufwerk: unvollständige Kopie. Siehe %s" ;;
        write_ok) printf '%s' "Schreibtest auf dem Laufwerk: OK" ;;
        write_fail) printf '%s' "Schreiben auf %s nicht möglich" ;;
        splitting) printf '%s' "install.wim wird aufgeteilt..." ;;
        split_done) printf '%s' "Aufteilung abgeschlossen." ;;
        split_fail) printf '%s' "wimlib ist fehlgeschlagen (Code %s). Letzte Zeilen von %s:" ;;
        esd_copy) printf '%s' "install.esd erkannt: wird direkt kopiert." ;;
        esd_fail) printf '%s' "install.esd konnte nicht kopiert werden" ;;
        no_image) printf '%s' "Weder install.wim noch install.esd in der ISO gefunden." ;;
        done_mac) printf '%s' "Fertig: Das Laufwerk ist bereit unter %s" ;;
        logs) printf '%s' "Protokolle: %s, %s (bei Aufteilung) und %s" ;;
        eject_hint) printf '%s' "Zum sicheren Auswerfen: diskutil eject %s" ;;
        syncing) printf '%s' "Laufwerk wird synchronisiert (noch nicht entfernen)..." ;;
        umount_fail) printf '%s' "Laufwerk konnte nicht ausgehängt werden: nicht entfernen." ;;
        done_linux) printf '%s' "Fertig: Das Laufwerk ist bereit (%s). Du kannst es entfernen." ;;
        bar_size) printf '%s' "%d MB / %d MB" ;;
        bar_speed) printf '%s' "%s MB/s" ;;
        copy_line_speed) printf '%s' "  — %s MB/s im Durchschnitt" ;;
        copy_summary) printf '%s' "Kopieren abgeschlossen: %s MB in %s — %s MB/s im Durchschnitt." ;;
        split_summary) printf '%s' "Aufteilung: %s MB in %s — %s MB/s." ;;
        total_speed) printf '%s' "Insgesamt auf das Laufwerk geschrieben: %s GB in %s — %s MB/s (Schreibcache geleert)." ;;
        slow_drive) printf '%s' "Langsames Laufwerk (%s MB/s): Ein USB-3.x-Laufwerk an einem USB-3-Anschluss wäre deutlich schneller." ;;
        curl_needed) printf '%s' "curl wird zum Herunterladen der ISO benötigt." ;;
        dl_title) printf '%s' "Windows-11-ISO wird von Microsoft heruntergeladen" ;;
        ask_lang) printf '%s' "Sprache der Microsoft-Seite [%s] (Eingabe zum Übernehmen, oder anderer Code, z. B. de-de): " ;;
        bad_code) printf '%s' "Ungültiger Code: erkannte Sprache bleibt erhalten (%s)." ;;
        official_page) printf '%s' "Offizielle Seite: %s" ;;
        no_fixed_link) printf '%s' "Microsoft veröffentlicht keinen festen Link: Der direkte Link wird bei jedem Download erzeugt\nund ist nur 24 Stunden gültig." ;;
        step1) printf '%s' "  1. Öffne die obige offizielle Seite in deinem Browser." ;;
        step2) printf '%s' "  2. Wähle unter „Windows 11-Datenträgerabbild (ISO) für x64-Geräte herunterladen“ die ISO mit\n     mehreren Editionen, dann die Produktsprache (deine Systemsprache: %s) und klicke auf „Bestätigen“." ;;
        step3) printf '%s' "  3. Rechtsklick auf die 64-Bit-Download-Schaltfläche > „Link-Adresse kopieren“: Das Skript erkennt ihn selbst.\n     Füge den GANZEN Link ein, einschließlich dessen, was nach „.iso?“ folgt: Dieser Teil autorisiert ihn." ;;
        clip_unreadable) printf '%s' "Zwischenablage hier nicht lesbar (Werkzeug fehlt): Link von Hand einfügen." ;;
        ask_url) printf '%s' "Link-URL hier einfügen (https://...microsoft.com/....iso): " ;;
        url_refused) printf '%s' "URL abgelehnt: Sie muss https verwenden, zu einer *.microsoft.com-Domain gehören und der Pfad muss auf .iso enden." ;;
        file_exists) printf '%s' "%s existiert bereits in %s: vorhandene Datei wird verwendet." ;;
        querying) printf '%s' "Microsoft-Server wird abgefragt..." ;;
        size_unknown) printf '%s' "ISO-Größe nicht mitgeteilt: Annahme von %s GB." ;;
        http_err) printf '%s' "Der Microsoft-Server antwortete mit HTTP %s (000 = keine Antwort): Link abgelaufen, unvollständig (Teil nach „.iso?“ fehlt) oder Netzwerk nicht erreichbar.\nErzeuge einen neuen Link auf der offiziellen Seite." ;;
        size_line) printf '%s' "  ISO-Größe            : %s GB" ;;
        need_line) printf '%s' "  Benötigter Platz     : %s GB (ISO + Reserve; keine temporäre Kopie für die Aufteilung)" ;;
        free_line) printf '%s' "  Freier Platz         : %s GB (%s)" ;;
        insufficient) printf '%s' "Nicht genug Speicherplatz: %s GB fehlen." ;;
        confirm_dl) printf '%s' "Download nach %s starten? (J/N) " ;;
        dl_running) printf '%s' "Download läuft (fortsetzbar bei Unterbrechung)..." ;;
        dl_fail) printf '%s' "Download fehlgeschlagen (Link abgelaufen oder Netzwerk?). Erzeuge einen neuen Link auf der Microsoft-Seite." ;;
        dl_done) printf '%s' "Download abgeschlossen: %s" ;;
        dl_speed) printf '%s' "Durchschnittliche Download-Geschwindigkeit: %s MB/s" ;;
        sha_calc) printf '%s' "SHA-256-Hash wird berechnet (einige Minuten)..." ;;
        sha_ok) printf '%s' "Hash stimmt mit dem von Microsoft veröffentlichten überein (%s)." ;;
        sha_unknown) printf '%s' "Hash nicht erkannt (Version oder Sprache fehlt in iso_hashes.txt, oder Datei verändert)." ;;
        sha_computed) printf '%s' "Berechneter SHA-256: %s" ;;
        ask_sha) printf '%s' "Von Microsoft für diese Sprache angezeigter SHA-256-Hash (Eingabe zum Überspringen): " ;;
        sha_match) printf '%s' "Hash stimmt überein." ;;
        sha_bad) printf '%s' "Hash weicht ab: Datei beschädigt oder unvollständig. Löschen und neu beginnen." ;;
        wait_link) printf '%s' "Warte auf den Link: Klicke im Browser auf „Link-Adresse kopieren“.\n(Eingabe = Link von Hand einfügen)" ;;
        clip_found) printf '%s' "Link in der Zwischenablage erkannt: %s. Verwenden? (J/n) " ;;
        wait_timeout) printf '%s' "Zeitüberschreitung (5 Minuten): Link von Hand einfügen." ;;
        published_found) printf '%s' "Bereits erzeugter Link (iso_links.txt): Build %s, noch gültig für %s. Verwenden? (J/n) " ;;
        published_dead) printf '%s' "Dieser veröffentlichte Link antwortet nicht (HTTP %s): Rückfall auf die manuelle Methode." ;;
        *) return 1 ;;
    esac
}
msg_it() {
    case "$1" in
        need_sudo) printf '%s' "Avvia lo script con sudo: sudo bash %s" ;;
        tools_missing) printf '%s' "Strumenti mancanti:%s" ;;
        install_wimlib) printf '%s' "Installa wimlib (senza sudo): brew install wimlib" ;;
        no_iso) printf '%s' "Nessun file .iso trovato in %s." ;;
        ask_no_iso) printf '%s' "T per scaricare l'ISO da Microsoft, oppure percorso completo dell'ISO: " ;;
        isos_found) printf '%s' "ISO trovati in %s:" ;;
        menu_download) printf '%s' "  [T] Scarica un ISO di Windows 11 da Microsoft" ;;
        ask_iso) printf '%s' "Numero dell'ISO da usare (o T): " ;;
        bad_choice) printf '%s' "Scelta non valida." ;;
        iso_selected) printf '%s' "ISO selezionato: %s" ;;
        iso_missing) printf '%s' "ISO non trovato." ;;
        no_usb) printf '%s' "Nessuna unità USB rilevata." ;;
        usb_found) printf '%s' "Unità USB rilevate:" ;;
        ask_usb) printf '%s' "Numero dell'unità USB da CANCELLARE: " ;;
        not_in_list) printf '%s' "Questo numero non è nell'elenco." ;;
        internal_disk) printf '%s' "%s è un disco interno: operazione annullata." ;;
        root_disk) printf '%s' "%s contiene il file system root: operazione annullata." ;;
        too_small) printf '%s' "Unità troppo piccola: %s GB per un ISO da %s GB." ;;
        confirm_erase) printf '%s' "Confermare la cancellazione di '%s' (%s)? (S/N) " ;;
        keep_confirm) printf '%s' "'%s' ha già una disposizione compatibile: verrà riformattata solo la partizione FAT32, le altre %s partizione/i restano intatte. Continuare? (S/N) " ;;
        data_warn) printf '%s' "ATTENZIONE: questa unità contiene file in una partizione dati e la partizione FAT32 è troppo piccola per questo ISO (servono %s GB). Continuare ripartiziona l'unità e CANCELLA quei file." ;;
        data_ask) printf '%s' "Per cancellarli comunque, scrivi %s (Invio per annullare):  " ;;
        erase_word) printf '%s' "CANCELLA" ;;
        data_created) printf '%s' "Partizione dati exFAT 'DONNEES' creata: %s GB per i tuoi file (la FAT32 mantiene margine per le future versioni di Windows)." ;;
        kept) printf '%s' "Disposizione mantenuta: viene riformattata solo la partizione FAT32." ;;
        eject_ask) printf '%s' "Espellere ora la chiavetta USB in sicurezza? (S/N) " ;;
        eject_ok) printf '%s' "Chiavetta espulsa: puoi scollegarla." ;;
        eject_fail) printf '%s' "Impossibile espellere (chiavetta ancora in uso?). Chiudi le finestre che la usano ed espellila dal sistema prima di scollegarla." ;;
        bypass_ask) printf '%s' "Saltare le domande dell'installazione di Windows (account locale, senza account Microsoft né offerte Microsoft 365)? (S/N) " ;;
        bypass_name) printf '%s' "Nome dell'account locale di Windows da creare (premi Invio senza scrivere nulla per usare: %s): " ;;
        bypass_done) printf '%s' "File di risposte scritto sulla chiavetta: autounattend.xml (account locale '%s'). Le schermate di lingua, edizione e disco restano visibili." ;;
        ua_pc) printf '%s' "Nome del computer (scrivi un nome o premi Invio per lasciarlo scegliere a Windows): " ;;
        ua_lang) printf '%s' "Lingua, tastiera e fuso orario: 0 = chiedimelo, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (premi il numero, Invio = 0): " ;;
        ua_edition) printf '%s' "Edizione: 0 = chiedimelo, 1 = Pro, 2 = Home (premi il numero, Invio = 0): " ;;
        ua_auto) printf '%s' "Accedere automaticamente (senza password) al primo avvio? (S/N) " ;;
        ua_updates) printf '%s' "Sospendere gli aggiornamenti automatici (meno sicuro)? (S/N) " ;;
        ua_hw) printf '%s' "Saltare i controlli di compatibilità di Windows 11 (TPM, Secure Boot, memoria, CPU)? (S/N) " ;;
        recap_key) printf '%s' "Chiavetta da %s GB: cerca questa dimensione nell'elenco dei dischi del programma di installazione di Windows." ;;
        preparing) printf '%s' "Preparazione dell'unità (%s)..." ;;
        partition_fail) printf '%s' "Partizionamento di %s non riuscito." ;;
        no_mountpoint) printf '%s' "Punto di montaggio dell'unità non trovato." ;;
        part_missing) printf '%s' "Partizione non trovata dopo il partizionamento." ;;
        mkfs_fail) printf '%s' "Formattazione FAT32 di %s non riuscita." ;;
        mount_fail) printf '%s' "Impossibile montare %s." ;;
        iso_mount_fail_mac) printf '%s' "Impossibile montare l'ISO." ;;
        iso_mount_fail_linux) printf '%s' "Impossibile montare l'ISO (prova: sudo modprobe udf)." ;;
        sources_missing) printf '%s' "Cartella 'sources' non trovata nell'ISO montato: ISO non valido o montato in un formato incompleto." ;;
        copying) printf '%s' "Copia dei file in corso..." ;;
        copy_err_file) printf '%s' "ERRORE di copia: %s" ;;
        copy_err) printf '%s' "La copia ha incontrato un errore. Vedi %s" ;;
        bootwim_missing) printf '%s' "sources/boot.wim assente dall'unità: copia incompleta. Vedi %s" ;;
        write_ok) printf '%s' "Test di scrittura sull'unità: OK" ;;
        write_fail) printf '%s' "Impossibile scrivere su %s" ;;
        splitting) printf '%s' "Divisione di install.wim in corso..." ;;
        split_done) printf '%s' "Divisione completata." ;;
        split_fail) printf '%s' "wimlib non è riuscito (codice %s). Ultime righe di %s:" ;;
        esd_copy) printf '%s' "install.esd rilevato: copia diretta." ;;
        esd_fail) printf '%s' "Copia di install.esd non riuscita" ;;
        no_image) printf '%s' "Né install.wim né install.esd trovati nell'ISO." ;;
        done_mac) printf '%s' "Fatto: l'unità è pronta in %s" ;;
        logs) printf '%s' "Registri: %s, %s (se divisione) e %s" ;;
        eject_hint) printf '%s' "Per espellerla in sicurezza: diskutil eject %s" ;;
        syncing) printf '%s' "Sincronizzazione dell'unità (non rimuoverla ancora)..." ;;
        umount_fail) printf '%s' "Impossibile smontare l'unità: non rimuoverla." ;;
        done_linux) printf '%s' "Fatto: l'unità è pronta (%s). Puoi rimuoverla." ;;
        bar_size) printf '%s' "%d MB / %d MB" ;;
        bar_speed) printf '%s' "%s MB/s" ;;
        copy_line_speed) printf '%s' "  — %s MB/s in media" ;;
        copy_summary) printf '%s' "Copia terminata: %s MB in %s — %s MB/s in media." ;;
        split_summary) printf '%s' "Divisione: %s MB in %s — %s MB/s." ;;
        total_speed) printf '%s' "Totale scritto sull'unità: %s GB in %s — %s MB/s (cache di scrittura svuotata)." ;;
        slow_drive) printf '%s' "Unità lenta (%s MB/s): un'unità USB 3.x su una porta USB 3 sarebbe molto più veloce." ;;
        curl_needed) printf '%s' "curl è necessario per scaricare l'ISO." ;;
        dl_title) printf '%s' "Download dell'ISO di Windows 11 da Microsoft" ;;
        ask_lang) printf '%s' "Lingua della pagina Microsoft [%s] (Invio per confermare, o altro codice, es. it-it): " ;;
        bad_code) printf '%s' "Codice non valido: lingua rilevata mantenuta (%s)." ;;
        official_page) printf '%s' "Pagina ufficiale: %s" ;;
        no_fixed_link) printf '%s' "Microsoft non pubblica un link fisso: il link diretto viene generato a ogni download\ned è valido solo 24 ore." ;;
        step1) printf '%s' "  1. Apri la pagina ufficiale qui sopra nel browser." ;;
        step2) printf '%s' "  2. In «Scarica l'immagine del disco di Windows 11 (ISO) per dispositivi x64», scegli l'ISO\n     multi-edizione, poi la lingua del prodotto (lingua del tuo sistema: %s) e fai clic su «Conferma»." ;;
        step3) printf '%s' "  3. Clic destro sul pulsante di download a 64 bit > «Copia indirizzo link»: lo script lo rileva da solo.\n     Incolla il link COMPLETO, compresa la parte dopo «.iso?»: è quella che lo autorizza." ;;
        clip_unreadable) printf '%s' "Appunti non leggibili qui (strumento mancante): incolla il link a mano." ;;
        ask_url) printf '%s' "Incolla qui l'URL del link (https://...microsoft.com/....iso): " ;;
        url_refused) printf '%s' "URL rifiutato: deve essere https, di un dominio *.microsoft.com, e il percorso deve terminare con .iso." ;;
        file_exists) printf '%s' "%s esiste già in %s: uso il file esistente." ;;
        querying) printf '%s' "Interrogazione del server Microsoft..." ;;
        size_unknown) printf '%s' "Dimensione dell'ISO non comunicata: ipotizzo %s GB." ;;
        http_err) printf '%s' "Il server Microsoft ha risposto HTTP %s (000 = nessuna risposta): link scaduto, incompleto (senza la parte dopo «.iso?») o rete non raggiungibile.\nGenera un nuovo link sulla pagina ufficiale." ;;
        size_line) printf '%s' "  Dimensione ISO       : %s GB" ;;
        need_line) printf '%s' "  Spazio necessario    : %s GB (ISO + margine; nessuna copia temporanea per la divisione)" ;;
        free_line) printf '%s' "  Spazio libero        : %s GB (%s)" ;;
        insufficient) printf '%s' "Spazio su disco insufficiente: mancano %s GB." ;;
        confirm_dl) printf '%s' "Avviare il download in %s? (S/N) " ;;
        dl_running) printf '%s' "Download in corso (riprendibile se interrotto)..." ;;
        dl_fail) printf '%s' "Download non riuscito (link scaduto o rete?). Genera un nuovo link sulla pagina Microsoft." ;;
        dl_done) printf '%s' "Download completato: %s" ;;
        dl_speed) printf '%s' "Velocità media di download: %s MB/s" ;;
        sha_calc) printf '%s' "Calcolo dell'hash SHA-256 (qualche minuto)..." ;;
        sha_ok) printf '%s' "L'hash corrisponde a quello pubblicato da Microsoft (%s)." ;;
        sha_unknown) printf '%s' "Hash non riconosciuto (versione o lingua assente da iso_hashes.txt, o file alterato)." ;;
        sha_computed) printf '%s' "SHA-256 calcolato: %s" ;;
        ask_sha) printf '%s' "Hash SHA-256 mostrato da Microsoft per questa lingua (Invio per saltare): " ;;
        sha_match) printf '%s' "L'hash corrisponde." ;;
        sha_bad) printf '%s' "L'hash è diverso: file danneggiato o incompleto. Eliminalo e ricomincia." ;;
        wait_link) printf '%s' "In attesa del link: fai clic su «Copia indirizzo link» nel browser.\n(Invio = incolla il link a mano)" ;;
        clip_found) printf '%s' "Link rilevato negli appunti: %s. Usarlo? (S/n) " ;;
        wait_timeout) printf '%s' "Tempo scaduto (5 minuti): incolla il link a mano." ;;
        published_found) printf '%s' "Link già generato (iso_links.txt): build %s, ancora valido per %s. Usarlo? (S/n) " ;;
        published_dead) printf '%s' "Questo link pubblicato non risponde (HTTP %s): ritorno al metodo manuale." ;;
        *) return 1 ;;
    esac
}
msg_pt() {
    case "$1" in
        need_sudo) printf '%s' "Execute o script com sudo: sudo bash %s" ;;
        tools_missing) printf '%s' "Ferramentas ausentes:%s" ;;
        install_wimlib) printf '%s' "Instale o wimlib (sem sudo): brew install wimlib" ;;
        no_iso) printf '%s' "Nenhum arquivo .iso encontrado em %s." ;;
        ask_no_iso) printf '%s' "T para baixar o ISO da Microsoft, ou caminho completo do ISO: " ;;
        isos_found) printf '%s' "ISO encontrados em %s:" ;;
        menu_download) printf '%s' "  [T] Baixar um ISO do Windows 11 da Microsoft" ;;
        ask_iso) printf '%s' "Número do ISO a usar (ou T): " ;;
        bad_choice) printf '%s' "Opção inválida." ;;
        iso_selected) printf '%s' "ISO selecionado: %s" ;;
        iso_missing) printf '%s' "ISO não encontrado." ;;
        no_usb) printf '%s' "Nenhuma unidade USB detectada." ;;
        usb_found) printf '%s' "Unidades USB detectadas:" ;;
        ask_usb) printf '%s' "Número da unidade USB a APAGAR: " ;;
        not_in_list) printf '%s' "Esse número não está na lista." ;;
        internal_disk) printf '%s' "%s é um disco interno: operação cancelada." ;;
        root_disk) printf '%s' "%s contém o sistema de arquivos raiz: operação cancelada." ;;
        too_small) printf '%s' "Unidade pequena demais: %s GB para um ISO de %s GB." ;;
        confirm_erase) printf '%s' "Confirmar o apagamento de '%s' (%s)? (S/N) " ;;
        keep_confirm) printf '%s' "'%s' já tem uma disposição compatível: só a partição FAT32 será reformatada, as outras %s partição(ões) são mantidas. Continuar? (S/N) " ;;
        data_warn) printf '%s' "ATENÇÃO: esta unidade tem ficheiros numa partição de dados e a partição FAT32 é demasiado pequena para este ISO (são precisos %s GB). Continuar reparticiona a unidade e APAGA esses ficheiros." ;;
        data_ask) printf '%s' "Para os apagar mesmo assim, escreve %s (Enter para cancelar):  " ;;
        erase_word) printf '%s' "APAGAR" ;;
        data_created) printf '%s' "Partição de dados exFAT 'DONNEES' criada: %s GB para os teus ficheiros (a FAT32 mantém margem para futuras versões do Windows)." ;;
        kept) printf '%s' "Disposição mantida: só a partição FAT32 é reformatada." ;;
        eject_ask) printf '%s' "Ejetar agora a pen USB em segurança? (S/N) " ;;
        eject_ok) printf '%s' "Pen ejetada: já a podes desligar." ;;
        eject_fail) printf '%s' "Não foi possível ejetar (pen ainda em uso?). Fecha as janelas que a usam e ejeta-a pelo sistema antes de a desligar." ;;
        bypass_ask) printf '%s' "Ignorar as perguntas da instalação do Windows (conta local, sem conta Microsoft nem ofertas do Microsoft 365)? (S/N) " ;;
        bypass_name) printf '%s' "Nome da conta local do Windows a criar (prime Enter sem escrever nada para usar: %s): " ;;
        bypass_done) printf '%s' "Ficheiro de respostas escrito na pen: autounattend.xml (conta local '%s'). Os ecrãs de idioma, edição e disco continuam visíveis." ;;
        ua_pc) printf '%s' "Nome do computador (escreve um nome ou prime Enter para o Windows escolher um): " ;;
        ua_lang) printf '%s' "Idioma, teclado e fuso horário: 0 = perguntar-me, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (prime o número, Enter = 0): " ;;
        ua_edition) printf '%s' "Edição: 0 = perguntar-me, 1 = Pro, 2 = Home (prime o número, Enter = 0): " ;;
        ua_auto) printf '%s' "Iniciar sessão automaticamente (sem palavra-passe) no primeiro arranque? (S/N) " ;;
        ua_updates) printf '%s' "Pausar as atualizações automáticas (menos seguro)? (S/N) " ;;
        ua_hw) printf '%s' "Ignorar as verificações de compatibilidade do Windows 11 (TPM, Secure Boot, memória, CPU)? (S/N) " ;;
        recap_key) printf '%s' "Pen de %s GB: procura este tamanho na lista de discos do instalador do Windows." ;;
        preparing) printf '%s' "Preparando a unidade (%s)..." ;;
        partition_fail) printf '%s' "Falha ao particionar %s." ;;
        no_mountpoint) printf '%s' "Não foi possível encontrar o ponto de montagem da unidade." ;;
        part_missing) printf '%s' "Partição não encontrada após o particionamento." ;;
        mkfs_fail) printf '%s' "Falha ao formatar %s em FAT32." ;;
        mount_fail) printf '%s' "Não foi possível montar %s." ;;
        iso_mount_fail_mac) printf '%s' "Não foi possível montar o ISO." ;;
        iso_mount_fail_linux) printf '%s' "Não foi possível montar o ISO (tente: sudo modprobe udf)." ;;
        sources_missing) printf '%s' "Pasta 'sources' não encontrada no ISO montado: ISO inválido ou montado em formato incompleto." ;;
        copying) printf '%s' "Copiando arquivos..." ;;
        copy_err_file) printf '%s' "ERRO de cópia: %s" ;;
        copy_err) printf '%s' "A cópia encontrou um erro. Veja %s" ;;
        bootwim_missing) printf '%s' "sources/boot.wim ausente da unidade: cópia incompleta. Veja %s" ;;
        write_ok) printf '%s' "Teste de gravação na unidade: OK" ;;
        write_fail) printf '%s' "Não é possível gravar em %s" ;;
        splitting) printf '%s' "Dividindo o install.wim..." ;;
        split_done) printf '%s' "Divisão concluída." ;;
        split_fail) printf '%s' "O wimlib falhou (código %s). Últimas linhas de %s:" ;;
        esd_copy) printf '%s' "install.esd detectado: cópia direta." ;;
        esd_fail) printf '%s' "Falha ao copiar o install.esd" ;;
        no_image) printf '%s' "Nem install.wim nem install.esd encontrados no ISO." ;;
        done_mac) printf '%s' "Concluído: a unidade está pronta em %s" ;;
        logs) printf '%s' "Registros: %s, %s (se dividido) e %s" ;;
        eject_hint) printf '%s' "Para ejetá-la com segurança: diskutil eject %s" ;;
        syncing) printf '%s' "Sincronizando a unidade (não a remova ainda)..." ;;
        umount_fail) printf '%s' "Não foi possível desmontar a unidade: não a remova." ;;
        done_linux) printf '%s' "Concluído: a unidade está pronta (%s). Você já pode removê-la." ;;
        bar_size) printf '%s' "%d MB / %d MB" ;;
        bar_speed) printf '%s' "%s MB/s" ;;
        copy_line_speed) printf '%s' "  — %s MB/s em média" ;;
        copy_summary) printf '%s' "Cópia concluída: %s MB em %s — %s MB/s em média." ;;
        split_summary) printf '%s' "Divisão: %s MB em %s — %s MB/s." ;;
        total_speed) printf '%s' "Total gravado na unidade: %s GB em %s — %s MB/s (cache de gravação esvaziado)." ;;
        slow_drive) printf '%s' "Unidade lenta (%s MB/s): uma unidade USB 3.x em uma porta USB 3 seria bem mais rápida." ;;
        curl_needed) printf '%s' "O curl é necessário para baixar o ISO." ;;
        dl_title) printf '%s' "Baixando o ISO do Windows 11 da Microsoft" ;;
        ask_lang) printf '%s' "Idioma da página da Microsoft [%s] (Enter para aceitar, ou outro código, ex.: pt-br): " ;;
        bad_code) printf '%s' "Código inválido: idioma detectado mantido (%s)." ;;
        official_page) printf '%s' "Página oficial: %s" ;;
        no_fixed_link) printf '%s' "A Microsoft não publica um link fixo: o link direto é gerado a cada download\ne só é válido por 24 horas." ;;
        step1) printf '%s' "  1. Abra a página oficial acima no navegador." ;;
        step2) printf '%s' "  2. Em «Baixar a Imagem de Disco do Windows 11 (ISO) para dispositivos x64», escolha o ISO\n     de várias edições, depois o idioma do produto (idioma do seu sistema: %s) e clique em «Confirmar»." ;;
        step3) printf '%s' "  3. Clique com o botão direito no botão de download de 64 bits > «Copiar endereço do link»: o script o detecta sozinho.\n     Cole o link COMPLETO, incluindo o que vem depois de «.iso?»: é essa parte que o autoriza." ;;
        clip_unreadable) printf '%s' "Área de transferência ilegível aqui (ferramenta ausente): cole o link manualmente." ;;
        ask_url) printf '%s' "Cole aqui a URL do link (https://...microsoft.com/....iso): " ;;
        url_refused) printf '%s' "URL recusada: deve ser https, de um domínio *.microsoft.com, e o caminho deve terminar em .iso." ;;
        file_exists) printf '%s' "%s já existe em %s: usando o arquivo existente." ;;
        querying) printf '%s' "Consultando o servidor da Microsoft..." ;;
        size_unknown) printf '%s' "Tamanho do ISO não informado: supondo %s GB." ;;
        http_err) printf '%s' "O servidor da Microsoft respondeu HTTP %s (000 = sem resposta): link expirado, incompleto (sem a parte depois de «.iso?») ou rede inacessível.\nGere um novo link na página oficial." ;;
        size_line) printf '%s' "  Tamanho do ISO       : %s GB" ;;
        need_line) printf '%s' "  Espaço necessário    : %s GB (ISO + margem; sem cópia temporária para a divisão)" ;;
        free_line) printf '%s' "  Espaço livre         : %s GB (%s)" ;;
        insufficient) printf '%s' "Espaço em disco insuficiente: faltam %s GB." ;;
        confirm_dl) printf '%s' "Iniciar o download em %s? (S/N) " ;;
        dl_running) printf '%s' "Baixando (retomável se interrompido)..." ;;
        dl_fail) printf '%s' "Falha no download (link expirado ou rede?). Gere um novo link na página da Microsoft." ;;
        dl_done) printf '%s' "Download concluído: %s" ;;
        dl_speed) printf '%s' "Velocidade média de download: %s MB/s" ;;
        sha_calc) printf '%s' "Calculando o hash SHA-256 (alguns minutos)..." ;;
        sha_ok) printf '%s' "O hash corresponde ao publicado pela Microsoft (%s)." ;;
        sha_unknown) printf '%s' "Hash não reconhecido (versão ou idioma ausente de iso_hashes.txt, ou arquivo alterado)." ;;
        sha_computed) printf '%s' "SHA-256 calculado: %s" ;;
        ask_sha) printf '%s' "Hash SHA-256 exibido pela Microsoft para este idioma (Enter para ignorar): " ;;
        sha_match) printf '%s' "O hash corresponde." ;;
        sha_bad) printf '%s' "O hash é diferente: arquivo corrompido ou incompleto. Exclua-o e recomece." ;;
        wait_link) printf '%s' "Aguardando o link: clique em «Copiar endereço do link» no navegador.\n(Enter = colar o link manualmente)" ;;
        clip_found) printf '%s' "Link detectado na área de transferência: %s. Usá-lo? (S/n) " ;;
        wait_timeout) printf '%s' "Tempo esgotado (5 minutos): cole o link manualmente." ;;
        published_found) printf '%s' "Link já gerado (iso_links.txt): build %s, ainda válido por %s. Usá-lo? (S/n) " ;;
        published_dead) printf '%s' "Esse link publicado não responde (HTTP %s): voltando ao método manual." ;;
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
    case "$rep" in [oOyYsSjJ]*) ;; *) return 1 ;; esac

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
nom=$(info_disque "$dev" nom)

# --- Disposition existante : on ne repartitionne pas une clé déjà compatible, et on protège les fichiers de la partition de données ---
besoin_boot=$((iso_octets + 512 * 1024 * 1024))
garde=0; risque=0; nb_autres=0
tranches=$(diskutil list "$dev" | awk '$NF ~ /^disk[0-9]+s[0-9]+$/ {print $NF}')
s1=$(printf '%s\n' "$tranches" | head -1)
if [ -n "$s1" ]; then
    fs1=$(diskutil info "$s1" | sed -En 's/^ *File System Personality: *//p' | head -1)
    sz1=$(info_disque "$s1" octets)
    case "$fs1" in *FAT32*) [ "${sz1:-0}" -ge "$besoin_boot" ] && [ "${sz1:-0}" -le 34359738368 ] && garde=1 ;; esac
    for t in $(printf '%s\n' "$tranches" | tail -n +2); do
        nb_autres=$((nb_autres + 1))
        fs=$(diskutil info "$t" | sed -En 's/^ *File System Personality: *//p' | head -1)
        [ -z "$fs" ] && continue
        diskutil mount readOnly "$t" >/dev/null 2>&1
        pm=$(diskutil info "$t" | sed -En 's/^ *Mount Point: *//p' | head -1)
        if [ -n "$pm" ] && [ -d "$pm" ]; then
            if [ -n "$(ls -A "$pm" 2>/dev/null | grep -v '^\.' | head -1)" ]; then risque=1; fi
            diskutil unmount "$t" >/dev/null 2>&1
        else
            risque=1   # montage impossible : on protège par précaution
        fi
    done
fi
if [ "$garde" -eq 1 ]; then
    read -r -p "$(msg keep_confirm "$nom" "$nb_autres")" rep
    case "$rep" in [oOyYsSjJ]*) ;; *) exit 0 ;; esac
else
    if [ "$risque" -eq 1 ]; then
        erreur "$(msg data_warn "$(en_go "$besoin_boot")")"
        mot=$(msg erase_word)
        read -r -p "$(msg data_ask "$mot")" rep
        [ "$rep" = "$mot" ] || exit 0
    else
        read -r -p "$(msg confirm_erase "$nom" "$dev")" rep
        case "$rep" in [oOyYsSjJ]*) ;; *) exit 0 ;; esac
    fi
fi

# --- Installation automatisée : questions de la première configuration de Windows ---
oui() { case "$1" in [oOyYsSjJ]*) return 0 ;; esac; return 1; }
touche() { TOUCHE=""; printf '%s' "$(msg "$1")" >&2; IFS= read -r -n 1 TOUCHE || true; [ -n "$TOUCHE" ] && echo >&2; return 0; }
choix() { touche "$1"; case "$TOUCHE" in [0-9]) [ "$TOUCHE" -le "$2" ] && { echo "$TOUCHE"; return; } ;; esac; echo 0; }
bypass=0; nom_compte=""; nom_pc=""; i_loc=0; i_ed=0; ua_auto=0; ua_upd=0; ua_hw=0
touche bypass_ask
if oui "$TOUCHE"; then
    bypass=1
    read -r -p "$(msg bypass_name "Utilisateur")" saisie
    nom_compte=$(printf '%s' "$saisie" | LC_ALL=C tr -d '\000-\037"/\\[]:;|=,+*?<>@%&\047' | sed 's/^ *//; s/ *$//; s/\.*$//')
    nom_compte="${nom_compte:0:20}"; nom_compte=$(printf '%s' "$nom_compte" | sed 's/ *$//')
    [ -n "$nom_compte" ] || nom_compte="Utilisateur"
    read -r -p "$(msg ua_pc)" saisie
    nom_pc=$(printf '%s' "$saisie" | tr ' _' '--' | LC_ALL=C tr -cd 'A-Za-z0-9-' | sed 's/^-*//; s/-*$//' | cut -c1-15 | sed 's/-*$//')
    case "$nom_pc" in *[!0-9]*) ;; *) nom_pc="" ;; esac
    i_loc=$(choix ua_lang 7)
    i_ed=$(choix ua_edition 2)
    touche ua_auto; oui "$TOUCHE" && ua_auto=1
    touche ua_updates; oui "$TOUCHE" && ua_upd=1
    touche ua_hw; oui "$TOUCHE" && ua_hw=1
fi

# --- Préparation de la clé ---
# MBR + FAT32 : avec GPT, macOS ajoute une partition EFI vide qui peut gêner le démarrage UEFI.
info "$(msg preparing "$dev")"
diskutil unmountDisk force "$dev" >/dev/null 2>&1
if [ "$garde" -eq 1 ]; then
    ok "$(msg kept)"
    if ! diskutil eraseVolume FAT32 WIN11 "$s1"; then
        erreur "$(msg partition_fail "$dev")"
        exit 1
    fi
    boot_slice="$s1"
else
    # FAT32 : ISO + 2 Go de marge (32 Go maximum) ; le reste en exFAT pour les données de l'utilisateur
    fat_go=$(( (iso_octets + 2147483648 + 1073741823) / 1073741824 ))
    [ "$fat_go" -gt 32 ] && fat_go=32
    reste=$(( ${octets_cle:-0} - fat_go * 1073741824 ))
    if [ "$reste" -ge $((3 * 1073741824)) ]; then
        diskutil partitionDisk "$dev" MBR FAT32 WIN11 "${fat_go}G" ExFAT DONNEES R
        rc=$?
        [ "$rc" -eq 0 ] && ok "$(msg data_created "$(en_go "$reste")")"
    else
        if [ "${octets_cle:-0}" -gt 32000000000 ]; then taille_part="32G"; else taille_part="R"; fi
        diskutil partitionDisk "$dev" MBR FAT32 WIN11 "$taille_part"
        rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        erreur "$(msg partition_fail "$dev")"
        exit 1
    fi
    boot_slice="${dev}s1"
fi
sleep 2
usb=$(diskutil info "$boot_slice" | sed -En 's/^ *Mount Point: *//p' | head -1)
if [ -z "$usb" ] || [ ! -d "$usb" ]; then
    diskutil mount "$boot_slice" >/dev/null 2>&1
    usb=$(diskutil info "$boot_slice" | sed -En 's/^ *Mount Point: *//p' | head -1)
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

# --- Fichier de réponses automatiques (racine de la clé) ---
if [ "$bypass" -eq 1 ]; then
    ns='processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
    xml=""
    ajoute() { xml="$xml$1"$'\n'; }
    reg_ligne() { ajoute "        <RunSynchronousCommand wcm:action=\"add\"><Order>$1</Order><Path>reg.exe add \"$2\" /v $3 /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>"; }
    loc=""; inp=""; tz=""
    case "$i_loc" in
        1) loc="fr-FR"; inp="040c:0000040c"; tz="Romance Standard Time" ;;
        2) loc="en-GB"; inp="0809:00000809"; tz="GMT Standard Time" ;;
        3) loc="en-US"; inp="0409:00000409" ;;
        4) loc="de-DE"; inp="0407:00000407"; tz="W. Europe Standard Time" ;;
        5) loc="es-ES"; inp="0c0a:0000040a"; tz="Romance Standard Time" ;;
        6) loc="it-IT"; inp="0410:00000410"; tz="W. Europe Standard Time" ;;
        7) loc="pt-PT"; inp="0816:00000816"; tz="GMT Standard Time" ;;
    esac
    cle=""
    [ "$i_ed" -eq 1 ] && cle="W269N-WFGWX-YVC9B-4J6C9-T83GX"
    [ "$i_ed" -eq 2 ] && cle="TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"
    ajoute '<?xml version="1.0" encoding="utf-8"?>'
    ajoute '<unattend xmlns="urn:schemas-microsoft-com:unattend">'
    if [ -n "$loc" ] || [ -n "$cle" ] || [ "$ua_hw" -eq 1 ]; then
        ajoute '  <settings pass="windowsPE">'
        if [ -n "$loc" ]; then
            ajoute "    <component name=\"Microsoft-Windows-International-Core-WinPE\" $ns>"
            ajoute "      <SetupUILanguage><UILanguage>$loc</UILanguage></SetupUILanguage>"
            ajoute "      <InputLocale>$inp</InputLocale>"
            ajoute "      <SystemLocale>$loc</SystemLocale>"
            ajoute "      <UILanguage>$loc</UILanguage>"
            ajoute "      <UserLocale>$loc</UserLocale>"
            ajoute '    </component>'
        fi
        if [ -n "$cle" ] || [ "$ua_hw" -eq 1 ]; then
            ajoute "    <component name=\"Microsoft-Windows-Setup\" $ns>"
            if [ "$ua_hw" -eq 1 ]; then
                ajoute '      <RunSynchronous>'
                reg_ligne 1 'HKLM\SYSTEM\Setup\LabConfig' BypassTPMCheck
                reg_ligne 2 'HKLM\SYSTEM\Setup\LabConfig' BypassSecureBootCheck
                reg_ligne 3 'HKLM\SYSTEM\Setup\LabConfig' BypassRAMCheck
                reg_ligne 4 'HKLM\SYSTEM\Setup\LabConfig' BypassCPUCheck
                ajoute '      </RunSynchronous>'
            fi
            [ -n "$cle" ] && ajoute "      <UserData><AcceptEula>true</AcceptEula><ProductKey><Key>$cle</Key><WillShowUI>OnError</WillShowUI></ProductKey></UserData>"
            ajoute '    </component>'
        fi
        ajoute '  </settings>'
    fi
    pol='HKLM\SOFTWARE\Policies\Microsoft\Windows'
    ajoute '  <settings pass="specialize">'
    ajoute "    <component name=\"Microsoft-Windows-Deployment\" $ns>"
    ajoute '      <RunSynchronous>'
    reg_ligne 1 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' BypassNRO
    reg_ligne 2 "$pol\\CloudContent" DisableWindowsConsumerFeatures
    reg_ligne 3 "$pol\\CloudContent" DisableSoftLanding
    reg_ligne 4 "$pol\\OOBE" DisablePrivacyExperience
    reg_ligne 5 'HKLM\SOFTWARE\Policies\Microsoft\Edge' HideFirstRunExperience
    if [ "$ua_upd" -eq 1 ]; then
        reg_ligne 6 "$pol\\WindowsUpdate\\AU" NoAutoUpdate
        reg_ligne 7 "$pol\\WindowsUpdate" ExcludeWUDriversInQualityUpdate
    fi
    ajoute '      </RunSynchronous>'
    ajoute '    </component>'
    if [ -n "$nom_pc" ] || [ -n "$tz" ]; then
        ajoute "    <component name=\"Microsoft-Windows-Shell-Setup\" $ns>"
        [ -n "$nom_pc" ] && ajoute "      <ComputerName>$nom_pc</ComputerName>"
        [ -n "$tz" ] && ajoute "      <TimeZone>$tz</TimeZone>"
        ajoute '    </component>'
    fi
    ajoute '  </settings>'
    ajoute '  <settings pass="oobeSystem">'
    if [ -n "$loc" ]; then
        ajoute "    <component name=\"Microsoft-Windows-International-Core\" $ns>"
        ajoute "      <InputLocale>$inp</InputLocale>"
        ajoute "      <SystemLocale>$loc</SystemLocale>"
        ajoute "      <UILanguage>$loc</UILanguage>"
        ajoute "      <UserLocale>$loc</UserLocale>"
        ajoute '    </component>'
    fi
    ajoute "    <component name=\"Microsoft-Windows-Shell-Setup\" $ns>"
    ajoute '      <OOBE><HideEULAPage>true</HideEULAPage><HideOEMRegistrationScreen>true</HideOEMRegistrationScreen><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE><ProtectYourPC>3</ProtectYourPC></OOBE>'
    ajoute '      <UserAccounts><LocalAccounts><LocalAccount wcm:action="add">'
    ajoute "        <Name>$nom_compte</Name><DisplayName>$nom_compte</DisplayName><Group>Administrators</Group>"
    ajoute '      </LocalAccount></LocalAccounts></UserAccounts>'
    [ "$ua_auto" -eq 1 ] && ajoute "      <AutoLogon><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>$nom_compte</Username><Password><Value></Value><PlainText>true</PlainText></Password></AutoLogon>"
    ajoute '    </component>'
    ajoute '  </settings>'
    ajoute '</unattend>'
    printf '%s' "$xml" > "$usb/autounattend.xml"
    ok "$(msg bypass_done "$nom_compte")"
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
echo "$(msg recap_key "$(awk -v s="$octets_cle" 'BEGIN{printf "%.1f", s/1073741824}')")"
echo "$(msg logs "$log" "$dlog" "$dossier/contenu_cle.txt")"
read -r -p "$(msg eject_ask)" rep
case "$rep" in
    [oOyYsSjJ]*)
        cd / || true
        if diskutil eject "$dev" >/dev/null 2>&1; then
            ok "$(msg eject_ok)"
        else
            avert "$(msg eject_fail)"
        fi
        ;;
esac
