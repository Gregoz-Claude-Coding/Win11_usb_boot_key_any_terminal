# Win11_usb_boot_key_any_terminal

Crée une clé USB bootable Windows 11 (UEFI, FAT32) à partir d'un fichier ISO, depuis **Windows, macOS ou Linux**. Les scripts peuvent aussi télécharger l'ISO depuis le serveur de Microsoft.

| Système | Script | Outils utilisés |
|---|---|---|
| Windows | `make_win11_usb.ps1` | PowerShell, DISM, robocopy, BITS |
| macOS | `make_win11_usb_macos.sh` | diskutil, hdiutil, curl, wimlib |
| Linux | `make_win11_usb_linux.sh` | lsblk, parted, mkfs.vfat, mount, curl, wimlib |

## Démarrage rapide

Les scripts posent des questions (ISO, clé USB, confirmation) : ils sont donc téléchargés d'abord, puis lancés, et non exécutés directement depuis le réseau.

**macOS** (Terminal) : `brew install wimlib` n'est à faire qu'une fois (Homebrew : https://brew.sh). Le dossier `~/win11` reçoit l'ISO et les journaux (prévoir environ 8 Go libres). Le script demande le mot de passe de session.

```bash
brew install wimlib
mkdir -p ~/win11 && cd ~/win11
curl -fsSLO https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/make_win11_usb_macos.sh
sudo bash make_win11_usb_macos.sh
```

**Linux** (commande `apt` pour Debian / Ubuntu ; autres distributions : voir plus bas) :

```bash
sudo apt install wimtools parted dosfstools curl
mkdir -p ~/win11 && cd ~/win11
curl -fsSLO https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/make_win11_usb_linux.sh
sudo bash make_win11_usb_linux.sh
```

**Windows** (console PowerShell ouverte en administrateur) :

```powershell
mkdir C:\win11 -Force | Out-Null; cd C:\win11
irm https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/make_win11_usb.ps1 | iex
```

Dans le script, choisir `T` pour télécharger l'ISO depuis Microsoft, ou placer d'abord un ISO dans le dossier de travail.

## Langue des menus

Les scripts s'affichent dans la **langue du système** : français, anglais, espagnol, allemand, italien ou portugais (anglais par défaut pour toute autre langue). Pour forcer une langue : `WIN11_LANG=en` (macOS/Linux : `sudo env WIN11_LANG=en bash make_win11_usb_macos.sh`, Windows : `$env:WIN11_LANG='en'` avant de lancer le script). Les réponses « oui » acceptent O, Y, S et J. Ajouter une langue : copier la fonction `msg_en` en `msg_xx` (bash) ou le bloc `en = @{...}` de `$Textes` (PowerShell) et traduire les valeurs ; les clés ne changent pas. Les traductions es/de/it/pt n'ont pas été relues par un locuteur natif : corrections bienvenues.

## Vitesse d'écriture

La vitesse est affichée pour voir si la clé est lente :

- pendant la copie des fichiers (moyenne en cours) et à la fin de chaque étape (copie, découpage de `install.wim`, écriture des morceaux) ;
- **à la fin, une vitesse globale mesurée après vidage du cache d'écriture** : c'est la valeur à retenir, car les vitesses affichées pendant la copie sont gonflées tant que le cache du système n'est pas plein ;
- un avertissement s'affiche sous **10 Mo/s** (clé USB 2.0 ou port USB 2 probable).

Sous macOS et Linux, la vitesse du découpage est mesurée sur la croissance des fichiers `install*.swm` écrits directement sur la clé. Sous Windows, le découpage se fait sur le disque local (la vitesse indiquée est celle du disque local) ; la copie des morceaux vers la clé est ensuite mesurée séparément, en écriture directe.

## Fonctionnement (identique sur les trois systèmes)

1. Recherche les `.iso` du répertoire courant et les liste numérotés avec leur taille. L'option `T` télécharge un ISO depuis Microsoft (voir plus bas). Si aucun ISO n'est trouvé, on peut saisir `T` ou le chemin complet d'un ISO.
2. Liste les clés USB détectées, demande laquelle effacer, vérifie que la clé est au moins aussi grande que l'ISO, puis demande confirmation (O/N).
3. Partitionne et formate la clé en FAT32, label `WIN11`, 32 Go maximum.
4. Copie le contenu de l'ISO, sauf `install.wim` et `autorun.inf`. Chaque fichier copié est affiché et journalisé.
5. Découpe `install.wim` (plus de 4 Go) en morceaux `install*.swm` de 3800 Mo compatibles FAT32, avec une barre de progression.
6. Si l'ISO contient un `install.esd`, il est simplement copié.
7. Écrit un inventaire de la clé.

Les journaux sont écrits dans le répertoire courant, jamais dans un dossier temporaire :

- `copie_cle.log` : liste des fichiers copiés
- `dism_split.log` (Windows) ou `wimlib_split.log` (macOS, Linux) : sortie du découpage
- `contenu_cle.txt` : inventaire des fichiers de la clé

## Télécharger l'ISO depuis Microsoft

Microsoft ne publie **pas de lien direct fixe** : le lien est généré pour chaque téléchargement, après le choix de la langue, et n'est valable que **24 heures**. Les scripts ne contournent pas ce mécanisme :

1. Ouvrir la page officielle : <https://www.microsoft.com/fr-fr/software-download/windows11>
2. Dans la section « Télécharger l'image disque Windows 11 (ISO) pour les appareils x64 », choisir l'ISO multi-éditions, puis la langue du produit, et cliquer sur « Confirmer ».
3. Clic droit sur le bouton de téléchargement 64 bits, puis « Copier l'adresse du lien ». Le lien doit être copié en entier, y compris ce qui suit `.iso?` : c'est cette partie qui l'autorise.
4. Choisir `T` dans le script.

Le script ouvre lui-même la page Microsoft (dans ta langue) dans le navigateur par défaut, puis **surveille le presse-papiers** : dès qu'un lien valide y apparaît après « Copier l'adresse du lien », il affiche son nom de fichier et demande confirmation (O/n). Il n'y a donc rien à coller. Entrée permet de coller le lien à la main, et l'attente s'arrête au bout de 5 minutes.

| Système | Ouverture de la page | Lecture du presse-papiers | À installer |
|---|---|---|---|
| macOS | `open` | `pbpaste` | rien |
| Windows | `Start-Process` | `Get-Clipboard` | rien |
| Linux | `xdg-open` | `wl-paste`, `xclip` ou `xsel` | l'un de ces outils pour la détection automatique (sinon collage manuel) |

Le lien copié n'est pas affiché en entier (seul le nom du fichier l'est), car il contient une signature personnelle.

Le script :

- n'accepte qu'une URL `https` d'un domaine `*.microsoft.com` dont le chemin se termine par `.iso` ;
- interroge le serveur pour connaître la taille de l'ISO ;
- compare avec l'espace libre du répertoire courant et **refuse de télécharger s'il en manque** ;
- télécharge dans le répertoire courant (fichier `.part` renommé à la fin) ;
- vérifie l'empreinte SHA-256 de l'ISO téléchargé (voir plus bas).

### Empreintes enregistrées dans le dépôt (`iso_hashes.txt`)

Un lien direct ne peut pas être enregistré dans le dépôt : Microsoft le signe et il expire au bout de 24 heures (un lien sans signature est refusé avec une erreur 403).

Le fichier `iso_hashes.txt` contient à la place les empreintes SHA-256 publiées par Microsoft, au format `version;langue;sha256`. Après le téléchargement, le script calcule l'empreinte de l'ISO et la cherche dans ce fichier : si elle y figure, la conformité est confirmée automatiquement ; sinon, il demande de saisir l'empreinte affichée par Microsoft (Entrée pour ignorer).

Pour ajouter une langue ou une version : pull request sur `iso_hashes.txt`, en recopiant l'empreinte depuis la page Microsoft. Une empreinte erronée dans ce fichier ne bloque rien : elle fait seulement passer l'ISO en « non reconnu ».

### Lien déjà généré (`iso_links.txt`)

Une routine quotidienne (dossier [`routine/`](routine/README.md)) génère dans un navigateur headless **un lien signé pour chaque langue proposée par Microsoft** et les publie dans `iso_links.txt` (format `langue;build;expiration;url`). Quand vous choisissez `T`, le script lit ce fichier : si un lien de votre langue reste valable **au moins 30 minutes**, il le propose (« Utiliser ? O/n »), sans ouvrir la page Microsoft. Si le lien ne répond pas (expiré, lié à un autre réseau…), le script revient tout seul à la méthode manuelle ci-dessus. Seule la signature publiée par Microsoft est utilisée ; l'URL est revalidée comme toute autre (https, `*.microsoft.com`, `.iso`).

### Langue détectée

Le script détecte la langue du système (macOS : préférences de langue ; Linux : `LANG` / `LC_ALL` ; Windows : langue d'affichage) et propose par défaut la page Microsoft correspondante, par exemple `https://www.microsoft.com/fr-fr/software-download/windows11`. On peut saisir un autre code (`en-us`, `de-de`, etc.) ou valider avec Entrée. Le lien de l'ISO lui-même reste à copier depuis cette page.

### Espace disque nécessaire dans le répertoire courant

| Système | Besoin | Pourquoi |
|---|---|---|
| macOS, Linux | taille de l'ISO + 0,5 Go | l'ISO est monté (pas extrait) et `install.wim` est découpé directement sur la clé |
| Windows | taille de l'ISO + environ 6 Go + 0,5 Go | `install.wim` est d'abord découpé en local (`swm_tmp`), puis les morceaux sont copiés sur la clé |

Sous Windows, une seconde vérification exacte (taille réelle de `install.wim`) est faite avant l'effacement de la clé. La clé elle-même doit être au moins aussi grande que l'ISO.

## Utilisation

**Windows** : console PowerShell ouverte en administrateur, dans le dossier de l'ISO, puis coller le contenu de `make_win11_usb.ps1`.

**macOS** :

`brew install wimlib` n'est à faire qu'une fois, sans `sudo`. Placez-vous dans le dossier qui contient l'ISO (ici `~/Downloads`).

```bash
brew install wimlib
cd ~/Downloads
sudo bash /chemin/vers/make_win11_usb_macos.sh
```

**Linux** :

Paquets à installer selon la distribution : Debian / Ubuntu `sudo apt install wimtools parted dosfstools curl`, Fedora `sudo dnf install wimlib-utils parted dosfstools curl`, Arch `sudo pacman -S wimlib parted dosfstools curl`.

```bash
sudo apt install wimtools parted dosfstools curl
cd ~/Téléchargements
sudo bash /chemin/vers/make_win11_usb_linux.sh
```

## Différences entre les versions

- **Windows** : table GPT. Le découpage se fait d'abord sur le disque local (`swm_tmp`) puis les morceaux sont copiés sur la clé, car DISM était bloqué par l'antivirus lors d'une écriture directe. Téléchargement par BITS, avec `curl.exe` en secours.
- **macOS** : table **MBR** + FAT32. Avec GPT, macOS ajoute une partition EFI vide qui peut perturber le démarrage UEFI. Le découpage se fait directement sur la clé avec `wimlib`.
- **Linux** : table GPT, comme sous Windows. Découpage direct sur la clé avec `wimlib`. L'ISO est monté en UDF en priorité, car la vue ISO 9660 d'un ISO Windows est incomplète.
- Sous macOS et Linux, les disques sont choisis par leur numéro dans la liste affichée. Les disques internes ne sont pas proposés.

## Avertissements

- **Le disque choisi est entièrement effacé.** Vérifier le nom et la taille avant de confirmer.
- Ces scripts ne contournent pas les prérequis de Windows 11 (TPM, Secure Boot, etc.).
- Les versions macOS et Linux n'ont pas encore été testées sur du matériel réel : la copie, les exclusions, le menu des ISO, la barre de progression et la logique de téléchargement (contre un serveur local) ont été vérifiés, mais pas le partitionnement ni le découpage avec `wimlib`.
- Le téléchargement n'a pas été testé contre le serveur réel de Microsoft, car il faut un lien généré dans un navigateur. La lecture de la taille se fait par une requête `HEAD` ; si le serveur ne la communique pas mais répond normalement, le script suppose 8 Go et le signale. Si le serveur répond par une erreur (403, 404...), le script s'arrête en affichant le code reçu.
- La version PowerShell (menus traduits, vitesse d'écriture, lecture de `iso_links.txt`) n'a pas été exécutée : seuls l'équilibre des blocs et la syntaxe générale ont été vérifiés. Sa partie téléchargement non plus. La lecture du presse-papiers a été testée sur macOS et Linux avec un presse-papiers simulé, pas avec `pbpaste`, `wl-paste` ou `xclip` réels, ni sous Windows.
