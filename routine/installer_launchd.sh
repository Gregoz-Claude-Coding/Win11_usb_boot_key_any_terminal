#!/bin/bash
# Installe (ou retire avec --retirer) la routine quotidienne sur ce Mac.
# Aucun port n'est ouvert : launchd lance simplement le script à heure fixe.
# Usage : bash installer_launchd.sh [HH:MM] [etale]      (défaut 07:07)
#   sans « etale » : un passage par jour (toutes les langues d'un coup)
#   avec « etale » : une langue à la fois, 24 h réparties sur le nombre de langues, en continu (voir README)
set -e
DOSSIER="$(cd "$(dirname "$0")" && pwd)"
LABEL="fr.win11.liens-iso"
CIBLE="$HOME/Library/LaunchAgents/$LABEL.plist"
DOM="gui/$(id -u)"

if [ "$1" = "--retirer" ]; then
  launchctl bootout "$DOM/$LABEL" 2>/dev/null || true
  rm -f "$CIBLE"; echo "Routine retirée."; exit 0
fi

HM="${1:-07:07}"
MODE="${2:-}"
[ -z "$MODE" ] || [ "$MODE" = "etale" ] || { echo "Mode inconnu : $MODE (seul « etale » existe)"; exit 1; }
case "$HM" in [0-2][0-9]:[0-5][0-9]) ;; *) echo "Heure invalide : $HM (format HH:MM)"; exit 1;; esac
HEURE=$((10#${HM%:*})); MINUTE=$((10#${HM#*:}))

PHP="$(command -v php || true)"
[ -x "$PHP" ] || { echo "php introuvable dans le PATH."; exit 1; }
[ -d "/Applications/Google Chrome.app" ] || echo "Attention : Google Chrome introuvable dans /Applications (définir CHROME_BIN sinon)."
security find-generic-password -s win11-liens-github >/dev/null 2>&1 || {
  echo "Jeton GitHub absent du Trousseau. Le créer d'abord :"
  echo "  security add-generic-password -s win11-liens-github -a \"\$USER\" -w"
  exit 1; }

mkdir -p "$HOME/Library/LaunchAgents"
ARGS=""; RUNATLOAD=""
if [ "$MODE" = "etale" ]; then
  ARGS=$'        <string>--etale</string>\n'
  RUNATLOAD=$'    <key>RunAtLoad</key>\n    <true/>\n'
fi
CONTENU="$(cat "$DOSSIER/fr.win11.liens-iso.plist.modele")"
CONTENU="${CONTENU//__PHP__/$PHP}"
CONTENU="${CONTENU//__DOSSIER__/$DOSSIER}"
CONTENU="${CONTENU//__HEURE__/$HEURE}"
CONTENU="${CONTENU//__MINUTE__/$MINUTE}"
CONTENU="${CONTENU//__ARGS__$'\n'/$ARGS}"
CONTENU="${CONTENU//__RUNATLOAD__/$RUNATLOAD}"
printf '%s\n' "$CONTENU" > "$CIBLE"
plutil -lint "$CIBLE" >/dev/null
launchctl bootout "$DOM/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOM" "$CIBLE"
if [ "$MODE" = "etale" ]; then
  printf 'Routine étalée installée : elle démarre maintenant et à chaque ouverture de session, tourne en continu, et est relancée chaque jour à %02d:%02d si elle s'"'"'était arrêtée.\n' "$HEURE" "$MINUTE"
else
  printf 'Routine installée : tous les jours à %02d:%02d (le Mac doit être allumé ; sinon launchd la lance au réveil).\n' "$HEURE" "$MINUTE"
fi
echo "Essai immédiat : launchctl kickstart $DOM/$LABEL   puis  tail $DOSSIER/maj_lien.log"
