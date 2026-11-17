# Routine quotidienne : lien ISO Windows 11 → GitHub

Une fois par jour, l'ordinateur lance Chrome en mode headless, refait les clics de la page Microsoft (édition « Windows 11 multi-éditions », puis **chaque langue proposée dans le menu**, puis « Confirmer »), récupère le lien signé de chaque langue (valable 24 h) et publie le tout, en un seul commit, dans `iso_links.txt` de ce dépôt. La liste des langues est lue sur la page : une langue ajoutée par Microsoft est prise en compte sans modifier le script.

**Rien n'écoute sur le réseau** : launchd lance le script à heure fixe, le script appelle Microsoft et GitHub en sortie uniquement. Aucune installation supplémentaire : PHP et Google Chrome suffisent.

## Mise en place (une seule fois, sur l'ordinateur)

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

Un échec déclenche une notification macOS ; le détail est dans `maj_lien.log`. Une langue en échec n'empêche pas les autres : les liens obtenus sont publiés (code 0, avec notification « N en échec »). Après **3 échecs de suite**, la routine s'arrête et publie ce qu'elle a : Microsoft limite peut-être les demandes, et rien n'est tenté pour contourner cette limite.

## Options

`php maj_lien.php [--dry-run] [--show] [--langue=French] [--delai=10] [--max=N]` : `--langue` ne traite qu'une langue (nom anglais utilisé par Microsoft, par exemple `French`, `German`) ; `--delai` règle la pause entre deux langues (10 s par défaut) ; `--max` limite le nombre de langues, pratique pour un premier essai (`--dry-run --max=2`). Les anciennes lignes des autres langues restent dans le fichier tant que leur lien n'a pas expiré.

## Garde-fous

- Le lien n'est accepté que s'il est en `https`, sur `*.microsoft.com`, se termine par `.iso`, porte une signature (`t`, `P1`) et reste valable **au moins 1 h**.
- Le lien signé n'est **jamais écrit dans les journaux**, seulement dans `iso_links.txt`.
- Le jeton ne vit que dans le Trousseau (ou la variable `GITHUB_TOKEN` pour un essai) ; jamais dans le script.
- Un verrou (`.verrou`) empêche deux exécutions simultanées.
- Si Microsoft affiche une page de blocage (« trafic inhabituel »…), la routine **s'arrête et le journalise** : elle ne tente aucun contournement.

## À savoir

- **Le dépôt est public** : le lien signé y est lisible pendant 24 h par n'importe qui. Il ne donne accès qu'à l'ISO publique de Microsoft, mais si cela gêne, rendre le dépôt privé ou ne publier que sur demande.
- **Une exécution complète fait une demande par langue** : la page en proposait **37** le 17/11/2026 (allemand, anglais États-Unis, arabe, bulgare, chinois simplifié et traditionnel, coréen, croate, danois, espagnol et espagnol Mexique, estonien, finnois, français et français canadien, grec, hébreu, hongrois, italien, japonais, letton, lituanien, néerlandais, norvégien, polonais, portugais et portugais Brésil, roumain, russe, serbe latin, slovaque, slovène, suédois, tchèque, thaï, turc, ukrainien). Avec 10 secondes de pause entre deux langues, une exécution dure de l'ordre de 10 minutes. En cas d'échecs répétés, augmenter `--delai` (3 minutes = environ 2 heures). Pour un premier essai : `--dry-run --max=2 --delai=10`. Non testé contre la vraie page au-delà de la lecture de la liste des langues.
- On ignore si un lien généré depuis votre connexion fonctionne depuis un autre réseau (la signature peut être liée à l'IP). À vérifier avec un téléchargement depuis un autre réseau.
- La page Microsoft change parfois : si les sélecteurs ne correspondent plus, la routine échoue en code 2 (le début du texte de la page est journalisé) et le script doit être adapté.
- L'ordinateur doit être allumé et la session ouverte (LaunchAgent, car le Trousseau est lié à la session). Si le Mac dormait à l'heure prévue, launchd lance la tâche au réveil.
- Les trois scripts de création de clé lisent `iso_links.txt` : si un lien de votre langue reste valable au moins 30 min, ils le proposent à la place de la méthode manuelle (et reviennent à celle-ci si le lien ne répond pas).
