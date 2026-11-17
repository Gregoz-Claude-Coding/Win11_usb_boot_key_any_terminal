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

# Barre de progression : $1 = octets faits, $2 = octets totaux
barre() {
    local fait=$1 total=$2 pct plein
    [ "$total" -gt 0 ] || total=1
    pct=$(( fait * 100 / total ))
    [ "$pct" -gt 99 ] && pct=99
    plein=$(( pct * 40 / 100 ))
    printf '\r[%s%s] %3d%%  %d Mo / %d Mo ' \
        "$(printf '%*s' "$plein" '' | tr ' ' '#')" \
        "$(printf '%*s' $((40 - plein)) '' | tr ' ' '.')" \
        "$pct" $((fait / 1048576)) $((total / 1048576))
}

# Copie tout le contenu de $1 vers $2, sauf install.wim et autorun.inf (insensible à la casse).
# Affiche chaque fichier copié.
copier_fichiers() {
    local src=$1 dst=$2 total n=0 f d rel reld
    find "$src" -type d -print0 | while IFS= read -r -d '' d; do
        reld=${d#"$src"}
        mkdir -p "$dst/$reld"
    done
    total=$(find "$src" -type f ! -iname 'install.wim' ! -iname 'autorun.inf' | wc -l | tr -d ' ')
    while IFS= read -r -d '' f; do
        rel=${f#"$src"/}
        n=$((n + 1))
        printf '[%d/%d] %s\n' "$n" "$total" "$rel"
        if ! cp "$f" "$dst/$rel"; then
            echo "ERREUR de copie : $rel"
            return 1
        fi
    done < <(find "$src" -type f ! -iname 'install.wim' ! -iname 'autorun.inf' -print0)
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
URL_HASHES="https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/versions_iso.txt"
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

# Télécharge l'ISO depuis Microsoft dans $dossier. Renseigne la variable globale $iso.
# Retourne 1 en cas d'abandon ou d'échec.
telecharger_depuis_microsoft() {
    local url nom taille besoin libre rep attendu code calc reconnu loc page
    if ! command -v curl >/dev/null 2>&1; then
        erreur "curl est nécessaire pour télécharger l'ISO."
        return 1
    fi
    info "Téléchargement de l'ISO Windows 11 depuis Microsoft"
    loc=$(langue_systeme)
    read -r -p "Langue de la page Microsoft [$loc] (Entrée pour valider, ou autre code, ex. en-us) : " rep
    rep=$(printf '%s' "$rep" | tr 'A-Z_' 'a-z-' | tr -d '[:space:]')
    if [ -n "$rep" ]; then
        if printf '%s' "$rep" | grep -Eq '^[a-z]{2,3}(-[a-z0-9]{2,4}){1,2}$'; then
            loc="$rep"
        else
            avert "Code invalide : langue détectée conservée ($loc)."
        fi
    fi
    page="https://www.microsoft.com/$loc/software-download/windows11"
    echo "Page officielle : $page"
    echo "Microsoft ne publie pas de lien fixe : le lien direct est généré à chaque téléchargement"
    echo "et n'est valable que 24 heures."
    echo "  1. Ouvre la page officielle ci-dessus dans ton navigateur."
    echo "  2. Dans « Télécharger l'image disque Windows 11 (ISO) pour les appareils x64 », choisis l'ISO"
    echo "     multi-éditions, puis la langue du produit (ta langue système : $loc) et clique sur « Confirmer »."
    echo "  3. Clic droit sur le bouton de téléchargement 64 bits > « Copier l'adresse du lien »."
    echo "     Colle le lien ENTIER, y compris ce qui suit « .iso? » : c'est ce qui l'autorise."
    read -r -p "Colle ici l'URL du lien (https://...microsoft.com/....iso) : " url
    url=$(printf '%s' "$url" | tr -d '[:space:]"')
    if ! url_valide "$url"; then
        erreur "URL refusée : elle doit être en https, sur un domaine *.microsoft.com, et son chemin doit se terminer par .iso."
        return 1
    fi
    nom=$(nom_fichier_url "$url")
    if [ -f "$dossier/$nom" ]; then
        avert "$nom existe déjà dans $dossier : utilisation du fichier existant."
        iso="$dossier/$nom"
        return 0
    fi

    info "Interrogation du serveur Microsoft..."
    taille=$(taille_distante "$url")
    if [ "$taille" -eq 0 ]; then
        code=$(code_http "$url")
        case "$code" in
            2??)
                taille=$((8 * 1024 * 1024 * 1024))
                avert "Taille de l'ISO non communiquée : hypothèse de $(en_go "$taille") Go."
                ;;
            *)
                erreur "Le serveur Microsoft a répondu HTTP $code (000 = pas de réponse) : lien expiré, incomplet (sans la partie après « .iso? ») ou réseau injoignable."
                erreur "Génère un nouveau lien sur la page officielle."
                return 1
                ;;
        esac
    fi
    # L'ISO est monté (pas extrait) et install.wim est découpé directement sur la clé :
    # il faut donc seulement la place de l'ISO, plus une marge pour les journaux.
    besoin=$((taille + MARGE_OCTETS))
    libre=$(espace_libre "$dossier")
    echo "  Taille de l'ISO     : $(en_go "$taille") Go"
    echo "  Espace nécessaire   : $(en_go "$besoin") Go (ISO + marge ; pas de copie temporaire pour le découpage)"
    echo "  Espace libre        : $(en_go "$libre") Go ($dossier)"
    if [ "$libre" -lt "$besoin" ]; then
        erreur "Espace disque insuffisant : il manque $(en_go $((besoin - libre))) Go."
        return 1
    fi
    read -r -p "Lancer le téléchargement vers $dossier/$nom ? (O/N) " rep
    case "$rep" in [oOyY]*) ;; *) return 1 ;; esac

    info "Téléchargement (reprise possible si interrompu)..."
    if ! curl -L --fail -C - --progress-bar -o "$dossier/$nom.part" "$url"; then
        erreur "Échec du téléchargement (lien expiré ou réseau ?). Génère un nouveau lien sur la page Microsoft."
        [ -s "$dossier/$nom.part" ] || rm -f "$dossier/$nom.part"
        return 1
    fi
    mv "$dossier/$nom.part" "$dossier/$nom" || return 1
    ok "Téléchargement terminé : $dossier/$nom"

    info "Calcul de l'empreinte SHA-256 (quelques minutes)..."
    calc=$(calculer_sha256 "$dossier/$nom")
    reconnu=$(curl -fsSL -m 15 "$URL_HASHES" 2>/dev/null | tr -d '\r' | grep -v '^[[:space:]]*#' |
              awk -F';' -v h="$calc" 'toupper($3)==toupper(h) {print $1 " - " $2; exit}')
    if [ -n "$reconnu" ]; then
        ok "Empreinte conforme à celle publiée par Microsoft ($reconnu)."
    else
        avert "Empreinte non reconnue (version ou langue absente de versions_iso.txt, ou fichier altéré)."
        echo "SHA-256 calculé : $calc"
        read -r -p "Empreinte SHA-256 affichée par Microsoft pour cette langue (Entrée pour ignorer) : " attendu
        if [ -n "$attendu" ]; then
            if verifier_sha256 "$dossier/$nom" "$attendu"; then
                ok "Empreinte conforme."
            else
                erreur "Empreinte différente : fichier corrompu ou incomplet. Supprime-le et recommence."
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

# --- Droits administrateur ---
if [ "$(id -u)" -ne 0 ]; then
    erreur "Lance le script avec sudo : sudo bash $0"
    exit 1
fi

# --- Outils nécessaires ---
manquants=""
for outil in diskutil hdiutil wimlib-imagex; do
    command -v "$outil" >/dev/null 2>&1 || manquants="$manquants $outil"
done
if [ -n "$manquants" ]; then
    erreur "Outils manquants :$manquants"
    case "$manquants" in
        *wimlib-imagex*) erreur "Installe wimlib (sans sudo) : brew install wimlib" ;;
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
    avert "Aucun fichier .iso trouvé dans $dossier."
    read -r -p "T pour télécharger l'ISO depuis Microsoft, ou chemin complet de l'ISO : " iso
    case "$iso" in
        [tT]) telecharger_depuis_microsoft || exit 1 ;;
        *)    iso="${iso//\\ / }"; iso="${iso%\"}"; iso="${iso#\"}" ;;
    esac
else
    info "ISO trouvés dans $dossier :"
    i=1
    for f in "${isos[@]}"; do
        octets=$(wc -c < "$f")
        printf '  [%d] %s  (%s Go)\n' "$i" "$(basename "$f")" "$(en_go "$octets")"
        i=$((i + 1))
    done
    echo "  [T] Télécharger un ISO Windows 11 depuis Microsoft"
    read -r -p "Numéro de l'ISO à utiliser (ou T) : " choix
    case "$choix" in
        [tT]) telecharger_depuis_microsoft || exit 1 ;;
        ''|*[!0-9]*) erreur "Choix invalide."; exit 1 ;;
        *)
            if [ "$choix" -lt 1 ] || [ "$choix" -gt "${#isos[@]}" ]; then
                erreur "Choix invalide."
                exit 1
            fi
            iso="${isos[$((choix - 1))]}"
            ;;
    esac
    ok "ISO sélectionné : $iso"
fi
[ -f "$iso" ] || { erreur "ISO introuvable."; exit 1; }

# --- Choix de la clé USB ---
disques=()
while IFS= read -r d; do disques+=("$d"); done < <(diskutil list external physical | awk '/^\/dev\/disk/ {print $1}')
if [ "${#disques[@]}" -eq 0 ]; then
    erreur "Aucun disque USB externe détecté."
    exit 1
fi
info "Disques externes détectés :"
i=1
for d in "${disques[@]}"; do
    printf '  [%d] %s  %s  %s\n' "$i" "$d" "$(info_disque "$d" nom)" "$(info_disque "$d" taille)"
    i=$((i + 1))
done
read -r -p "Numéro du disque USB à EFFACER : " choix
case "$choix" in ''|*[!0-9]*) erreur "Choix invalide."; exit 1 ;; esac
if [ "$choix" -lt 1 ] || [ "$choix" -gt "${#disques[@]}" ]; then
    erreur "Ce numéro n'est pas dans la liste."
    exit 1
fi
dev="${disques[$((choix - 1))]}"
if diskutil info "$dev" | grep -Eqi 'Internal:[[:space:]]+Yes'; then
    erreur "$dev est un disque interne : abandon."
    exit 1
fi
octets_cle=$(info_disque "$dev" octets)
iso_octets=$(wc -c < "$iso" | tr -d ' ')
if [ "${octets_cle:-0}" -gt 0 ] && [ "$octets_cle" -lt "$iso_octets" ]; then
    erreur "Clé trop petite : $(en_go "$octets_cle") Go pour un ISO de $(en_go "$iso_octets") Go."
    exit 1
fi
read -r -p "Confirmer l'effacement de '$(info_disque "$dev" nom)' ($dev) ? (O/N) " rep
case "$rep" in [oOyY]*) ;; *) exit 0 ;; esac

# --- Préparation de la clé ---
# MBR + FAT32 : avec GPT, macOS ajoute une partition EFI vide qui peut gêner le démarrage UEFI.
if [ "${octets_cle:-0}" -gt 32000000000 ]; then taille_part="32G"; else taille_part="R"; fi
info "Préparation de la clé ($dev)..."
diskutil unmountDisk force "$dev" >/dev/null 2>&1
if ! diskutil partitionDisk "$dev" MBR FAT32 WIN11 "$taille_part"; then
    erreur "Échec du partitionnement de $dev."
    exit 1
fi
sleep 2
usb=$(diskutil info "${dev}s1" | sed -En 's/^ *Mount Point: *//p' | head -1)
if [ -z "$usb" ] || [ ! -d "$usb" ]; then
    diskutil mount "${dev}s1" >/dev/null 2>&1
    usb=$(diskutil info "${dev}s1" | sed -En 's/^ *Mount Point: *//p' | head -1)
fi
if [ -z "$usb" ] || [ ! -d "$usb" ]; then
    erreur "Impossible de trouver le point de montage de la clé."
    exit 1
fi
mdutil -i off "$usb" >/dev/null 2>&1   # pas d'indexation Spotlight sur la clé

# --- Montage de l'ISO ---
hdiutil detach "$isomnt" -force >/dev/null 2>&1
mkdir -p "$isomnt"
if ! hdiutil attach -nobrowse -readonly -noverify -mountpoint "$isomnt" "$iso" >/dev/null; then
    erreur "Impossible de monter l'ISO."
    exit 1
fi
src="$isomnt"
if [ ! -d "$src/sources" ]; then
    erreur "Dossier 'sources' introuvable dans l'ISO monté : ISO invalide ou monté dans un format incomplet."
    exit 1
fi

# --- Copie (tout sauf install.wim et autorun.inf), liste affichée + journal ---
info "Copie des fichiers..."
log="$dossier/copie_cle.log"
copier_fichiers "$src" "$usb" 2>&1 | tee "$log"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    erreur "La copie a rencontré une erreur. Voir $log"
    exit 1
fi
if [ -z "$(find "$usb/sources" -maxdepth 1 -iname 'boot.wim' 2>/dev/null)" ]; then
    erreur "sources/boot.wim absent de la clé : copie incomplète. Voir $log"
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
        ok "Écriture sur la clé : OK"
    else
        erreur "Écriture impossible sur $dst"
        exit 1
    fi

    # 2. Découpage (limite FAT32 : 4 Go) directement sur la clé, avec barre de progression
    total=$(wc -c < "$wim" | tr -d ' ')
    info "Découpage de install.wim..."
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
        ok "Découpage terminé."
    else
        erreur "Échec de wimlib (code $rc). Dernières lignes de $dlog :"
        tail -n 15 "$dlog"
        rm -f "$dst"/install*.swm
        exit 1
    fi
elif [ -n "$esd" ]; then
    avert "install.esd détecté : copie directe."
    cp "$esd" "$dst/" || { erreur "Échec de la copie de install.esd"; exit 1; }
else
    erreur "Ni install.wim ni install.esd trouvé dans l'ISO."
    exit 1
fi

# --- Nettoyage des fichiers système macOS, puis inventaire de la clé ---
sync
rm -rf "$usb/.fseventsd" "$usb/.Spotlight-V100" "$usb/.Trashes" "$usb/.DS_Store" 2>/dev/null
(
    cd "$usb" && find . -type f -print0 | while IFS= read -r -d '' f; do
        printf '%s\t%s Mo\n' "${f#./}" "$(awk -v s="$(wc -c < "$f")" 'BEGIN{printf "%.1f", s/1048576}')"
    done
) > "$dossier/contenu_cle.txt"

sync
ok "Terminé : clé prête sur $usb"
echo "Journaux : $log, $dlog (si découpage) et $dossier/contenu_cle.txt"
echo "Pour l'éjecter proprement : diskutil eject $dev"
