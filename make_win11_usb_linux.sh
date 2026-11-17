#!/usr/bin/env bash
# Création d'une clé USB bootable Windows 11 (UEFI/GPT, FAT32) à partir d'un ISO — Linux
#
# Paquets nécessaires :
#   Debian / Ubuntu : sudo apt install wimtools parted dosfstools
#   Fedora          : sudo dnf install wimlib-utils parted dosfstools
#   Arch            : sudo pacman -S wimlib parted dosfstools
# Usage : cd <dossier contenant l'ISO> && sudo bash make_win11_usb_linux.sh

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

# Langue du système (Linux) : variables d'environnement, sinon locale
langue_systeme() {
    local l="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    [ -n "$l" ] || l=$(locale 2>/dev/null | sed -n 's/^LANG=//p' | tr -d '"')
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

# Exécute la commande « $@ » avec l'environnement graphique de l'utilisateur qui a lancé sudo
en_tant_qu_utilisateur() {
    local u="${SUDO_USER:-}" uid
    if [ -z "$u" ] || [ "$u" = "root" ]; then
        "$@"
        return
    fi
    uid=$(id -u "$u" 2>/dev/null)
    sudo -u "$u" env DISPLAY="${DISPLAY:-:0}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
        XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" "$@"
}

# Ouvre l'URL $1 dans le navigateur par défaut (échec silencieux)
ouvrir_page() {
    if command -v xdg-open >/dev/null 2>&1; then
        en_tant_qu_utilisateur xdg-open "$1" >/dev/null 2>&1 &
    fi
    return 0
}

# 0 si un outil de lecture du presse-papiers est installé
presse_papiers_disponible() {
    command -v wl-paste >/dev/null 2>&1 || command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1
}

# Contenu du presse-papiers de l'utilisateur
lire_presse_papiers() {
    if command -v wl-paste >/dev/null 2>&1; then
        en_tant_qu_utilisateur wl-paste --no-newline 2>/dev/null
    elif command -v xclip >/dev/null 2>&1; then
        en_tant_qu_utilisateur xclip -selection clipboard -o 2>/dev/null
    elif command -v xsel >/dev/null 2>&1; then
        en_tant_qu_utilisateur xsel --clipboard --output 2>/dev/null
    fi
}

# Attend que l'utilisateur copie le lien dans le presse-papiers. Renseigne $url si un lien valide est confirmé.
# Entrée = abandonner l'attente (le lien sera alors collé à la main). Délai maximal : 5 minutes.
attendre_lien() {
    local dernier="" c saisie rep nom rc i=0 max=300
    echo "En attente du lien : clique sur « Copier l'adresse du lien » dans le navigateur."
    echo "(Entrée = coller le lien à la main)"
    while [ "$i" -lt "$max" ]; do
        c=$(lire_presse_papiers 2>/dev/null | head -c 8192 | tr -d '[:space:]"')
        if [ -n "$c" ] && [ "$c" != "$dernier" ] && url_valide "$c"; then
            nom=$(nom_fichier_url "$c")
            read -r -p "Lien détecté dans le presse-papiers : $nom. L'utiliser ? (O/n) " rep
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
    avert "Délai dépassé (5 minutes) : colle le lien à la main."
    return 0
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
    echo "  3. Clic droit sur le bouton de téléchargement 64 bits > « Copier l'adresse du lien » : le script la détecte tout seul."
    echo "     Colle le lien ENTIER, y compris ce qui suit « .iso? » : c'est ce qui l'autorise."
    ouvrir_page "$page"
    url=""
    if presse_papiers_disponible; then
        attendre_lien
    else
        avert "Presse-papiers illisible ici (outil absent) : colle le lien à la main."
    fi
    if [ -z "$url" ]; then
        read -r -p "Colle ici l'URL du lien (https://...microsoft.com/....iso) : " url
        url=$(printf '%s' "$url" | tr -d '[:space:]"')
    fi
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

# --- Droits administrateur ---
if [ "$(id -u)" -ne 0 ]; then
    erreur "Lance le script avec sudo : sudo bash $0"
    exit 1
fi

# --- Outils nécessaires ---
manquants=""
for outil in lsblk parted mkfs.vfat wimlib-imagex wipefs mount umount; do
    command -v "$outil" >/dev/null 2>&1 || manquants="$manquants $outil"
done
if [ -n "$manquants" ]; then
    erreur "Outils manquants :$manquants"
    erreur "Debian/Ubuntu : sudo apt install wimtools parted dosfstools"
    erreur "Fedora        : sudo dnf install wimlib-utils parted dosfstools"
    erreur "Arch          : sudo pacman -S wimlib parted dosfstools"
    exit 1
fi

dossier="$PWD"
isomnt="$dossier/iso_mnt"
usbmnt="$dossier/usb_mnt"

# --- Nettoyage en sortie (succès, erreur ou Ctrl-C) ---
nettoyage() {
    cd "$dossier" 2>/dev/null
    umount "$isomnt" 2>/dev/null
    rmdir "$isomnt" 2>/dev/null
    if mountpoint -q "$usbmnt" 2>/dev/null; then
        sync
        umount "$usbmnt" 2>/dev/null
    fi
    rmdir "$usbmnt" 2>/dev/null
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
for d in $(lsblk -dnpo NAME,TRAN,TYPE 2>/dev/null | awk '$2=="usb" && $3=="disk" {print $1}'); do
    b=$(lsblk -dnbo SIZE "$d" 2>/dev/null)
    [ "${b:-0}" -gt 0 ] && disques+=("$d")
done
if [ "${#disques[@]}" -eq 0 ]; then
    erreur "Aucune clé USB détectée."
    exit 1
fi
info "Clés USB détectées :"
i=1
for d in "${disques[@]}"; do
    printf '  [%d] %s  %s  %s\n' "$i" "$d" \
        "$(lsblk -dnpo MODEL "$d" | sed 's/ *$//' | tr -cd '[:print:]')" "$(lsblk -dnpo SIZE "$d")"
    i=$((i + 1))
done
read -r -p "Numéro de la clé USB à EFFACER : " choix
case "$choix" in ''|*[!0-9]*) erreur "Choix invalide."; exit 1 ;; esac
if [ "$choix" -lt 1 ] || [ "$choix" -gt "${#disques[@]}" ]; then
    erreur "Ce numéro n'est pas dans la liste."
    exit 1
fi
dev="${disques[$((choix - 1))]}"
if lsblk -lnpo MOUNTPOINT "$dev" | grep -qx '/'; then
    erreur "$dev contient le système de fichiers racine : abandon."
    exit 1
fi
octets_cle=$(lsblk -dnbo SIZE "$dev")
iso_octets=$(wc -c < "$iso" | tr -d ' ')
if [ "${octets_cle:-0}" -gt 0 ] && [ "$octets_cle" -lt "$iso_octets" ]; then
    erreur "Clé trop petite : $(en_go "$octets_cle") Go pour un ISO de $(en_go "$iso_octets") Go."
    exit 1
fi
nom=$(lsblk -dnpo MODEL "$dev" | sed 's/ *$//' | tr -cd '[:print:]')
read -r -p "Confirmer l'effacement de '$nom' ($dev) ? (O/N) " rep
case "$rep" in [oOyY]*) ;; *) exit 0 ;; esac

# --- Préparation de la clé (GPT + FAT32, 32 Go maximum) ---
if [ "$octets_cle" -gt $((32 * 1024 * 1024 * 1024)) ]; then fin="32GiB"; else fin="100%"; fi
info "Préparation de la clé ($dev)..."
for p in $(lsblk -lnpo NAME "$dev" | tail -n +2); do
    umount "$p" 2>/dev/null
done
for p in $(lsblk -lnpo NAME "$dev" | tail -n +2); do
    wipefs -a "$p" >/dev/null 2>&1
done
wipefs -a "$dev" >/dev/null 2>&1
if ! parted -s "$dev" mklabel gpt mkpart WIN11 fat32 1MiB "$fin"; then
    erreur "Échec du partitionnement de $dev."
    exit 1
fi
partprobe "$dev" 2>/dev/null
udevadm settle 2>/dev/null
part=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
    part=$(lsblk -lnpo NAME,TYPE "$dev" | awk '$2=="part" {print $1; exit}')
    if [ -n "$part" ] && [ -b "$part" ]; then break; fi
    sleep 1
done
if [ -z "$part" ] || [ ! -b "$part" ]; then
    erreur "Partition introuvable après le partitionnement."
    exit 1
fi
if ! mkfs.vfat -F 32 -n WIN11 "$part" >/dev/null; then
    erreur "Échec du formatage FAT32 de $part."
    exit 1
fi
mkdir -p "$usbmnt"
if ! mount "$part" "$usbmnt"; then
    erreur "Impossible de monter $part."
    exit 1
fi
usb="$usbmnt"

# --- Montage de l'ISO (UDF d'abord : la vue ISO 9660 des ISO Windows est incomplète) ---
mkdir -p "$isomnt"
if ! mount -t udf -o loop,ro "$iso" "$isomnt" 2>/dev/null; then
    if ! mount -o loop,ro "$iso" "$isomnt"; then
        erreur "Impossible de monter l'ISO (essaie : sudo modprobe udf)."
        exit 1
    fi
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

# --- Inventaire de la clé ---
(
    cd "$usb" && find . -type f -print0 | while IFS= read -r -d '' f; do
        printf '%s\t%s Mo\n' "${f#./}" "$(awk -v s="$(wc -c < "$f")" 'BEGIN{printf "%.1f", s/1048576}')"
    done
) > "$dossier/contenu_cle.txt"

# --- Écriture définitive et démontage de la clé ---
info "Synchronisation de la clé (ne la retire pas encore)..."
sync
cd "$dossier" || exit 1
umount "$usbmnt" || { erreur "Impossible de démonter la clé : ne la retire pas."; exit 1; }

ok "Terminé : clé prête ($part). Tu peux la retirer."
echo "Journaux : $log, $dlog (si découpage) et $dossier/contenu_cle.txt"
