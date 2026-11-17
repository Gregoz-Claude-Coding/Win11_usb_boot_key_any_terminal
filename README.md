# Win11_usb_boot_key_any_terminal

Crée une clé USB bootable Windows 11 (UEFI, FAT32) à partir d'un fichier ISO, depuis **Windows, macOS ou Linux**. Les scripts peuvent aussi télécharger l'ISO depuis le serveur de Microsoft.

| Système | Script | Outils utilisés |
|---|---|---|
| Windows | `make_win11_usb.ps1` | PowerShell, DISM, robocopy, BITS |
| macOS | `make_win11_usb_macos.sh` | diskutil, hdiutil, curl, wimlib |
| Linux | `make_win11_usb_linux.sh` | lsblk, parted, mkfs.vfat, mount, curl, wimlib |

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
3. Clic droit sur le bouton de téléchargement 64 bits, puis « Copier l'adresse du lien ».
4. Choisir `T` dans le script et coller l'adresse.

Le script :

- n'accepte qu'une URL `https` d'un domaine `*.microsoft.com` dont le chemin se termine par `.iso` ;
- interroge le serveur pour connaître la taille de l'ISO ;
- compare avec l'espace libre du répertoire courant et **refuse de télécharger s'il en manque** ;
- télécharge dans le répertoire courant (fichier `.part` renommé à la fin) ;
- propose de vérifier l'empreinte SHA-256, affichée sur la page Microsoft pour chaque langue (Entrée pour ignorer).

### Liens enregistrés dans le dépôt (`liens_iso.txt`)

Le fichier `liens_iso.txt` liste des liens directs, un par ligne, au format `langue;build;url`. Quand on choisit `T`, les scripts lisent ce fichier sur GitHub et proposent ces liens numérotés ; Entrée permet de coller un autre lien.

**Ces liens sont ceux que Microsoft génère, ils peuvent expirer ou exiger une signature.** Le script teste le lien enregistré avant de s'en servir : s'il ne répond pas, il demande un lien à jour (méthode manuelle ci-dessus).

Pour corriger ou ajouter un lien : modifier `liens_iso.txt` par pull request. Seules les URL `https` en `*.microsoft.com` se terminant par `.iso` sont acceptées par les scripts.

### Espace disque nécessaire dans le répertoire courant

| Système | Besoin | Pourquoi |
|---|---|---|
| macOS, Linux | taille de l'ISO + 0,5 Go | l'ISO est monté (pas extrait) et `install.wim` est découpé directement sur la clé |
| Windows | taille de l'ISO + environ 6 Go + 0,5 Go | `install.wim` est d'abord découpé en local (`swm_tmp`), puis les morceaux sont copiés sur la clé |

Sous Windows, une seconde vérification exacte (taille réelle de `install.wim`) est faite avant l'effacement de la clé. La clé elle-même doit être au moins aussi grande que l'ISO.

## Utilisation

**Windows** : console PowerShell ouverte en administrateur, dans le dossier de l'ISO, puis coller le contenu de `make_win11_usb.ps1`.

**macOS** :

```bash
brew install wimlib            # une seule fois, sans sudo
cd ~/Downloads                 # dossier contenant l'ISO
sudo bash /chemin/vers/make_win11_usb_macos.sh
```

**Linux** :

```bash
sudo apt install wimtools parted dosfstools curl     # Debian / Ubuntu
# sudo dnf install wimlib-utils parted dosfstools curl   # Fedora
# sudo pacman -S wimlib parted dosfstools curl           # Arch
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
- Le lien enregistré dans `liens_iso.txt` n'a pas pu être vérifié (il n'est pas signé et l'environnement de développement n'avait pas accès à microsoft.com). Le téléchargement n'a pas été testé contre le serveur réel de Microsoft, car il faut un lien généré dans un navigateur. La lecture de la taille se fait par une requête `HEAD` ; si le serveur ne la communique pas, le script suppose 8 Go et le signale.
- La partie téléchargement de la version PowerShell n'a pas été exécutée.
