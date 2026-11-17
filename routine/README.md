# Routine quotidienne : lien ISO Windows 11 → GitHub

Une fois par jour, le Mac mini lance Chrome en mode headless, refait les clics de la page Microsoft (édition « Windows 11 multi-éditions », langue, « Confirmer »), récupère le lien signé généré (valable 24 h) et le publie dans `liens_iso.txt` de ce dépôt.

**Rien n'écoute sur le réseau** : launchd lance le script à heure fixe, le script appelle Microsoft et GitHub en sortie uniquement. Aucune installation supplémentaire : PHP et Google Chrome suffisent.

## Mise en place (une seule fois, sur le Mac mini)

1. Créer sur GitHub un **jeton fine-grained** : *Settings → Developer settings → Fine-grained tokens*, accès limité au seul dépôt `Win11_usb_boot_key_any_terminal`, permission **Contents : Read and write**, durée 1 an.
2. Le ranger dans le Trousseau (saisie masquée, jamais dans un fichier) :
   ```bash
   security add-generic-password -s win11-liens-github -a "$USER" -w
   ```
3. Tester **sans rien publier** :
   ```bash
   cd routine
   php maj_lien.php --dry-run
   ```
   Le journal `maj_lien.log` doit indiquer « Lien obtenu : … valable jusqu'au … ». Pour voir Chrome travailler : `php maj_lien.php --dry-run --show`.
4. Installer la routine (heure au choix, 07:07 par défaut) :
   ```bash
   bash installer_launchd.sh 07:07
   launchctl kickstart gui/$(id -u)/fr.win11.liens-iso    # essai réel immédiat
   ```
   Retrait : `bash installer_launchd.sh --retirer`.

## Codes de sortie

| Code | Signification |
|---|---|
| 0 | lien obtenu et publié (ou simulé) |
| 1 | configuration (Chrome, jeton, verrou) |
| 2 | page modifiée/refusée par Microsoft, ou lien non conforme |
| 3 | échec de publication GitHub |

Un échec déclenche une notification macOS ; le détail est dans `maj_lien.log`.

## Garde-fous

- Le lien n'est accepté que s'il est en `https`, sur `*.microsoft.com`, se termine par `.iso`, porte une signature (`t`, `P1`) et reste valable **au moins 1 h**.
- Le lien signé n'est **jamais écrit dans les journaux**, seulement dans `liens_iso.txt`.
- Le jeton ne vit que dans le Trousseau (ou la variable `GITHUB_TOKEN` pour un essai) ; jamais dans le script.
- Un verrou (`.verrou`) empêche deux exécutions simultanées.
- Si Microsoft affiche une page de blocage (« trafic inhabituel »…), la routine **s'arrête et le journalise** : elle ne tente aucun contournement.

## À savoir

- **Le dépôt est public** : le lien signé y est lisible pendant 24 h par n'importe qui. Il ne donne accès qu'à l'ISO publique de Microsoft, mais si cela gêne, rendre le dépôt privé ou ne publier que sur demande.
- On ignore si un lien généré depuis votre box fonctionne depuis un autre réseau (la signature peut être liée à l'IP). À vérifier avec un téléchargement depuis un autre réseau.
- La page Microsoft change parfois : si les sélecteurs ne correspondent plus, la routine échoue en code 2 (le début du texte de la page est journalisé) et le script doit être adapté.
- Le Mac doit être allumé et la session ouverte (LaunchAgent, car le Trousseau est lié à la session). Si le Mac dormait à l'heure prévue, launchd lance la tâche au réveil.
- Les scripts de création de clé ne lisent pas encore `liens_iso.txt` ; ce point reste à faire.
