# Création d'une clé USB bootable Windows 11 (UEFI/GPT, FAT32) à partir d'un ISO
# Creates a bootable Windows 11 USB drive (UEFI/GPT, FAT32) from an ISO

# --- Langue des menus : langue d'affichage de Windows (repli : anglais) ---
# Langues : fr, en, es, de, it, pt. Forcer une langue : $env:WIN11_LANG = 'en' avant de coller le script. Ajouter une langue : ajouter un bloc dans $Textes.
$Textes = @{
    fr = @{
        need_admin      = 'Ouvre la console en administrateur.'
        dl_title        = 'Téléchargement de l''ISO Windows 11 depuis Microsoft'
        ask_lang        = 'Langue de la page Microsoft [{0}] (Entrée pour valider, ou autre code, ex. en-us)'
        bad_code        = 'Code invalide : langue détectée conservée ({0}).'
        official_page   = 'Page officielle : {0}'
        no_fixed_link   = "Microsoft ne publie pas de lien fixe : le lien direct est généré à chaque téléchargement`net n'est valable que 24 heures."
        step1           = '  1. Ouvre la page officielle ci-dessus dans ton navigateur.'
        step2           = "  2. Dans « Télécharger l'image disque Windows 11 (ISO) pour les appareils x64 », choisis l'ISO`n     multi-éditions, puis la langue du produit (ta langue système : {0}) et clique sur « Confirmer »."
        step3           = "  3. Clic droit sur le bouton de téléchargement 64 bits > « Copier l'adresse du lien » : le script la détecte tout seul.`n     Colle le lien ENTIER, y compris ce qui suit « .iso? » : c'est ce qui l'autorise."
        open_fail       = 'Impossible d''ouvrir le navigateur : ouvre la page à la main.'
        wait_link       = "En attente du lien : clique sur « Copier l'adresse du lien » dans le navigateur.`n(Entrée = coller le lien à la main)"
        clip_found      = 'Lien détecté dans le presse-papiers : {0}. L''utiliser ? (O/n)'
        ask_url         = 'Colle ici l''URL du lien (https://...microsoft.com/....iso)'
        url_refused     = 'URL refusée : elle doit être en https, sur un domaine *.microsoft.com, et son chemin doit se terminer par .iso.'
        file_exists     = '{0} existe déjà dans {1} : utilisation du fichier existant.'
        querying        = 'Interrogation du serveur Microsoft...'
        http_err        = "Le serveur Microsoft a répondu HTTP {0} (0 = pas de réponse) : lien expiré, incomplet (sans la partie après « .iso? ») ou réseau injoignable.`nGénère un nouveau lien sur la page officielle."
        size_unknown    = 'Taille de l''ISO non communiquée : hypothèse de 8 Go.'
        size_line       = '  Taille de l''ISO                       : {0} Go'
        split_line      = '  Découpage local de install.wim (est.) : {0} Go'
        need_line       = '  Espace nécessaire (avec marge)        : {0} Go'
        free_unknown    = '  Espace libre : impossible à déterminer pour {0}, contrôle ignoré.'
        free_line       = '  Espace libre                          : {0} Go ({1})'
        insufficient    = 'Espace disque insuffisant : il manque {0} Go.'
        confirm_dl      = 'Lancer le téléchargement vers {0} ? (O/N)'
        dl_running      = 'Téléchargement...'
        dl_par          = 'Téléchargement en parallèle sur {0} connexions (reprise possible)...'
        menu_help       = '↑↓ choisir · Espace cocher · ←→ changer · Entrée valider · Échap annuler'
        menu_opts_title = 'Options de l''installation de Windows'
        m_bypass        = 'Sauter les questions d''installation (compte local)'
        m_lang          = 'Langue, clavier et fuseau'
        m_ed            = 'Édition'
        m_ask           = 'me le demander'
        m_home          = 'Famille'
        m_auto          = "Session admin automatique"
        m_upd           = 'Mettre en pause les mises à jour (moins sûr)'
        m_hw            = 'Ignorer les contrôles TPM / Secure Boot / mémoire / CPU'
        ua_note         = 'Note : au premier démarrage, connectez le PC à Internet. Windows Update installera les applications (icônes du menu Démarrer) en 10 à 30 minutes.'
        menu_dl_title   = 'Téléchargement de l''ISO depuis Microsoft'
        m_dl_lang       = 'Langue de la page Microsoft'
        m_other         = 'autre…'
        dl_pause_hint   = '[P] pause'
        dl_paused       = 'EN PAUSE — appuyez sur P pour reprendre'
        recap_speed     = 'Récapitulatif des vitesses : téléchargement {0} Mo/s · écriture sur la clé {1} Mo/s'
        bits_fail       = 'BITS en échec ({0}) : essai avec curl.exe...'
        dl_fail         = 'Échec du téléchargement (lien expiré ou réseau ?). Génère un nouveau lien sur la page Microsoft.'
        dl_done         = 'Téléchargement terminé : {0}'
        dl_speed        = 'Vitesse de téléchargement moyenne : {0} Mo/s'
        sha_calc        = 'Calcul de l''empreinte SHA-256 (quelques minutes)...'
        sha_ok          = 'Empreinte conforme à celle publiée par Microsoft ({0} - {1}).'
        sha_unknown     = 'Empreinte non reconnue (version ou langue absente de iso_hashes.txt, ou fichier altéré).'
        sha_computed    = 'SHA-256 calculé : {0}'
        ask_sha         = 'Empreinte SHA-256 affichée par Microsoft pour cette langue (Entrée pour ignorer)'
        sha_match       = 'Empreinte conforme.'
        sha_bad         = 'Empreinte différente : fichier corrompu ou incomplet. Supprime-le et recommence.'
        published_found = 'Lien déjà généré (iso_links.txt) : build {0}, encore valable {1}. L''utiliser ? (O/n)'
        published_dead  = 'Ce lien publié ne répond pas (HTTP {0}) : retour à la méthode manuelle.'
        no_iso          = 'Aucun fichier .iso trouvé dans {0}.'
        ask_no_iso      = 'T pour télécharger l''ISO depuis Microsoft, ou chemin complet de l''ISO'
        isos_found      = 'ISO trouvés dans {0} :'
        menu_download   = '  [T] Télécharger un ISO Windows 11 depuis Microsoft'
        ask_iso         = 'Numéro de l''ISO à utiliser (ou T)'
        bad_choice      = 'Choix invalide.'
        iso_selected    = 'ISO sélectionné : {0}'
        iso_missing     = 'ISO introuvable.'
        disk_short      = 'Espace disque insuffisant dans {0} : {1} Go nécessaires pour découper install.wim, {2} Go libres.'
        no_usb          = 'Aucune clé USB détectée.'
        ask_usb         = 'Numéro du disque USB à EFFACER'
        not_usb         = 'Ce numéro n''est pas une clé USB.'
        too_small       = 'Clé trop petite : {0} Go pour un ISO de {1} Go.'
        confirm_erase   = 'Confirmer l''effacement de ''{0}'' ? (O/N)'
        keep_confirm    = "'{0}' contient déjà une disposition compatible : seule la partition FAT32 sera reformatée, les {1} autre(s) partition(s) sont conservées. Continuer ? (O/N)"
        data_warn       = "ATTENTION : cette clé contient des fichiers dans une partition de données, et sa partition FAT32 est trop petite pour cet ISO ({0} Go nécessaires). Continuer repartitionne la clé et EFFACE ces fichiers."
        data_ask        = "Pour les effacer quand même, tape {0} (Entrée pour annuler) : "
        erase_word      = "EFFACER"
        data_created    = "Partition de données exFAT « DONNEES » créée : {0} Go pour tes fichiers (la FAT32 garde de la marge pour les futures versions de Windows)."
        kept            = "Disposition conservée : seule la partition FAT32 est reformatée."
        eject_ask       = "Éjecter la clé USB en toute sécurité maintenant ? (O/N) "
        busy_prep       = "Préparation de la clé (effacement, partitions, formatage)"
        busy_flush      = "Écriture finale sur la clé, ne la débranche pas"
        busy_eject      = "Éjection de la clé"
        eject_ok        = "Clé éjectée : tu peux la débrancher."
        eject_fail      = "Éjection impossible (clé encore utilisée ?). Ferme les fenêtres qui l'utilisent puis éjecte-la depuis le système avant de la débrancher."
        bypass_ask      = "Ignorer les questions de l'installation de Windows (compte local, sans compte Microsoft ni offres Microsoft 365) ? (O/N) "
        bypass_name     = "Nom du compte local Windows à créer (appuyez sur Entrée sans rien taper pour '{0}') : "
        bypass_done     = "Réponses automatiques écrites sur la clé : autounattend.xml (compte local « {0} »). Les écrans langue, édition et disque restent affichés."
        ua_pc           = "Nom de la machine (tapez un nom, ou appuyez sur Entrée pour laisser Windows en choisir un) : "
        ua_lang         = "Langue, clavier et fuseau : 0 = me le demander, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (appuyez sur le chiffre voulu, Entrée = 0) : "
        ua_edition      = "Édition : 0 = me la demander, 1 = Pro, 2 = Famille/Home (appuyez sur le chiffre voulu, Entrée = 0) : "
        ua_auto         = "Ouvrir la session admin automatiquement au premier démarrage ? (O/N) "
        ua_pwd          = "Mot de passe du compte admin : "
        ua_pwd2         = "Confirmez le mot de passe : "
        ua_pwd_bad      = "Mot de passe vide ou différent. Recommencez."
        m_pwdmode       = "Mot de passe admin"
        m_pwd_auto      = "provisoire auto, puis vide"
        m_pwd_ask       = "que je saisis"
        m_wifi          = "Connexion Wi-Fi automatique"
        m_grey          = "(inutile avec le Wi-Fi)"
        ua_wifi_ssid    = "Nom du réseau Wi-Fi (SSID) : "
        ua_wifi_pwd     = "Mot de passe du Wi-Fi (8 caractères minimum) : "
        ua_wifi_pwd2    = "Confirmez le mot de passe du Wi-Fi : "
        ua_wifi_bad     = "Mot de passe Wi-Fi trop court ou différent. Recommencez."
        ua_wifi         = "Connecter automatiquement le PC à un réseau Wi-Fi au premier démarrage ? (O/N) "
        ua_pwdmode      = "Saisir vous-même le mot de passe admin (sinon provisoire automatique, puis vide) ? (O/N) "
        ua_clean        = "Laissez la clé branchée jusqu'au bureau : au premier démarrage, les mots de passe seront effacés de la clé."
        ua_updates      = "Mettre en pause les mises à jour automatiques (moins sûr) ? (O/N) "
        ua_hw           = "Ignorer les contrôles de compatibilité Windows 11 (TPM, Secure Boot, mémoire, processeur) ? (O/N) "
        recap_key       = "Clé de {0} Go : repérez cette taille dans la liste des disques de l'installateur Windows."
        copying         = 'Copie des fichiers...'
        robocopy_err    = 'robocopy a rencontré des erreurs (code {0}). Voir {1}'
        bootwim_missing = 'sources\boot.wim absent de la clé : copie incomplète. Voir {0}'
        write_ok        = 'Écriture sur la clé : OK'
        write_fail      = 'Écriture impossible sur {0} : {1}'
        splitting       = 'Découpage de install.wim dans {0} (~5 Go libres nécessaires)...'
        split_title     = 'Découpage de install.wim'
        split_status    = '{0} Mo / {1} Mo — {2} Mo/s'
        copy_title      = 'Copie des fichiers vers la clé'
        copy_status     = '{0} Mo — {1} Mo/s'
        copying_swm     = 'Copie des morceaux vers la clé...'
        split_done      = 'Découpage terminé.'
        dism_fail       = 'Échec de DISM (code {0}). Dernières lignes de {1} :'
        esd_copy        = 'install.esd détecté : copie directe.'
        no_image        = 'Ni install.wim ni install.esd trouvé dans l''ISO.'
        copy_summary    = 'Copie terminée : {0} Mo en {1} — {2} Mo/s en moyenne.'
        split_summary   = 'Découpage : {0} Mo en {1} — {2} Mo/s.'
        swm_summary     = 'Écriture des morceaux sur la clé : {0} Mo en {1} — {2} Mo/s.'
        total_speed     = 'Écriture totale sur la clé : {0} Go en {1} — {2} Mo/s (cache d''écriture vidé).'
        slow_drive      = 'Clé lente ({0} Mo/s) : une clé USB 3.x sur un port USB 3 irait bien plus vite.'
        done            = 'Terminé : clé prête sur {0}'
        logs            = 'Journaux : {0}, {1} et {2}'
        inv_file        = 'Fichier'
        inv_mb          = 'Mo'
    }
    en = @{
        need_admin      = 'Open the console as administrator.'
        dl_title        = 'Downloading the Windows 11 ISO from Microsoft'
        ask_lang        = 'Microsoft page language [{0}] (Enter to accept, or another code, e.g. fr-fr)'
        bad_code        = 'Invalid code: keeping the detected language ({0}).'
        official_page   = 'Official page: {0}'
        no_fixed_link   = "Microsoft does not publish a fixed link: the direct link is generated for each download`nand is only valid for 24 hours."
        step1           = '  1. Open the official page above in your browser.'
        step2           = "  2. Under `"Download Windows 11 Disk Image (ISO) for x64 devices`", choose the multi-edition`n     ISO, then the product language (your system language: {0}) and click `"Confirm`"."
        step3           = "  3. Right-click the 64-bit download button > `"Copy link address`": the script detects it by itself.`n     Paste the WHOLE link, including what follows `".iso?`": that part is what authorizes it."
        open_fail       = 'Could not open the browser: open the page by hand.'
        wait_link       = "Waiting for the link: click `"Copy link address`" in the browser.`n(Enter = paste the link by hand)"
        clip_found      = 'Link detected in the clipboard: {0}. Use it? (Y/n)'
        ask_url         = 'Paste the link URL here (https://...microsoft.com/....iso)'
        url_refused     = 'URL rejected: it must be https, on a *.microsoft.com domain, and its path must end with .iso.'
        file_exists     = '{0} already exists in {1}: using the existing file.'
        querying        = 'Querying the Microsoft server...'
        http_err        = "The Microsoft server answered HTTP {0} (0 = no answer): link expired, incomplete (missing the part after `".iso?`") or network unreachable.`nGenerate a new link on the official page."
        size_unknown    = 'ISO size not provided by the server: assuming 8 GB.'
        size_line       = '  ISO size                              : {0} GB'
        split_line      = '  Local split of install.wim (est.)     : {0} GB'
        need_line       = '  Space needed (with margin)            : {0} GB'
        free_unknown    = '  Free space: cannot be determined for {0}, check skipped.'
        free_line       = '  Free space                            : {0} GB ({1})'
        insufficient    = 'Not enough disk space: {0} GB missing.'
        confirm_dl      = 'Start the download to {0}? (Y/N)'
        dl_running      = 'Downloading...'
        dl_par          = 'Parallel download on {0} connections (resumable)...'
        menu_help       = '↑↓ move · Space tick · ←→ change · Enter OK · Esc cancel'
        menu_opts_title = 'Windows installation options'
        m_bypass        = 'Skip setup questions (local account)'
        m_lang          = 'Language, keyboard, time zone'
        m_ed            = 'Edition'
        m_ask           = 'ask me during setup'
        m_home          = 'Home'
        m_auto          = "Automatic admin sign-in"
        m_upd           = 'Pause automatic updates (less secure)'
        m_hw            = 'Skip TPM / Secure Boot / memory / CPU checks'
        ua_note         = 'Note: on first start, connect the PC to the Internet. Windows Update will install the apps (Start menu icons) within 10 to 30 minutes.'
        menu_dl_title   = 'Downloading the ISO from Microsoft'
        m_dl_lang       = 'Microsoft page language'
        m_other         = 'other…'
        dl_pause_hint   = '[P] pause'
        dl_paused       = 'PAUSED — press P to resume'
        recap_speed     = 'Speed summary: download {0} MB/s · write to the drive {1} MB/s'
        bits_fail       = 'BITS failed ({0}): trying curl.exe...'
        dl_fail         = 'Download failed (expired link or network?). Generate a new link on the Microsoft page.'
        dl_done         = 'Download finished: {0}'
        dl_speed        = 'Average download speed: {0} MB/s'
        sha_calc        = 'Computing the SHA-256 hash (a few minutes)...'
        sha_ok          = 'Hash matches the one published by Microsoft ({0} - {1}).'
        sha_unknown     = 'Hash not recognized (version or language missing from iso_hashes.txt, or altered file).'
        sha_computed    = 'Computed SHA-256: {0}'
        ask_sha         = 'SHA-256 hash shown by Microsoft for this language (Enter to skip)'
        sha_match       = 'Hash matches.'
        sha_bad         = 'Hash differs: corrupted or incomplete file. Delete it and start over.'
        published_found = 'Ready-made link found (iso_links.txt): build {0}, still valid for {1}. Use it? (Y/n)'
        published_dead  = 'That published link does not answer (HTTP {0}): falling back to the manual method.'
        no_iso          = 'No .iso file found in {0}.'
        ask_no_iso      = 'T to download the ISO from Microsoft, or the full path of the ISO'
        isos_found      = 'ISO files found in {0}:'
        menu_download   = '  [T] Download a Windows 11 ISO from Microsoft'
        ask_iso         = 'Number of the ISO to use (or T)'
        bad_choice      = 'Invalid choice.'
        iso_selected    = 'Selected ISO: {0}'
        iso_missing     = 'ISO not found.'
        disk_short      = 'Not enough disk space in {0}: {1} GB needed to split install.wim, {2} GB free.'
        no_usb          = 'No USB drive detected.'
        ask_usb         = 'Number of the USB disk to ERASE'
        not_usb         = 'This number is not a USB drive.'
        too_small       = 'USB drive too small: {0} GB for a {1} GB ISO.'
        confirm_erase   = 'Confirm erasing ''{0}''? (Y/N)'
        keep_confirm    = "'{0}' already has a compatible layout: only the FAT32 partition will be reformatted, the {1} other partition(s) are kept. Continue? (Y/N)"
        data_warn       = "WARNING: this drive holds files in a data partition, and its FAT32 partition is too small for this ISO ({0} GB needed). Continuing repartitions the drive and ERASES those files."
        data_ask        = "To erase them anyway, type {0} (Enter to cancel): "
        erase_word      = "ERASE"
        data_created    = "exFAT data partition 'DONNEES' created: {0} GB for your files (the FAT32 partition keeps headroom for future Windows versions)."
        kept            = "Layout kept: only the FAT32 partition is reformatted."
        eject_ask       = "Safely eject the USB drive now? (Y/N) "
        busy_prep       = "Preparing the drive (erasing, partitioning, formatting)"
        busy_flush      = "Final write to the drive, do not unplug it"
        busy_eject      = "Ejecting the drive"
        eject_ok        = "Drive ejected: you can unplug it."
        eject_fail      = "Could not eject (drive still in use?). Close any window using it, then eject it from the system before unplugging."
        bypass_ask      = "Skip the Windows setup questions (local account, no Microsoft account or Microsoft 365 offers)? (Y/N) "
        bypass_name     = "Name of the local Windows account to create (press Enter without typing anything for '{0}'): "
        bypass_done     = "Answer file written to the drive: autounattend.xml (local account '{0}'). The language, edition and disk screens are still shown."
        ua_pc           = "Computer name (type a name, or press Enter to let Windows choose one): "
        ua_lang         = "Language, keyboard and time zone: 0 = ask me during setup, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (press the number, Enter = 0): "
        ua_edition      = "Edition: 0 = ask me during setup, 1 = Pro, 2 = Home (press the number, Enter = 0): "
        ua_auto         = "Sign in automatically as admin on first start? (Y/N) "
        ua_pwd          = "Admin account password: "
        ua_pwd2         = "Confirm the password: "
        ua_pwd_bad      = "Empty or mismatching password. Try again."
        m_pwdmode       = "Admin password"
        m_pwd_auto      = "temporary auto, then empty"
        m_pwd_ask       = "I type it"
        m_wifi          = "Automatic Wi-Fi connection"
        m_grey          = "(not needed with Wi-Fi)"
        ua_wifi_ssid    = "Wi-Fi network name (SSID): "
        ua_wifi_pwd     = "Wi-Fi password (8 characters minimum): "
        ua_wifi_pwd2    = "Confirm the Wi-Fi password: "
        ua_wifi_bad     = "Wi-Fi password too short or mismatching. Try again."
        ua_wifi         = "Connect the PC to a Wi-Fi network automatically on first start? (Y/N) "
        ua_pwdmode      = "Type the admin password yourself (otherwise temporary automatic, then empty)? (Y/N) "
        ua_clean        = "Keep the drive plugged in until the desktop appears: on first start the passwords will be erased from the drive."
        ua_updates      = "Pause automatic updates (less secure)? (Y/N) "
        ua_hw           = "Skip the Windows 11 compatibility checks (TPM, Secure Boot, memory, CPU)? (Y/N) "
        recap_key       = "{0} GB drive: look for this size in the Windows setup disk list."
        copying         = 'Copying files...'
        robocopy_err    = 'robocopy hit errors (code {0}). See {1}'
        bootwim_missing = 'sources\boot.wim is missing from the drive: incomplete copy. See {0}'
        write_ok        = 'Write test on the drive: OK'
        write_fail      = 'Cannot write to {0}: {1}'
        splitting       = 'Splitting install.wim into {0} (~5 GB free needed)...'
        split_title     = 'Splitting install.wim'
        split_status    = '{0} MB / {1} MB — {2} MB/s'
        copy_title      = 'Copying files to the drive'
        copy_status     = '{0} MB — {1} MB/s'
        copying_swm     = 'Copying the pieces to the drive...'
        split_done      = 'Split complete.'
        dism_fail       = 'DISM failed (code {0}). Last lines of {1}:'
        esd_copy        = 'install.esd detected: copying it directly.'
        no_image        = 'Neither install.wim nor install.esd found in the ISO.'
        copy_summary    = 'Copy finished: {0} MB in {1} — {2} MB/s on average.'
        split_summary   = 'Split: {0} MB in {1} — {2} MB/s.'
        swm_summary     = 'Pieces written to the drive: {0} MB in {1} — {2} MB/s.'
        total_speed     = 'Total written to the drive: {0} GB in {1} — {2} MB/s (write cache flushed).'
        slow_drive      = 'Slow drive ({0} MB/s): a USB 3.x drive in a USB 3 port would be much faster.'
        done            = 'Done: the drive is ready at {0}'
        logs            = 'Logs: {0}, {1} and {2}'
        inv_file        = 'File'
        inv_mb          = 'MB'
    }
    es = @{
        need_admin      = "Abre la consola como administrador."
        dl_title        = "Descarga del ISO de Windows 11 desde Microsoft"
        ask_lang        = "Idioma de la página de Microsoft [{0}] (Intro para aceptar, u otro código, p. ej. fr-fr)"
        bad_code        = "Código no válido: se mantiene el idioma detectado ({0})."
        official_page   = "Página oficial: {0}"
        no_fixed_link   = "Microsoft no publica un enlace fijo: el enlace directo se genera en cada descarga`ny solo es válido 24 horas."
        step1           = "  1. Abre la página oficial anterior en tu navegador."
        step2           = "  2. En «Descargar imagen de disco de Windows 11 (ISO) para dispositivos x64», elige el ISO`n     multiedición, luego el idioma del producto (idioma de tu sistema: {0}) y pulsa «Confirmar»."
        step3           = "  3. Clic derecho en el botón de descarga de 64 bits > «Copiar dirección del vínculo»: el script lo detecta solo.`n     Pega el vínculo COMPLETO, incluido lo que sigue a «.iso?»: esa parte es la que lo autoriza."
        open_fail       = "No se pudo abrir el navegador: abre la página a mano."
        wait_link       = "Esperando el enlace: haz clic en «Copiar dirección del vínculo» en el navegador.`n(Intro = pegar el enlace a mano)"
        clip_found      = "Enlace detectado en el portapapeles: {0}. ¿Usarlo? (S/n)"
        ask_url         = "Pega aquí la URL del enlace (https://...microsoft.com/....iso)"
        url_refused     = "URL rechazada: debe ser https, de un dominio *.microsoft.com, y su ruta debe terminar en .iso."
        file_exists     = "{0} ya existe en {1}: se usa el archivo existente."
        querying        = "Consultando el servidor de Microsoft..."
        http_err        = "El servidor de Microsoft respondió HTTP {0} (0 = sin respuesta): enlace caducado, incompleto (sin la parte posterior a «.iso?») o red inaccesible.`nGenera un nuevo enlace en la página oficial."
        size_unknown    = "Tamaño del ISO no comunicado: se supone 8 GB."
        size_line       = "  Tamaño del ISO                        : {0} GB"
        split_line      = "  División local de install.wim (est.)  : {0} GB"
        need_line       = "  Espacio necesario (con margen)        : {0} GB"
        free_unknown    = "  Espacio libre: no se puede determinar para {0}, comprobación omitida."
        free_line       = "  Espacio libre                         : {0} GB ({1})"
        insufficient    = "Espacio en disco insuficiente: faltan {0} GB."
        confirm_dl      = "¿Iniciar la descarga en {0}? (S/N)"
        dl_running      = "Descargando..."
        dl_par          = "Descarga en paralelo con {0} conexiones (se puede reanudar)..."
        menu_help       = "↑↓ mover · Espacio marcar · ←→ cambiar · Intro validar · Esc cancelar"
        menu_opts_title = "Opciones de la instalación de Windows"
        m_bypass        = "Omitir preguntas de instalación (cuenta local)"
        m_lang          = "Idioma, teclado y zona horaria"
        m_ed            = "Edición"
        m_ask           = "preguntármelo"
        m_home          = "Home"
        m_auto          = "Inicio de sesión admin automático"
        m_upd           = "Pausar las actualizaciones (menos seguro)"
        m_hw            = "Omitir controles TPM / Secure Boot / memoria / CPU"
        ua_note         = "Nota: en el primer inicio, conecta el PC a Internet. Windows Update instalará las aplicaciones (iconos del menú Inicio) en 10 a 30 minutos."
        menu_dl_title   = "Descarga del ISO desde Microsoft"
        m_dl_lang       = "Idioma de la página de Microsoft"
        m_other         = "otro…"
        dl_pause_hint   = "[P] pausa"
        dl_paused       = "EN PAUSA — pulse P para reanudar"
        recap_speed     = "Resumen de velocidades: descarga {0} MB/s · escritura en la unidad {1} MB/s"
        bits_fail       = "BITS falló ({0}): probando con curl.exe..."
        dl_fail         = "Error en la descarga (¿enlace caducado o red?). Genera un nuevo enlace en la página de Microsoft."
        dl_done         = "Descarga terminada: {0}"
        dl_speed        = "Velocidad media de descarga: {0} MB/s"
        sha_calc        = "Calculando el hash SHA-256 (unos minutos)..."
        sha_ok          = "El hash coincide con el publicado por Microsoft ({0} - {1})."
        sha_unknown     = "Hash no reconocido (versión o idioma ausente de iso_hashes.txt, o archivo alterado)."
        sha_computed    = "SHA-256 calculado: {0}"
        ask_sha         = "Hash SHA-256 que muestra Microsoft para este idioma (Intro para omitir)"
        sha_match       = "El hash coincide."
        sha_bad         = "El hash difiere: archivo dañado o incompleto. Bórralo y vuelve a empezar."
        published_found = "Enlace ya generado (iso_links.txt): build {0}, válido todavía {1}. ¿Usarlo? (S/n)"
        published_dead  = "Ese enlace publicado no responde (HTTP {0}): se vuelve al método manual."
        no_iso          = "No se encontró ningún archivo .iso en {0}."
        ask_no_iso      = "T para descargar el ISO desde Microsoft, o ruta completa del ISO"
        isos_found      = "ISO encontrados en {0}:"
        menu_download   = "  [T] Descargar un ISO de Windows 11 desde Microsoft"
        ask_iso         = "Número del ISO a usar (o T)"
        bad_choice      = "Opción no válida."
        iso_selected    = "ISO seleccionado: {0}"
        iso_missing     = "ISO no encontrado."
        disk_short      = "Espacio en disco insuficiente en {0}: se necesitan {1} GB para dividir install.wim, hay {2} GB libres."
        no_usb          = "No se detectó ninguna unidad USB."
        ask_usb         = "Número de la unidad USB que se BORRARÁ"
        not_usb         = "Ese número no es una unidad USB."
        too_small       = "Unidad demasiado pequeña: {0} GB para un ISO de {1} GB."
        confirm_erase   = "¿Confirmar el borrado de '{0}'? (S/N)"
        keep_confirm    = "'{0}' ya tiene una disposición compatible: solo se reformateará la partición FAT32; las {1} otra(s) partición(es) se conservan. ¿Continuar? (S/N)"
        data_warn       = "ATENCIÓN: esta unidad tiene archivos en una partición de datos y su partición FAT32 es demasiado pequeña para este ISO (se necesitan {0} GB). Continuar reparticiona la unidad y BORRA esos archivos."
        data_ask        = "Para borrarlos igualmente, escribe {0} (Intro para cancelar): "
        erase_word      = "BORRAR"
        data_created    = "Partición de datos exFAT 'DONNEES' creada: {0} GB para tus archivos (la FAT32 conserva margen para futuras versiones de Windows)."
        kept            = "Disposición conservada: solo se reformatea la partición FAT32."
        eject_ask       = "¿Expulsar ahora la unidad USB de forma segura? (S/N) "
        busy_prep       = "Preparando la unidad (borrado, particiones, formato)"
        busy_flush      = "Escritura final en la unidad, no la desconectes"
        busy_eject      = "Expulsando la unidad"
        eject_ok        = "Unidad expulsada: ya puedes desconectarla."
        eject_fail      = "No se pudo expulsar (¿unidad en uso?). Cierra las ventanas que la usen y exprúlsala desde el sistema antes de desconectarla."
        bypass_ask      = "¿Omitir las preguntas de la instalación de Windows (cuenta local, sin cuenta Microsoft ni ofertas de Microsoft 365)? (S/N) "
        bypass_name     = "Nombre de la cuenta local de Windows que se creará (pulsa Intro sin escribir nada para '{0}'): "
        bypass_done     = "Archivo de respuestas escrito en la unidad: autounattend.xml (cuenta local '{0}'). Las pantallas de idioma, edición y disco siguen apareciendo."
        ua_pc           = "Nombre del equipo (escribe un nombre o pulsa Intro para que Windows elija uno): "
        ua_lang         = "Idioma, teclado y zona horaria: 0 = preguntármelo, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (pulsa el número, Intro = 0): "
        ua_edition      = "Edición: 0 = preguntármelo, 1 = Pro, 2 = Home (pulsa el número, Intro = 0): "
        ua_auto         = "¿Iniciar sesión admin automáticamente en el primer arranque? (S/N) "
        ua_pwd          = "Contraseña de la cuenta admin: "
        ua_pwd2         = "Confirma la contraseña: "
        ua_pwd_bad      = "Contraseña vacía o diferente. Inténtalo de nuevo."
        m_pwdmode       = "Contraseña admin"
        m_pwd_auto      = "temporal auto, luego vacía"
        m_pwd_ask       = "la escribo yo"
        m_wifi          = "Conexión Wi-Fi automática"
        m_grey          = "(innecesario con Wi-Fi)"
        ua_wifi_ssid    = "Nombre de la red Wi-Fi (SSID): "
        ua_wifi_pwd     = "Contraseña del Wi-Fi (mínimo 8 caracteres): "
        ua_wifi_pwd2    = "Confirma la contraseña del Wi-Fi: "
        ua_wifi_bad     = "Contraseña Wi-Fi demasiado corta o diferente. Inténtalo de nuevo."
        ua_wifi         = "¿Conectar el PC automáticamente a una red Wi-Fi en el primer arranque? (S/N) "
        ua_pwdmode      = "¿Escribir tú mismo la contraseña admin (si no, temporal automática y luego vacía)? (S/N) "
        ua_clean        = "Deja la unidad conectada hasta que aparezca el escritorio: en el primer arranque se borrarán las contraseñas de la unidad."
        ua_updates      = "¿Pausar las actualizaciones automáticas (menos seguro)? (S/N) "
        ua_hw           = "¿Omitir las comprobaciones de compatibilidad de Windows 11 (TPM, Secure Boot, memoria, CPU)? (S/N) "
        recap_key       = "Unidad de {0} GB: busca este tamaño en la lista de discos del instalador de Windows."
        copying         = "Copiando archivos..."
        robocopy_err    = "robocopy encontró errores (código {0}). Consulta {1}"
        bootwim_missing = "Falta sources\boot.wim en la unidad: copia incompleta. Consulta {0}"
        write_ok        = "Prueba de escritura en la unidad: OK"
        write_fail      = "No se puede escribir en {0}: {1}"
        splitting       = "Dividiendo install.wim en {0} (~5 GB libres necesarios)..."
        split_title     = "División de install.wim"
        split_status    = "{0} MB / {1} MB — {2} MB/s"
        copy_title      = "Copiando archivos a la unidad"
        copy_status     = "{0} MB — {1} MB/s"
        copying_swm     = "Copiando los fragmentos a la unidad..."
        split_done      = "División completada."
        dism_fail       = "DISM falló (código {0}). Últimas líneas de {1}:"
        esd_copy        = "install.esd detectado: se copia directamente."
        no_image        = "No se encontró ni install.wim ni install.esd en el ISO."
        copy_summary    = "Copia terminada: {0} MB en {1} — {2} MB/s de media."
        split_summary   = "División: {0} MB en {1} — {2} MB/s."
        swm_summary     = "Fragmentos escritos en la unidad: {0} MB en {1} — {2} MB/s."
        total_speed     = "Total escrito en la unidad: {0} GB en {1} — {2} MB/s (caché de escritura vaciada)."
        slow_drive      = "Unidad lenta ({0} MB/s): una unidad USB 3.x en un puerto USB 3 sería mucho más rápida."
        done            = "Terminado: la unidad está lista en {0}"
        logs            = "Registros: {0}, {1} y {2}"
        inv_file        = "Archivo"
        inv_mb          = "MB"
    }
    de = @{
        need_admin      = "Öffne die Konsole als Administrator."
        dl_title        = "Windows-11-ISO wird von Microsoft heruntergeladen"
        ask_lang        = "Sprache der Microsoft-Seite [{0}] (Eingabe zum Übernehmen, oder anderer Code, z. B. de-de)"
        bad_code        = "Ungültiger Code: erkannte Sprache bleibt erhalten ({0})."
        official_page   = "Offizielle Seite: {0}"
        no_fixed_link   = "Microsoft veröffentlicht keinen festen Link: Der direkte Link wird bei jedem Download erzeugt`nund ist nur 24 Stunden gültig."
        step1           = "  1. Öffne die obige offizielle Seite in deinem Browser."
        step2           = "  2. Wähle unter 'Windows 11-Datenträgerabbild (ISO) für x64-Geräte herunterladen' die ISO mit`n     mehreren Editionen, dann die Produktsprache (deine Systemsprache: {0}) und klicke auf 'Bestätigen'."
        step3           = "  3. Rechtsklick auf die 64-Bit-Download-Schaltfläche > 'Link-Adresse kopieren': Das Skript erkennt ihn selbst.`n     Füge den GANZEN Link ein, einschließlich dessen, was nach '.iso?' folgt: Dieser Teil autorisiert ihn."
        open_fail       = "Browser konnte nicht geöffnet werden: Seite von Hand öffnen."
        wait_link       = "Warte auf den Link: Klicke im Browser auf 'Link-Adresse kopieren'.`n(Eingabe = Link von Hand einfügen)"
        clip_found      = "Link in der Zwischenablage erkannt: {0}. Verwenden? (J/n)"
        ask_url         = "Link-URL hier einfügen (https://...microsoft.com/....iso)"
        url_refused     = "URL abgelehnt: Sie muss https verwenden, zu einer *.microsoft.com-Domain gehören und der Pfad muss auf .iso enden."
        file_exists     = "{0} existiert bereits in {1}: vorhandene Datei wird verwendet."
        querying        = "Microsoft-Server wird abgefragt..."
        http_err        = "Der Microsoft-Server antwortete mit HTTP {0} (0 = keine Antwort): Link abgelaufen, unvollständig (Teil nach '.iso?' fehlt) oder Netzwerk nicht erreichbar.`nErzeuge einen neuen Link auf der offiziellen Seite."
        size_unknown    = "ISO-Größe nicht mitgeteilt: Annahme von 8 GB."
        size_line       = "  ISO-Größe                             : {0} GB"
        split_line      = "  Lokale Aufteilung von install.wim (gesch.) : {0} GB"
        need_line       = "  Benötigter Platz (mit Reserve)        : {0} GB"
        free_unknown    = "  Freier Platz: für {0} nicht ermittelbar, Prüfung übersprungen."
        free_line       = "  Freier Platz                          : {0} GB ({1})"
        insufficient    = "Nicht genug Speicherplatz: {0} GB fehlen."
        confirm_dl      = "Download nach {0} starten? (J/N)"
        dl_running      = "Download läuft..."
        dl_par          = "Paralleler Download mit {0} Verbindungen (fortsetzbar)..."
        menu_help       = "↑↓ wählen · Leertaste anhaken · ←→ ändern · Eingabe OK · Esc abbrechen"
        menu_opts_title = "Optionen der Windows-Installation"
        m_bypass        = "Einrichtungsfragen überspringen (lokales Konto)"
        m_lang          = "Sprache, Tastatur, Zeitzone"
        m_ed            = "Edition"
        m_ask           = "mich fragen"
        m_home          = "Home"
        m_auto          = "Automatische Admin-Anmeldung"
        m_upd           = "Updates pausieren (weniger sicher)"
        m_hw            = "TPM-/Secure-Boot-/Speicher-/CPU-Prüfung überspringen"
        ua_note         = "Hinweis: Verbinden Sie den PC beim ersten Start mit dem Internet. Windows Update installiert die Apps (Symbole im Startmenü) innerhalb von 10 bis 30 Minuten."
        menu_dl_title   = "ISO von Microsoft herunterladen"
        m_dl_lang       = "Sprache der Microsoft-Seite"
        m_other         = "andere…"
        dl_pause_hint   = "[P] Pause"
        dl_paused       = "PAUSIERT — P zum Fortsetzen"
        recap_speed     = "Geschwindigkeiten: Download {0} MB/s · Schreiben auf den Stick {1} MB/s"
        bits_fail       = "BITS fehlgeschlagen ({0}): Versuch mit curl.exe..."
        dl_fail         = "Download fehlgeschlagen (Link abgelaufen oder Netzwerk?). Erzeuge einen neuen Link auf der Microsoft-Seite."
        dl_done         = "Download abgeschlossen: {0}"
        dl_speed        = "Durchschnittliche Download-Geschwindigkeit: {0} MB/s"
        sha_calc        = "SHA-256-Hash wird berechnet (einige Minuten)..."
        sha_ok          = "Hash stimmt mit dem von Microsoft veröffentlichten überein ({0} - {1})."
        sha_unknown     = "Hash nicht erkannt (Version oder Sprache fehlt in iso_hashes.txt, oder Datei verändert)."
        sha_computed    = "Berechneter SHA-256: {0}"
        ask_sha         = "Von Microsoft für diese Sprache angezeigter SHA-256-Hash (Eingabe zum Überspringen)"
        sha_match       = "Hash stimmt überein."
        sha_bad         = "Hash weicht ab: Datei beschädigt oder unvollständig. Löschen und neu beginnen."
        published_found = "Bereits erzeugter Link (iso_links.txt): Build {0}, noch gültig für {1}. Verwenden? (J/n)"
        published_dead  = "Dieser veröffentlichte Link antwortet nicht (HTTP {0}): Rückfall auf die manuelle Methode."
        no_iso          = "Keine .iso-Datei in {0} gefunden."
        ask_no_iso      = "T zum Herunterladen der ISO von Microsoft, oder vollständiger Pfad der ISO"
        isos_found      = "ISO-Dateien in {0}:"
        menu_download   = "  [T] Windows-11-ISO von Microsoft herunterladen"
        ask_iso         = "Nummer der zu verwendenden ISO (oder T)"
        bad_choice      = "Ungültige Auswahl."
        iso_selected    = "Gewählte ISO: {0}"
        iso_missing     = "ISO nicht gefunden."
        disk_short      = "Nicht genug Speicherplatz in {0}: {1} GB zum Aufteilen von install.wim nötig, {2} GB frei."
        no_usb          = "Kein USB-Laufwerk erkannt."
        ask_usb         = "Nummer des USB-Laufwerks, das GELÖSCHT wird"
        not_usb         = "Diese Nummer ist kein USB-Laufwerk."
        too_small       = "USB-Laufwerk zu klein: {0} GB für eine ISO mit {1} GB."
        confirm_erase   = "Löschen von '{0}' bestätigen? (J/N)"
        keep_confirm    = "'{0}' hat bereits ein kompatibles Layout: nur die FAT32-Partition wird neu formatiert, die {1} weitere(n) Partition(en) bleiben erhalten. Fortfahren? (J/N)"
        data_warn       = "ACHTUNG: Dieses Laufwerk enthält Dateien in einer Datenpartition, und die FAT32-Partition ist für diese ISO zu klein ({0} GB nötig). Fortfahren partitioniert neu und LÖSCHT diese Dateien."
        data_ask        = "Zum Löschen trotzdem {0} eingeben (Enter = abbrechen): "
        erase_word      = "LÖSCHEN"
        data_created    = "exFAT-Datenpartition 'DONNEES' angelegt: {0} GB für deine Dateien (die FAT32-Partition behält Reserve für künftige Windows-Versionen)."
        kept            = "Layout beibehalten: nur die FAT32-Partition wird neu formatiert."
        eject_ask       = "USB-Laufwerk jetzt sicher auswerfen? (J/N) "
        busy_prep       = "Stick wird vorbereitet (Löschen, Partitionieren, Formatieren)"
        busy_flush      = "Letzte Schreibvorgänge auf den Stick, nicht abziehen"
        busy_eject      = "Stick wird ausgeworfen"
        eject_ok        = "Laufwerk ausgeworfen: Du kannst es abziehen."
        eject_fail      = "Auswerfen nicht möglich (Laufwerk noch in Benutzung?). Schließe Fenster, die es nutzen, und wirf es im System aus, bevor du es abziehst."
        bypass_ask      = "Fragen der Windows-Einrichtung überspringen (lokales Konto, ohne Microsoft-Konto und Microsoft-365-Angebote)? (J/N) "
        bypass_name     = "Name des anzulegenden lokalen Windows-Kontos (Eingabetaste ohne Text drücken für '{0}'): "
        bypass_done     = "Antwortdatei auf den Stick geschrieben: autounattend.xml (lokales Konto '{0}'). Sprach-, Editions- und Datenträgerauswahl bleiben sichtbar."
        ua_pc           = "Computername (Namen eingeben oder Eingabetaste drücken, damit Windows einen wählt): "
        ua_lang         = "Sprache, Tastatur und Zeitzone: 0 = bei der Installation fragen, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (Ziffer drücken, Eingabe = 0): "
        ua_edition      = "Edition: 0 = bei der Installation fragen, 1 = Pro, 2 = Home (Ziffer drücken, Eingabe = 0): "
        ua_auto         = "Beim ersten Start automatisch als Admin anmelden? (J/N) "
        ua_pwd          = "Kennwort des Admin-Kontos: "
        ua_pwd2         = "Kennwort bestätigen: "
        ua_pwd_bad      = "Kennwort leer oder abweichend. Bitte erneut versuchen."
        m_pwdmode       = "Admin-Kennwort"
        m_pwd_auto      = "temporär automatisch, danach leer"
        m_pwd_ask       = "ich gebe es ein"
        m_wifi          = "Automatische WLAN-Verbindung"
        m_grey          = "(mit WLAN unnötig)"
        ua_wifi_ssid    = "Name des WLAN-Netzwerks (SSID): "
        ua_wifi_pwd     = "WLAN-Kennwort (mindestens 8 Zeichen): "
        ua_wifi_pwd2    = "WLAN-Kennwort bestätigen: "
        ua_wifi_bad     = "WLAN-Kennwort zu kurz oder abweichend. Bitte erneut versuchen."
        ua_wifi         = "PC beim ersten Start automatisch mit einem WLAN verbinden? (J/N) "
        ua_pwdmode      = "Admin-Kennwort selbst eingeben (sonst temporär automatisch, danach leer)? (J/N) "
        ua_clean        = "Stick bis zum Desktop eingesteckt lassen: beim ersten Start werden die Kennwörter vom Stick gelöscht."
        ua_updates      = "Automatische Updates pausieren (weniger sicher)? (J/N) "
        ua_hw           = "Windows-11-Kompatibilitätsprüfungen überspringen (TPM, Secure Boot, Speicher, CPU)? (J/N) "
        recap_key       = "Stick mit {0} GB: Diese Größe in der Datenträgerliste des Windows-Setups suchen."
        copying         = "Dateien werden kopiert..."
        robocopy_err    = "robocopy hat Fehler gemeldet (Code {0}). Siehe {1}"
        bootwim_missing = "sources\boot.wim fehlt auf dem Laufwerk: unvollständige Kopie. Siehe {0}"
        write_ok        = "Schreibtest auf dem Laufwerk: OK"
        write_fail      = "Schreiben auf {0} nicht möglich: {1}"
        splitting       = "install.wim wird in {0} aufgeteilt (~5 GB freier Platz nötig)..."
        split_title     = "Aufteilung von install.wim"
        split_status    = "{0} MB / {1} MB — {2} MB/s"
        copy_title      = "Dateien werden auf das Laufwerk kopiert"
        copy_status     = "{0} MB — {1} MB/s"
        copying_swm     = "Teile werden auf das Laufwerk kopiert..."
        split_done      = "Aufteilung abgeschlossen."
        dism_fail       = "DISM ist fehlgeschlagen (Code {0}). Letzte Zeilen von {1}:"
        esd_copy        = "install.esd erkannt: wird direkt kopiert."
        no_image        = "Weder install.wim noch install.esd in der ISO gefunden."
        copy_summary    = "Kopieren abgeschlossen: {0} MB in {1} — {2} MB/s im Durchschnitt."
        split_summary   = "Aufteilung: {0} MB in {1} — {2} MB/s."
        swm_summary     = "Auf das Laufwerk geschriebene Teile: {0} MB in {1} — {2} MB/s."
        total_speed     = "Insgesamt auf das Laufwerk geschrieben: {0} GB in {1} — {2} MB/s (Schreibcache geleert)."
        slow_drive      = "Langsames Laufwerk ({0} MB/s): Ein USB-3.x-Laufwerk an einem USB-3-Anschluss wäre deutlich schneller."
        done            = "Fertig: Das Laufwerk ist bereit unter {0}"
        logs            = "Protokolle: {0}, {1} und {2}"
        inv_file        = "Datei"
        inv_mb          = "MB"
    }
    it = @{
        need_admin      = "Apri la console come amministratore."
        dl_title        = "Download dell'ISO di Windows 11 da Microsoft"
        ask_lang        = "Lingua della pagina Microsoft [{0}] (Invio per confermare, o altro codice, es. it-it)"
        bad_code        = "Codice non valido: lingua rilevata mantenuta ({0})."
        official_page   = "Pagina ufficiale: {0}"
        no_fixed_link   = "Microsoft non pubblica un link fisso: il link diretto viene generato a ogni download`ned è valido solo 24 ore."
        step1           = "  1. Apri la pagina ufficiale qui sopra nel browser."
        step2           = "  2. In «Scarica l'immagine del disco di Windows 11 (ISO) per dispositivi x64», scegli l'ISO`n     multi-edizione, poi la lingua del prodotto (lingua del tuo sistema: {0}) e fai clic su «Conferma»."
        step3           = "  3. Clic destro sul pulsante di download a 64 bit > «Copia indirizzo link»: lo script lo rileva da solo.`n     Incolla il link COMPLETO, compresa la parte dopo «.iso?»: è quella che lo autorizza."
        open_fail       = "Impossibile aprire il browser: apri la pagina a mano."
        wait_link       = "In attesa del link: fai clic su «Copia indirizzo link» nel browser.`n(Invio = incolla il link a mano)"
        clip_found      = "Link rilevato negli appunti: {0}. Usarlo? (S/n)"
        ask_url         = "Incolla qui l'URL del link (https://...microsoft.com/....iso)"
        url_refused     = "URL rifiutato: deve essere https, di un dominio *.microsoft.com, e il percorso deve terminare con .iso."
        file_exists     = "{0} esiste già in {1}: uso il file esistente."
        querying        = "Interrogazione del server Microsoft..."
        http_err        = "Il server Microsoft ha risposto HTTP {0} (0 = nessuna risposta): link scaduto, incompleto (senza la parte dopo «.iso?») o rete non raggiungibile.`nGenera un nuovo link sulla pagina ufficiale."
        size_unknown    = "Dimensione dell'ISO non comunicata: ipotizzo 8 GB."
        size_line       = "  Dimensione ISO                        : {0} GB"
        split_line      = "  Divisione locale di install.wim (stima) : {0} GB"
        need_line       = "  Spazio necessario (con margine)       : {0} GB"
        free_unknown    = "  Spazio libero: non determinabile per {0}, controllo saltato."
        free_line       = "  Spazio libero                         : {0} GB ({1})"
        insufficient    = "Spazio su disco insufficiente: mancano {0} GB."
        confirm_dl      = "Avviare il download in {0}? (S/N)"
        dl_running      = "Download in corso..."
        dl_par          = "Download parallelo su {0} connessioni (riprendibile)..."
        menu_help       = "↑↓ muovi · Spazio spunta · ←→ cambia · Invio conferma · Esc annulla"
        menu_opts_title = "Opzioni di installazione di Windows"
        m_bypass        = "Salta le domande di installazione (account locale)"
        m_lang          = "Lingua, tastiera, fuso orario"
        m_ed            = "Edizione"
        m_ask           = "chiedimelo"
        m_home          = "Home"
        m_auto          = "Accesso admin automatico"
        m_upd           = "Sospendi gli aggiornamenti (meno sicuro)"
        m_hw            = "Salta i controlli TPM / Secure Boot / memoria / CPU"
        ua_note         = "Nota: al primo avvio collega il PC a Internet. Windows Update installerà le app (icone del menu Start) entro 10-30 minuti."
        menu_dl_title   = "Download dell'ISO da Microsoft"
        m_dl_lang       = "Lingua della pagina Microsoft"
        m_other         = "altro…"
        dl_pause_hint   = "[P] pausa"
        dl_paused       = "IN PAUSA — premi P per riprendere"
        recap_speed     = "Riepilogo velocità: download {0} MB/s · scrittura sull'unità {1} MB/s"
        bits_fail       = "BITS non riuscito ({0}): provo con curl.exe..."
        dl_fail         = "Download non riuscito (link scaduto o rete?). Genera un nuovo link sulla pagina Microsoft."
        dl_done         = "Download completato: {0}"
        dl_speed        = "Velocità media di download: {0} MB/s"
        sha_calc        = "Calcolo dell'hash SHA-256 (qualche minuto)..."
        sha_ok          = "L'hash corrisponde a quello pubblicato da Microsoft ({0} - {1})."
        sha_unknown     = "Hash non riconosciuto (versione o lingua assente da iso_hashes.txt, o file alterato)."
        sha_computed    = "SHA-256 calcolato: {0}"
        ask_sha         = "Hash SHA-256 mostrato da Microsoft per questa lingua (Invio per saltare)"
        sha_match       = "L'hash corrisponde."
        sha_bad         = "L'hash è diverso: file danneggiato o incompleto. Eliminalo e ricomincia."
        published_found = "Link già generato (iso_links.txt): build {0}, ancora valido per {1}. Usarlo? (S/n)"
        published_dead  = "Questo link pubblicato non risponde (HTTP {0}): ritorno al metodo manuale."
        no_iso          = "Nessun file .iso trovato in {0}."
        ask_no_iso      = "T per scaricare l'ISO da Microsoft, oppure percorso completo dell'ISO"
        isos_found      = "ISO trovati in {0}:"
        menu_download   = "  [T] Scarica un ISO di Windows 11 da Microsoft"
        ask_iso         = "Numero dell'ISO da usare (o T)"
        bad_choice      = "Scelta non valida."
        iso_selected    = "ISO selezionato: {0}"
        iso_missing     = "ISO non trovato."
        disk_short      = "Spazio su disco insufficiente in {0}: servono {1} GB per dividere install.wim, {2} GB liberi."
        no_usb          = "Nessuna unità USB rilevata."
        ask_usb         = "Numero dell'unità USB da CANCELLARE"
        not_usb         = "Questo numero non è un'unità USB."
        too_small       = "Unità troppo piccola: {0} GB per un ISO da {1} GB."
        confirm_erase   = "Confermare la cancellazione di '{0}'? (S/N)"
        keep_confirm    = "'{0}' ha già una disposizione compatibile: verrà riformattata solo la partizione FAT32, le altre {1} partizione/i restano intatte. Continuare? (S/N)"
        data_warn       = "ATTENZIONE: questa unità contiene file in una partizione dati e la partizione FAT32 è troppo piccola per questo ISO (servono {0} GB). Continuare ripartiziona l'unità e CANCELLA quei file."
        data_ask        = "Per cancellarli comunque, scrivi {0} (Invio per annullare): "
        erase_word      = "CANCELLA"
        data_created    = "Partizione dati exFAT 'DONNEES' creata: {0} GB per i tuoi file (la FAT32 mantiene margine per le future versioni di Windows)."
        kept            = "Disposizione mantenuta: viene riformattata solo la partizione FAT32."
        eject_ask       = "Espellere ora la chiavetta USB in sicurezza? (S/N) "
        busy_prep       = "Preparazione della chiavetta (cancellazione, partizioni, formattazione)"
        busy_flush      = "Scrittura finale sulla chiavetta, non scollegarla"
        busy_eject      = "Espulsione della chiavetta"
        eject_ok        = "Chiavetta espulsa: puoi scollegarla."
        eject_fail      = "Impossibile espellere (chiavetta ancora in uso?). Chiudi le finestre che la usano ed espellila dal sistema prima di scollegarla."
        bypass_ask      = "Saltare le domande dell'installazione di Windows (account locale, senza account Microsoft né offerte Microsoft 365)? (S/N) "
        bypass_name     = "Nome dell'account locale di Windows da creare (premi Invio senza scrivere nulla per '{0}'): "
        bypass_done     = "File di risposte scritto sulla chiavetta: autounattend.xml (account locale '{0}'). Le schermate di lingua, edizione e disco restano visibili."
        ua_pc           = "Nome del computer (scrivi un nome o premi Invio per lasciarlo scegliere a Windows): "
        ua_lang         = "Lingua, tastiera e fuso orario: 0 = chiedimelo, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (premi il numero, Invio = 0): "
        ua_edition      = "Edizione: 0 = chiedimelo, 1 = Pro, 2 = Home (premi il numero, Invio = 0): "
        ua_auto         = "Accedere automaticamente come admin al primo avvio? (S/N) "
        ua_pwd          = "Password dell'account admin: "
        ua_pwd2         = "Conferma la password: "
        ua_pwd_bad      = "Password vuota o diversa. Riprova."
        m_pwdmode       = "Password admin"
        m_pwd_auto      = "provvisoria auto, poi vuota"
        m_pwd_ask       = "la digito io"
        m_wifi          = "Connessione Wi-Fi automatica"
        m_grey          = "(inutile con il Wi-Fi)"
        ua_wifi_ssid    = "Nome della rete Wi-Fi (SSID): "
        ua_wifi_pwd     = "Password del Wi-Fi (minimo 8 caratteri): "
        ua_wifi_pwd2    = "Conferma la password del Wi-Fi: "
        ua_wifi_bad     = "Password Wi-Fi troppo corta o diversa. Riprova."
        ua_wifi         = "Collegare automaticamente il PC a una rete Wi-Fi al primo avvio? (S/N) "
        ua_pwdmode      = "Digitare tu la password admin (altrimenti provvisoria automatica, poi vuota)? (S/N) "
        ua_clean        = "Lascia la chiavetta inserita fino alla comparsa del desktop: al primo avvio le password verranno cancellate dalla chiavetta."
        ua_updates      = "Sospendere gli aggiornamenti automatici (meno sicuro)? (S/N) "
        ua_hw           = "Saltare i controlli di compatibilità di Windows 11 (TPM, Secure Boot, memoria, CPU)? (S/N) "
        recap_key       = "Chiavetta da {0} GB: cerca questa dimensione nell'elenco dei dischi del programma di installazione di Windows."
        copying         = "Copia dei file in corso..."
        robocopy_err    = "robocopy ha rilevato errori (codice {0}). Vedi {1}"
        bootwim_missing = "sources\boot.wim assente dall'unità: copia incompleta. Vedi {0}"
        write_ok        = "Test di scrittura sull'unità: OK"
        write_fail      = "Impossibile scrivere su {0}: {1}"
        splitting       = "Divisione di install.wim in {0} (~5 GB liberi necessari)..."
        split_title     = "Divisione di install.wim"
        split_status    = "{0} MB / {1} MB — {2} MB/s"
        copy_title      = "Copia dei file sull'unità"
        copy_status     = "{0} MB — {1} MB/s"
        copying_swm     = "Copia dei frammenti sull'unità..."
        split_done      = "Divisione completata."
        dism_fail       = "DISM non è riuscito (codice {0}). Ultime righe di {1}:"
        esd_copy        = "install.esd rilevato: copia diretta."
        no_image        = "Né install.wim né install.esd trovati nell'ISO."
        copy_summary    = "Copia terminata: {0} MB in {1} — {2} MB/s in media."
        split_summary   = "Divisione: {0} MB in {1} — {2} MB/s."
        swm_summary     = "Frammenti scritti sull'unità: {0} MB in {1} — {2} MB/s."
        total_speed     = "Totale scritto sull'unità: {0} GB in {1} — {2} MB/s (cache di scrittura svuotata)."
        slow_drive      = "Unità lenta ({0} MB/s): un'unità USB 3.x su una porta USB 3 sarebbe molto più veloce."
        done            = "Fatto: l'unità è pronta in {0}"
        logs            = "Registri: {0}, {1} e {2}"
        inv_file        = "File"
        inv_mb          = "MB"
    }
    pt = @{
        need_admin      = "Abra o console como administrador."
        dl_title        = "Baixando o ISO do Windows 11 da Microsoft"
        ask_lang        = "Idioma da página da Microsoft [{0}] (Enter para aceitar, ou outro código, ex.: pt-br)"
        bad_code        = "Código inválido: idioma detectado mantido ({0})."
        official_page   = "Página oficial: {0}"
        no_fixed_link   = "A Microsoft não publica um link fixo: o link direto é gerado a cada download`ne só é válido por 24 horas."
        step1           = "  1. Abra a página oficial acima no navegador."
        step2           = "  2. Em «Baixar a Imagem de Disco do Windows 11 (ISO) para dispositivos x64», escolha o ISO`n     de várias edições, depois o idioma do produto (idioma do seu sistema: {0}) e clique em «Confirmar»."
        step3           = "  3. Clique com o botão direito no botão de download de 64 bits > «Copiar endereço do link»: o script o detecta sozinho.`n     Cole o link COMPLETO, incluindo o que vem depois de «.iso?»: é essa parte que o autoriza."
        open_fail       = "Não foi possível abrir o navegador: abra a página manualmente."
        wait_link       = "Aguardando o link: clique em «Copiar endereço do link» no navegador.`n(Enter = colar o link manualmente)"
        clip_found      = "Link detectado na área de transferência: {0}. Usá-lo? (S/n)"
        ask_url         = "Cole aqui a URL do link (https://...microsoft.com/....iso)"
        url_refused     = "URL recusada: deve ser https, de um domínio *.microsoft.com, e o caminho deve terminar em .iso."
        file_exists     = "{0} já existe em {1}: usando o arquivo existente."
        querying        = "Consultando o servidor da Microsoft..."
        http_err        = "O servidor da Microsoft respondeu HTTP {0} (0 = sem resposta): link expirado, incompleto (sem a parte depois de «.iso?») ou rede inacessível.`nGere um novo link na página oficial."
        size_unknown    = "Tamanho do ISO não informado: supondo 8 GB."
        size_line       = "  Tamanho do ISO                        : {0} GB"
        split_line      = "  Divisão local do install.wim (est.)   : {0} GB"
        need_line       = "  Espaço necessário (com margem)        : {0} GB"
        free_unknown    = "  Espaço livre: não foi possível determinar para {0}, verificação ignorada."
        free_line       = "  Espaço livre                          : {0} GB ({1})"
        insufficient    = "Espaço em disco insuficiente: faltam {0} GB."
        confirm_dl      = "Iniciar o download em {0}? (S/N)"
        dl_running      = "Baixando..."
        dl_par          = "Transferência em paralelo com {0} ligações (retomável)..."
        menu_help       = "↑↓ mover · Espaço marcar · ←→ mudar · Enter confirmar · Esc cancelar"
        menu_opts_title = "Opções da instalação do Windows"
        m_bypass        = "Ignorar perguntas da instalação (conta local)"
        m_lang          = "Idioma, teclado, fuso horário"
        m_ed            = "Edição"
        m_ask           = "perguntar-me"
        m_home          = "Home"
        m_auto          = "Sessão admin automática"
        m_upd           = "Pausar as atualizações (menos seguro)"
        m_hw            = "Ignorar verificações de TPM / Secure Boot / memória / CPU"
        ua_note         = "Nota: no primeiro arranque, liga o PC à Internet. O Windows Update instalará as aplicações (ícones do menu Iniciar) em 10 a 30 minutos."
        menu_dl_title   = "Transferir o ISO da Microsoft"
        m_dl_lang       = "Idioma da página da Microsoft"
        m_other         = "outro…"
        dl_pause_hint   = "[P] pausa"
        dl_paused       = "EM PAUSA — prima P para retomar"
        recap_speed     = "Resumo das velocidades: transferência {0} MB/s · escrita na unidade {1} MB/s"
        bits_fail       = "BITS falhou ({0}): tentando com curl.exe..."
        dl_fail         = "Falha no download (link expirado ou rede?). Gere um novo link na página da Microsoft."
        dl_done         = "Download concluído: {0}"
        dl_speed        = "Velocidade média de download: {0} MB/s"
        sha_calc        = "Calculando o hash SHA-256 (alguns minutos)..."
        sha_ok          = "O hash corresponde ao publicado pela Microsoft ({0} - {1})."
        sha_unknown     = "Hash não reconhecido (versão ou idioma ausente de iso_hashes.txt, ou arquivo alterado)."
        sha_computed    = "SHA-256 calculado: {0}"
        ask_sha         = "Hash SHA-256 exibido pela Microsoft para este idioma (Enter para ignorar)"
        sha_match       = "O hash corresponde."
        sha_bad         = "O hash é diferente: arquivo corrompido ou incompleto. Exclua-o e recomece."
        published_found = "Link já gerado (iso_links.txt): build {0}, ainda válido por {1}. Usá-lo? (S/n)"
        published_dead  = "Esse link publicado não responde (HTTP {0}): voltando ao método manual."
        no_iso          = "Nenhum arquivo .iso encontrado em {0}."
        ask_no_iso      = "T para baixar o ISO da Microsoft, ou caminho completo do ISO"
        isos_found      = "ISO encontrados em {0}:"
        menu_download   = "  [T] Baixar um ISO do Windows 11 da Microsoft"
        ask_iso         = "Número do ISO a usar (ou T)"
        bad_choice      = "Opção inválida."
        iso_selected    = "ISO selecionado: {0}"
        iso_missing     = "ISO não encontrado."
        disk_short      = "Espaço em disco insuficiente em {0}: {1} GB necessários para dividir o install.wim, {2} GB livres."
        no_usb          = "Nenhuma unidade USB detectada."
        ask_usb         = "Número da unidade USB a APAGAR"
        not_usb         = "Esse número não é uma unidade USB."
        too_small       = "Unidade pequena demais: {0} GB para um ISO de {1} GB."
        confirm_erase   = "Confirmar o apagamento de '{0}'? (S/N)"
        keep_confirm    = "'{0}' já tem uma disposição compatível: só a partição FAT32 será reformatada, as outras {1} partição(ões) são mantidas. Continuar? (S/N)"
        data_warn       = "ATENÇÃO: esta unidade tem ficheiros numa partição de dados e a partição FAT32 é demasiado pequena para este ISO (são precisos {0} GB). Continuar reparticiona a unidade e APAGA esses ficheiros."
        data_ask        = "Para os apagar mesmo assim, escreve {0} (Enter para cancelar): "
        erase_word      = "APAGAR"
        data_created    = "Partição de dados exFAT 'DONNEES' criada: {0} GB para os teus ficheiros (a FAT32 mantém margem para futuras versões do Windows)."
        kept            = "Disposição mantida: só a partição FAT32 é reformatada."
        eject_ask       = "Ejetar agora a pen USB em segurança? (S/N) "
        busy_prep       = "A preparar a pen (apagar, partições, formatar)"
        busy_flush      = "Escrita final na pen, não a desligues"
        busy_eject      = "A ejetar a pen"
        eject_ok        = "Pen ejetada: já a podes desligar."
        eject_fail      = "Não foi possível ejetar (pen ainda em uso?). Fecha as janelas que a usam e ejeta-a pelo sistema antes de a desligar."
        bypass_ask      = "Ignorar as perguntas da instalação do Windows (conta local, sem conta Microsoft nem ofertas do Microsoft 365)? (S/N) "
        bypass_name     = "Nome da conta local do Windows a criar (prime Enter sem escrever nada para '{0}'): "
        bypass_done     = "Ficheiro de respostas escrito na pen: autounattend.xml (conta local '{0}'). Os ecrãs de idioma, edição e disco continuam visíveis."
        ua_pc           = "Nome do computador (escreve um nome ou prime Enter para o Windows escolher um): "
        ua_lang         = "Idioma, teclado e fuso horário: 0 = perguntar-me, 1 Français, 2 English (UK), 3 English (US), 4 Deutsch, 5 Español, 6 Italiano, 7 Português (prime o número, Enter = 0): "
        ua_edition      = "Edição: 0 = perguntar-me, 1 = Pro, 2 = Home (prime o número, Enter = 0): "
        ua_auto         = "Iniciar sessão admin automaticamente no primeiro arranque? (S/N) "
        ua_pwd          = "Palavra-passe da conta admin: "
        ua_pwd2         = "Confirma a palavra-passe: "
        ua_pwd_bad      = "Palavra-passe vazia ou diferente. Tenta novamente."
        m_pwdmode       = "Palavra-passe admin"
        m_pwd_auto      = "provisória auto, depois vazia"
        m_pwd_ask       = "escrevo-a eu"
        m_wifi          = "Ligação Wi-Fi automática"
        m_grey          = "(inútil com Wi-Fi)"
        ua_wifi_ssid    = "Nome da rede Wi-Fi (SSID): "
        ua_wifi_pwd     = "Palavra-passe do Wi-Fi (mínimo 8 caracteres): "
        ua_wifi_pwd2    = "Confirma a palavra-passe do Wi-Fi: "
        ua_wifi_bad     = "Palavra-passe Wi-Fi demasiado curta ou diferente. Tenta novamente."
        ua_wifi         = "Ligar o PC automaticamente a uma rede Wi-Fi no primeiro arranque? (S/N) "
        ua_pwdmode      = "Escrever tu a palavra-passe admin (senão provisória automática, depois vazia)? (S/N) "
        ua_clean        = "Deixa a pen ligada até aparecer o ambiente de trabalho: no primeiro arranque as palavras-passe serão apagadas da pen."
        ua_updates      = "Pausar as atualizações automáticas (menos seguro)? (S/N) "
        ua_hw           = "Ignorar as verificações de compatibilidade do Windows 11 (TPM, Secure Boot, memória, CPU)? (S/N) "
        recap_key       = "Pen de {0} GB: procura este tamanho na lista de discos do instalador do Windows."
        copying         = "Copiando arquivos..."
        robocopy_err    = "O robocopy encontrou erros (código {0}). Veja {1}"
        bootwim_missing = "sources\boot.wim ausente da unidade: cópia incompleta. Veja {0}"
        write_ok        = "Teste de gravação na unidade: OK"
        write_fail      = "Não é possível gravar em {0}: {1}"
        splitting       = "Dividindo o install.wim em {0} (~5 GB livres necessários)..."
        split_title     = "Divisão do install.wim"
        split_status    = "{0} MB / {1} MB — {2} MB/s"
        copy_title      = "Copiando arquivos para a unidade"
        copy_status     = "{0} MB — {1} MB/s"
        copying_swm     = "Copiando os fragmentos para a unidade..."
        split_done      = "Divisão concluída."
        dism_fail       = "O DISM falhou (código {0}). Últimas linhas de {1}:"
        esd_copy        = "install.esd detectado: cópia direta."
        no_image        = "Nem install.wim nem install.esd encontrados no ISO."
        copy_summary    = "Cópia concluída: {0} MB em {1} — {2} MB/s em média."
        split_summary   = "Divisão: {0} MB em {1} — {2} MB/s."
        swm_summary     = "Fragmentos gravados na unidade: {0} MB em {1} — {2} MB/s."
        total_speed     = "Total gravado na unidade: {0} GB em {1} — {2} MB/s (cache de gravação esvaziado)."
        slow_drive      = "Unidade lenta ({0} MB/s): uma unidade USB 3.x em uma porta USB 3 seria bem mais rápida."
        done            = "Concluído: a unidade está pronta em {0}"
        logs            = "Registros: {0}, {1} e {2}"
        inv_file        = "Arquivo"
        inv_mb          = "MB"
    }
}
$Lang = $env:WIN11_LANG
if (-not $Lang) { $Lang = (Get-UICulture).TwoLetterISOLanguageName }
$Lang = "$Lang".ToLower()
if ($Lang.Length -gt 2) { $Lang = $Lang.Substring(0, 2) }
if (-not $Textes.ContainsKey($Lang)) { $Lang = 'en' }

# Message traduit : T 'clé' arg1, arg2   (repli : anglais)
function T([string]$cle, [object[]]$a = @()) {
    $f = $Textes[$Lang][$cle]
    if ($null -eq $f) { $f = $Textes['en'][$cle] }
    if ($a.Count -gt 0) { return ($f -f $a) }
    return $f
}

# --- Animation (barre qui va et vient + chrono) pour les étapes silencieuses ---
if (-not ('PocketSpin' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Threading;
public static class PocketSpin {
    static Thread t; static volatile bool run;
    public static void Start(string msg) {
        Stop();
        run = true;
        t = new Thread(() => {
            var sw = Stopwatch.StartNew(); int i = 0;
            while (run) {
                try {
                    int p = i % 12; if (p > 6) p = 12 - p;
                    string bar = new string(' ', p) + "===" + new string(' ', 6 - p);
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.Write("\r  [" + bar + "] " + msg + "  " + (int)sw.Elapsed.TotalSeconds + "s   ");
                    Console.ResetColor();
                } catch { }
                i++; Thread.Sleep(120);
            }
        });
        t.IsBackground = true; t.Start();
    }
    public static void Stop() {
        if (t == null) return;
        run = false; t.Join(); t = null;
        try { Console.Write("\r" + new string(' ', Math.Max(1, Console.WindowWidth - 1)) + "\r"); } catch { }
    }
}
"@
}
function Start-Anim([string]$texte) { try { [PocketSpin]::Start($texte) } catch { Write-Host $texte -ForegroundColor Cyan } }
function Stop-Anim { try { [PocketSpin]::Stop() } catch { } }

# --- Bannière PocketBoot ---
function Show-Banniere {
    $b = 'Cyan'; $g = 'Green'
    Write-Host ''
    $l = @(
        @('  ___         _       _  ', ' ___           _    '),
        @(' | _ \___  __| |_____| |_', '| _ ) ___  ___| |_ '),
        @(' |  _/ _ \/ _| / / -_)  _', '| _ \/ _ \/ _ \  _|'),
        @(' |_| \___/\__|_\_\___|\__', '|___/\___/\___/\__|')
    )
    foreach ($x in $l) { Write-Host $x[0] -NoNewline -ForegroundColor $b; Write-Host $x[1] -ForegroundColor $g }
    Write-Host '  Windows 11 USB  -  shark-micro.fr/bootpaste  (v2026.11.21-16)' -ForegroundColor DarkGray
    Write-Host ''
}
Show-Banniere

# --- Droits administrateur ---
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host (T 'need_admin') -ForegroundColor Red; return }

# --- Paramètres et fonctions de téléchargement ---
$UrlHashes     = "https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/iso_hashes.txt"
$UrlLiens      = "https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/iso_links.txt"
$ValiditeMin   = 1800    # un lien publié doit rester valable au moins 30 minutes (secondes)
$UniteGo       = if ($Lang -eq 'fr') { 'Go' } else { 'GB' }
$SeuilLent     = 10      # Mo/s : en dessous, la clé est signalée comme lente
$Marge         = 512MB   # journaux et fichiers temporaires
$EstimationWim = 6GB     # taille estimée de install.wim, découpé en local avant la copie sur la clé

# Durée « m:ss »
function Format-Duree([double]$secondes) {
    $s = [int][math]::Round($secondes)
    return ('{0}:{1:00}' -f [math]::Floor($s / 60), ($s % 60))
}

# Vitesse en Mo/s (1 décimale)
function Get-Vitesse([int64]$octets, [double]$secondes) {
    return [math]::Round($octets / 1MB / [math]::Max(1, $secondes), 1)
}

# --- Menu à cases à cocher : flèches pour se déplacer, espace pour cocher, Entrée pour valider ---
# $lignes : tableau de @{ Type = 'c' (case) ou 's' (liste) ; Label ; Val ; Opts ; Dep } ; Dep = visible seulement si la 1re case est cochée.
# Retour : $true validé, $false annulé, $null si pas de terminal interactif.
function Show-Menu([string]$titre, [object[]]$lignes) {
    try { if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $null } } catch { return $null }
    $n = $lignes.Count; $cur = 0
    $haut = $n + 2
    for ($i = 0; $i -lt $haut; $i++) { Write-Host '' }
    $top = [Console]::CursorTop - $haut
    if ($top -lt 0) { $top = 0 }
    $larg = [Math]::Max(20, [Console]::WindowWidth - 1)
    $visible = { param($i) (-not $lignes[$i].Dep) -or ($lignes[0].Val -eq 1) }
    try { [Console]::CursorVisible = $false } catch { }
    try {
        while ($true) {
            [Console]::SetCursorPosition(0, $top)
            Write-Host (("  " + $titre).PadRight($larg).Substring(0, $larg)) -ForegroundColor Cyan
            Write-Host (("  " + (T 'menu_help')).PadRight($larg).Substring(0, $larg)) -ForegroundColor DarkGray
            for ($i = 0; $i -lt $n; $i++) {
                $l = $lignes[$i]
                if (-not (& $visible $i)) { Write-Host ''.PadRight($larg); continue }
                $gris = ($null -ne $l.Grey) -and ($lignes[$l.Grey].Val -eq 1)
                if ($gris) { $l.Val = 0; $v = '[-]'; $txt = "$($l.Label) $(T 'm_grey')" }
                elseif ($l.Type -eq 'c') { $v = $(if ($l.Val -eq 1) { '[x]' } else { '[ ]' }); $txt = $l.Label }
                else { $v = '   '; $txt = "$($l.Label) :  < $($l.Opts[$l.Val]) >" }
                $ptr = $(if ($i -eq $cur) { '>' } else { ' ' })
                $ligne = (" $ptr $v $txt").PadRight($larg).Substring(0, $larg)
                if ($i -eq $cur) { Write-Host $ligne -ForegroundColor Cyan } elseif ($gris) { Write-Host $ligne -ForegroundColor DarkGray } else { Write-Host $ligne }
            }
            $k = [Console]::ReadKey($true)
            $act = 0
            switch ($k.Key) {
                'UpArrow'    { for ($j = $cur - 1; $j -ge 0; $j--) { if (& $visible $j) { $cur = $j; break } } }
                'DownArrow'  { for ($j = $cur + 1; $j -lt $n; $j++) { if (& $visible $j) { $cur = $j; break } } }
                'RightArrow' { $act = 1 }
                'LeftArrow'  { $act = -1 }
                'Spacebar'   { $act = 1 }
                'Enter'      { return $true }
                'Escape'     { return $false }
                'Q'          { return $false }
            }
            if ($act -ne 0) {
                $l = $lignes[$cur]
                if ($l.Type -eq 'c') { if (-not (($null -ne $l.Grey) -and ($lignes[$l.Grey].Val -eq 1))) { $l.Val = 1 - $l.Val } }
                else { $nb = $l.Opts.Count; $l.Val = ($l.Val + $act + $nb) % $nb }
            }
        }
    }
    finally {
        try { [Console]::CursorVisible = $true } catch { }
        try { [Console]::SetCursorPosition(0, [Math]::Min($top + $haut, [Console]::BufferHeight - 1)) } catch { }
    }
}

# Met en pause (ou reprend) un processus externe ; renvoie $false si Windows ne le permet pas
function Set-PauseProcessus([Diagnostics.Process]$p, [bool]$pause) {
    try {
        if (-not ('PocketProc' -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class PocketProc {
    [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr h);
    [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr h);
}
"@
        }
        if ($pause) { [void][PocketProc]::NtSuspendProcess($p.Handle) } else { [void][PocketProc]::NtResumeProcess($p.Handle) }
        return $true
    }
    catch { return $false }
}

# Taille totale si le serveur accepte les requêtes par tronçons (Range), sinon 0
function Get-TailleTroncons([string]$url) {
    try {
        $h = & curl.exe -s -L -D - -o NUL --connect-timeout 20 -m 30 -r 0-0 $url 2>$null
        $texte = ($h -join "`n")
        if ($texte -match '(?im)^HTTP/\S+\s+206' -and $texte -match '(?im)^content-range:\s*bytes\s+0-0/(\d+)') { return [int64]$Matches[1] }
    }
    catch { }
    return [int64]0
}

# Téléchargement par tronçons de 32 Mio, 8 curl.exe en parallèle, écrits directement dans le fichier final.
# Reprise possible : les tronçons terminés sont listés dans "fichier.done".
function Invoke-TelechargementParallele([string]$url, [string]$dest, [int64]$total) {
    $nb = 8
    $seg = [int64](32MB)
    $nbSeg = [int][math]::Ceiling($total / $seg)
    $fichierDone = "$dest.done"
    $faits = New-Object 'System.Collections.Generic.HashSet[int]'
    if (Test-Path -LiteralPath $fichierDone) {
        foreach ($l in (Get-Content -LiteralPath $fichierDone -ErrorAction SilentlyContinue)) { if ($l -match '^\d+$') { [void]$faits.Add([int]$l) } }
    }
    elseif ((Test-Path -LiteralPath $dest) -and ((Get-Item -LiteralPath $dest).Length -ge $seg)) {
        $pleins = [int][math]::Floor((Get-Item -LiteralPath $dest).Length / $seg)
        for ($i = 0; $i -lt $pleins; $i++) { [void]$faits.Add($i); Add-Content -LiteralPath $fichierDone -Value $i }
    }
    $attente = New-Object 'System.Collections.Generic.Queue[int]'
    for ($i = 0; $i -lt $nbSeg; $i++) { if (-not $faits.Contains($i)) { $attente.Enqueue($i) } }
    $actifs = New-Object System.Collections.ArrayList
    $essais = @{}
    $fs = [IO.File]::Open($dest, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $ok = $true
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $tPrev = 0.0; $bPrev = [int64]0; $vit = 0.0; $b = [int64]0
    $script:DlPause = 0.0; $script:DlErr = ""
    try {
        if ($fs.Length -lt $total) { $fs.SetLength($total) }
        $slotLibres = New-Object System.Collections.Generic.Stack[int]
        for ($i = $nb - 1; $i -ge 0; $i--) { $slotLibres.Push($i) }
        while ($attente.Count -gt 0 -or $actifs.Count -gt 0) {
            while ($attente.Count -gt 0 -and $actifs.Count -lt $nb) {
                $k = $attente.Dequeue(); $slot = $slotLibres.Pop()
                $deb = [int64]$k * $seg; $fin = [math]::Min($deb + $seg, $total) - 1
                $tmp = "$dest.t$slot"
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                $psi = New-Object Diagnostics.ProcessStartInfo
                $psi.FileName = "curl.exe"
                $psi.Arguments = "-sSL --fail --connect-timeout 20 --speed-limit 1024 --speed-time 30 -r $deb-$fin -o `"$tmp`" `"$url`""
                $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardError = $true
                $p = [Diagnostics.Process]::Start($psi)
                [void]$actifs.Add([pscustomobject]@{ P = $p; K = $k; Slot = $slot; Tmp = $tmp; Deb = $deb; Len = ($fin - $deb + 1) })
            }
            Start-Sleep -Milliseconds 400
            $touchePause = $false
            try { while ([Console]::KeyAvailable) { if ([Console]::ReadKey($true).Key -eq 'P') { $touchePause = $true } } } catch { }
            if ($touchePause) {
                $sw.Stop(); $tPause = [Diagnostics.Stopwatch]::StartNew()
                foreach ($a in $actifs) { [void](Set-PauseProcessus $a.P $true) }
                [Console]::Write("`r  " + (T 'dl_paused').PadRight(70))
                while ($true) {
                    Start-Sleep -Milliseconds 200
                    try { if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'P') { break } } catch { break }
                }
                foreach ($a in $actifs) { [void](Set-PauseProcessus $a.P $false) }
                $tPause.Stop(); $script:DlPause += $tPause.Elapsed.TotalSeconds
                $sw.Start(); $tPrev = $sw.Elapsed.TotalSeconds; $bPrev = $b
            }
            foreach ($a in @($actifs)) {
                if (-not $a.P.HasExited) { continue }
                $bon = ($a.P.ExitCode -eq 0) -and (Test-Path -LiteralPath $a.Tmp) -and ((Get-Item -LiteralPath $a.Tmp).Length -eq $a.Len)
                [void]$actifs.Remove($a); $slotLibres.Push($a.Slot)
                if ($bon) {
                    $in = [IO.File]::OpenRead($a.Tmp)
                    try { [void]$fs.Seek($a.Deb, [IO.SeekOrigin]::Begin); $in.CopyTo($fs) } finally { $in.Dispose() }
                    $fs.Flush()
                    Remove-Item -LiteralPath $a.Tmp -Force -ErrorAction SilentlyContinue
                    [void]$faits.Add($a.K); Add-Content -LiteralPath $fichierDone -Value $a.K
                }
                else {
                    $script:DlErr = "curl code " + $a.P.ExitCode + " : " + $a.P.StandardError.ReadToEnd().Trim()
                    Remove-Item -LiteralPath $a.Tmp -Force -ErrorAction SilentlyContinue
                    $essais[$a.K] = 1 + [int]$essais[$a.K]
                    if ($essais[$a.K] -ge 8) { $ok = $false; break }
                    Start-Sleep -Seconds ([math]::Min($essais[$a.K], 5))
                    $attente.Enqueue($a.K)
                }
            }
            if (-not $ok) { break }
            $b = [int64]0
            foreach ($k in $faits) { $b += [math]::Min($seg, $total - [int64]$k * $seg) }
            foreach ($a in $actifs) { if (Test-Path -LiteralPath $a.Tmp) { $b += (Get-Item -LiteralPath $a.Tmp -ErrorAction SilentlyContinue).Length } }
            $t = $sw.Elapsed.TotalSeconds
            if ($t - $tPrev -ge 1) { $vit = [math]::Round((($b - $bPrev) / 1MB) / ($t - $tPrev), 1); $tPrev = $t; $bPrev = $b }
            $pct = [int][math]::Floor(100 * [math]::Min($b, $total) / $total)
            $ligne = "`r  {0,3} %   {1} / {2} GB   {3} MB/s   {4}   " -f $pct, [math]::Round($b / 1GB, 2), [math]::Round($total / 1GB, 2), $vit, (T 'dl_pause_hint')
            [Console]::Write($ligne)
        }
        [Console]::WriteLine()
    }
    finally {
        foreach ($a in @($actifs)) { try { if (-not $a.P.HasExited) { $a.P.Kill() } } catch { } }
        $fs.Dispose()
        Get-ChildItem -Path "$dest.t*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    if ($ok -and $faits.Count -ge $nbSeg) { Remove-Item -LiteralPath $fichierDone -Force -ErrorAction SilentlyContinue; return $true }
    return $false
}

# Espace libre (octets) du volume qui contient $chemin, $null si indéterminable
function Get-EspaceLibre([string]$chemin) {
    try { return [IO.DriveInfo]::new([IO.Path]::GetPathRoot($chemin)).AvailableFreeSpace }
    catch { return $null }
}

# N'accepte qu'une URL https d'un domaine *.microsoft.com dont le chemin se termine par .iso
function Test-UrlMicrosoft([string]$url) {
    try {
        $u = [Uri]$url
        return ($u.IsAbsoluteUri -and $u.Scheme -eq 'https' -and $u.Port -eq 443 -and
                $u.Host -like '*.microsoft.com' -and [string]::IsNullOrEmpty($u.UserInfo) -and
                $u.AbsolutePath -match '\.iso$')
    } catch { return $false }
}

# Taille (octets) annoncée par le serveur, 0 si inconnue
function Get-TailleDistante([string]$url) {
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30
        $l = $r.Headers['Content-Length']
        if ($l -is [array]) { $l = $l[0] }
        return [int64]$l
    } catch { return 0 }
}

# Langue d'affichage de Windows au format « xx-xx » minuscule
function Get-LangueSysteme {
    $l = (Get-UICulture).Name
    if (-not $l) { return "en-us" }
    $p = $l.ToLower().Split('-')
    if ($p.Count -gt 2) { return "$($p[0])-$($p[-1])" }
    if ($p.Count -eq 1) { return "$($p[0])-$($p[0])" }
    return $l.ToLower()
}

# Code HTTP renvoyé par le serveur pour l'URL (0 = pas de réponse)
function Get-CodeHttp([string]$url) {
    try { return [int](Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30).StatusCode }
    catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return 0
    }
}

# Cherche dans iso_links.txt (GitHub) un lien de la langue $loc encore valable assez longtemps.
# Format du fichier : langue;build;expiration (epoch Unix);url
function Get-LienPublie([string]$loc) {
    try {
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $contenu = (Invoke-WebRequest -Uri $UrlLiens -UseBasicParsing -TimeoutSec 15).Content
        foreach ($ligne in ($contenu -split "`n")) {
            $l = $ligne.Trim()
            if (-not $l -or $l.StartsWith('#')) { continue }
            $c = $l -split ';', 4
            if ($c.Count -lt 4) { continue }
            if ($c[0].ToLower() -eq $loc -and (([int64]$c[2]) - $now) -ge $ValiditeMin) {
                return [pscustomobject]@{ Build = $c[1]; Expire = [int64]$c[2]; Url = $c[3].Trim() }
            }
        }
    } catch { }
    return $null
}

# Méthode manuelle : ouvre la page Microsoft, explique les étapes puis attend le lien (presse-papiers ou saisie).
function Get-LienManuel([string]$page, [string]$loc) {
    Write-Host (T 'official_page' $page)
    Write-Host (T 'no_fixed_link')
    Write-Host (T 'step1')
    Write-Host (T 'step2' $loc)
    Write-Host (T 'step3')
    try { Start-Process $page } catch { Write-Host (T 'open_fail') -ForegroundColor Yellow }
    $url = ""
    $dernier = ""
    Write-Host (T 'wait_link')
    for ($i = 0; $i -lt 300 -and -not $url; $i++) {
        $c = ""
        try { $c = ((Get-Clipboard -Raw -ErrorAction Stop) -replace '[\s"]', '') } catch { }
        if ($c -and $c -ne $dernier -and (Test-UrlMicrosoft $c)) {
            $nomClip = [IO.Path]::GetFileName(([Uri]$c).AbsolutePath)
            $rep = Read-Host (T 'clip_found' $nomClip)
            if ($rep -match '^[nN]') { $dernier = $c } else { $url = $c; break }
        }
        $entree = $false
        try {
            if ([Console]::KeyAvailable) { $entree = ([Console]::ReadKey($true).Key -eq 'Enter') }
        } catch { }
        if ($entree) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $url) {
        $url = (Read-Host (T 'ask_url')).Trim().Trim('"')
    }
    return $url
}

# Copie des fichiers vers un dossier avec vitesse d'écriture en direct (écriture directe sur le média).
# Renvoie @{ Octets; Secondes }.
function Copy-AvecVitesse([IO.FileInfo[]]$fichiers, [string]$dossierDest) {
    $fait = [int64]0
    $total = ($fichiers | Measure-Object -Property Length -Sum).Sum
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $tick = [Diagnostics.Stopwatch]::StartNew()
    $dernierFait = [int64]0
    $buf = [byte[]]::new(4MB)
    foreach ($f in $fichiers) {
        $in = [IO.File]::OpenRead($f.FullName)
        $out = [IO.FileStream]::new((Join-Path $dossierDest $f.Name), [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None, 1MB, [IO.FileOptions]::WriteThrough)
        try {
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $out.Write($buf, 0, $n)
                $fait += $n
                if ($tick.ElapsedMilliseconds -ge 1000) {
                    $v = Get-Vitesse ($fait - $dernierFait) $tick.Elapsed.TotalSeconds
                    $dernierFait = $fait
                    $tick.Restart()
                    Write-Progress -Activity (T 'copying_swm') `
                        -Status (T 'copy_status' ([int]($fait / 1MB)), $v) `
                        -PercentComplete ([math]::Min(99, [int](100 * $fait / $total)))
                }
            }
            $out.Flush($true)
        }
        finally { $in.Dispose(); $out.Dispose() }
    }
    Write-Progress -Activity (T 'copying_swm') -Completed
    return @{ Octets = $fait; Secondes = $sw.Elapsed.TotalSeconds }
}

# Télécharge l'ISO dans $dossier. Renvoie $true et renseigne $script:isoTelecharge en cas de succès.
$script:DlPause = 0.0; $script:DlVit = $null
function Invoke-TelechargementMicrosoft {
    Write-Host (T 'dl_title') -ForegroundColor Cyan
    $loc = Get-LangueSysteme
    $codes = @($loc, 'fr-fr', 'en-us', 'en-gb', 'de-de', 'es-es', 'it-it', 'pt-br', 'pt-pt', (T 'm_other'))
    $ligneLang = @{ Type = 's'; Label = (T 'm_dl_lang'); Val = 0; Opts = $codes; Dep = $false }
    $mr = Show-Menu (T 'menu_dl_title') @($ligneLang)
    if ($mr -eq $false) { return }
    if ($null -eq $mr -or $ligneLang.Val -eq ($codes.Count - 1)) { $rep = (Read-Host (T 'ask_lang' $loc)).Trim().ToLower().Replace('_', '-') }
    elseif ($ligneLang.Val -eq 0) { $rep = '' }
    else { $rep = $codes[$ligneLang.Val] }
    if ($rep) {
        if ($rep -match '^[a-z]{2,3}(-[a-z0-9]{2,4}){1,2}$') { $loc = $rep }
        else { Write-Host (T 'bad_code' $loc) -ForegroundColor Yellow }
    }
    $page = "https://www.microsoft.com/$loc/software-download/windows11"
    $url = ""
    $origine = ""

    # 1. Lien déjà généré par la routine quotidienne et publié dans iso_links.txt
    $publie = Get-LienPublie $loc
    if ($publie -and (Test-UrlMicrosoft $publie.Url)) {
        $restant = $publie.Expire - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $txtRestant = '{0} h {1:00} min' -f [math]::Floor($restant / 3600), [math]::Floor(($restant % 3600) / 60)
        $rep = Read-Host (T 'published_found' $publie.Build, $txtRestant)
        if ($rep -notmatch '^[nN]') { $url = $publie.Url; $origine = 'publie' }
    }
    # 2. Sinon : méthode manuelle (page ouverte, lien copié dans le presse-papiers)
    if (-not $url) { $url = Get-LienManuel $page $loc }

    while ($true) {
        if (-not (Test-UrlMicrosoft $url)) {
            Write-Host (T 'url_refused') -ForegroundColor Red
            return $false
        }
        $nom = [IO.Path]::GetFileName(([Uri]$url).AbsolutePath) -replace '[^A-Za-z0-9._-]', ''
        if (-not $nom) { $nom = "Win11.iso" }
        $dest = Join-Path $dossier $nom
        if (Test-Path -LiteralPath $dest) {
            Write-Host (T 'file_exists' $nom, $dossier) -ForegroundColor Yellow
            $script:isoTelecharge = $dest
            return $true
        }
        Write-Host (T 'querying') -ForegroundColor Cyan
        $taille = Get-TailleDistante $url
        if ($taille -gt 0) { break }
        $code = Get-CodeHttp $url
        if ($code -ge 200 -and $code -lt 300) {
            $taille = 8GB
            Write-Host (T 'size_unknown') -ForegroundColor Yellow
            break
        }
        if ($origine) {
            Write-Host (T 'published_dead' $code) -ForegroundColor Yellow
            $origine = ""
            $url = Get-LienManuel $page $loc
            continue
        }
        Write-Host (T 'http_err' $code) -ForegroundColor Red
        return $false
    }

    # install.wim est découpé en local (swm_tmp) avant d'être copié sur la clé :
    # il faut la place de l'ISO + celle des morceaux (environ la taille de install.wim).
    $besoin = $taille + $EstimationWim + $Marge
    $libre  = Get-EspaceLibre $dossier
    Write-Host (T 'size_line' ([math]::Round($taille / 1GB, 2)))
    Write-Host (T 'split_line' ([math]::Round($EstimationWim / 1GB, 2)))
    Write-Host (T 'need_line' ([math]::Round($besoin / 1GB, 2)))
    if ($null -eq $libre) {
        Write-Host (T 'free_unknown' $dossier) -ForegroundColor Yellow
    }
    else {
        Write-Host (T 'free_line' ([math]::Round($libre / 1GB, 2)), $dossier)
        if ($libre -lt $besoin) {
            Write-Host (T 'insufficient' ([math]::Round(($besoin - $libre) / 1GB, 2))) -ForegroundColor Red
            return $false
        }
    }
    if ((Read-Host (T 'confirm_dl' $dest)) -notmatch '^[oOyYsSjJ]') { return $false }

    Write-Host (T 'dl_running') -ForegroundColor Cyan
    $part = "$dest.part"
    $ok = $false
    $swDl = [Diagnostics.Stopwatch]::StartNew()
    $ptot = Get-TailleTroncons $url
    try {
        if ($ptot -gt 64MB) {
            Write-Host (T 'dl_par' 8) -ForegroundColor Cyan
            $ok = Invoke-TelechargementParallele $url $part $ptot
            if (-not $ok) { throw "download" }
        }
        else {
            Start-BitsTransfer -Source $url -Destination $part -DisplayName "ISO Windows 11" -ErrorAction Stop
            $ok = $true
        }
    }
    catch {
        $detail = if ($script:DlErr) { $script:DlErr } else { $_.Exception.Message }
        Write-Host (T 'bits_fail' $detail) -ForegroundColor Yellow
        Remove-Item -LiteralPath "$part.done" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        $swDl.Restart()
        & curl.exe -L --fail --progress-bar -o $part $url | Out-Host
        $ok = ($LASTEXITCODE -eq 0)
    }
    if (-not $ok) {
        Write-Host (T 'dl_fail') -ForegroundColor Red
        if ((Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part).Length -eq 0)) { Remove-Item -LiteralPath $part -Force }
        return $false
    }
    $swDl.Stop()
    Move-Item -LiteralPath $part -Destination $dest -Force
    Write-Host (T 'dl_done' $dest) -ForegroundColor Green
    $script:DlVit = Get-Vitesse (Get-Item -LiteralPath $dest).Length ($swDl.Elapsed.TotalSeconds - $script:DlPause)
    Write-Host (T 'dl_speed' $script:DlVit)

    Start-Anim (T 'sha_calc')
    try { $calc = (Get-FileHash -Algorithm SHA256 -LiteralPath $dest).Hash } finally { Stop-Anim }
    $reconnu = $null
    try {
        $reconnu = ((Invoke-WebRequest -Uri $UrlHashes -UseBasicParsing -TimeoutSec 15).Content -split "`n") |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') -and ($_ -split ';').Count -ge 3 -and (($_ -split ';')[2] -eq $calc) } |
            Select-Object -First 1
    } catch { }
    if ($reconnu) {
        $c = $reconnu -split ';'
        Write-Host (T 'sha_ok' $c[0], $c[1]) -ForegroundColor Green
    }
    else {
        Write-Host (T 'sha_unknown') -ForegroundColor Yellow
        Write-Host (T 'sha_computed' $calc)
        $attendu = (Read-Host (T 'ask_sha')).Trim()
        if ($attendu) {
            if ($calc -ne ($attendu -replace '\s', '')) {
                Write-Host (T 'sha_bad') -ForegroundColor Red
                return $false
            }
            Write-Host (T 'sha_match') -ForegroundColor Green
        }
    }
    $script:isoTelecharge = $dest
    return $true
}

# --- Recherche des ISO dans le répertoire courant ---
$dossier = (Get-Location).ProviderPath
$isos = @(Get-ChildItem -LiteralPath $dossier -Filter *.iso -File -ErrorAction SilentlyContinue | Sort-Object Name)

if ($isos.Count -eq 0) {
    Write-Host (T 'no_iso' $dossier) -ForegroundColor Yellow
    $saisie = (Read-Host (T 'ask_no_iso')).Trim('"')
    if ($saisie -eq 'T') {
        if (-not (Invoke-TelechargementMicrosoft)) { return }
        $iso = $script:isoTelecharge
    }
    else { $iso = $saisie }
}
else {
    Write-Host (T 'isos_found' $dossier) -ForegroundColor Cyan
    for ($i = 0; $i -lt $isos.Count; $i++) {
        Write-Host ("  [{0}] {1}  ({2} {3})" -f ($i + 1), $isos[$i].Name, [math]::Round($isos[$i].Length / 1GB, 2), $UniteGo)
    }
    Write-Host (T 'menu_download')
    $saisie = Read-Host (T 'ask_iso')
    if ($saisie -eq 'T') {
        if (-not (Invoke-TelechargementMicrosoft)) { return }
        $iso = $script:isoTelecharge
    }
    else {
        $choix = 0
        if (-not [int]::TryParse($saisie, [ref]$choix) -or $choix -lt 1 -or $choix -gt $isos.Count) {
            Write-Host (T 'bad_choice') -ForegroundColor Red
            return
        }
        $iso = $isos[$choix - 1].FullName
    }
    Write-Host (T 'iso_selected' $iso) -ForegroundColor Green
}
if (-not (Test-Path -LiteralPath $iso)) { Write-Host (T 'iso_missing') -ForegroundColor Red; return }

# --- Contrôle de l'espace disque pour le découpage local de install.wim ---
Mount-DiskImage -ImagePath $iso | Out-Null
$lettre = (Get-DiskImage -ImagePath $iso | Get-Volume).DriveLetter
$wimTest = $null
if ($lettre) { $wimTest = Get-Item -LiteralPath "${lettre}:\sources\install.wim" -ErrorAction SilentlyContinue }
Dismount-DiskImage -ImagePath $iso | Out-Null
if ($wimTest) {
    $libre  = Get-EspaceLibre $dossier
    $besoin = $wimTest.Length + $Marge
    if ($null -ne $libre -and $libre -lt $besoin) {
        Write-Host (T 'disk_short' $dossier, ([math]::Round($besoin / 1GB, 2)), ([math]::Round($libre / 1GB, 2))) -ForegroundColor Red
        return
    }
}

# --- Choix de la clé USB ---
$usbDisks = Get-Disk | Where-Object BusType -eq 'USB'
if (-not $usbDisks) { Write-Host (T 'no_usb') -ForegroundColor Red; return }
$usbDisks | Format-Table Number, FriendlyName, @{n=$UniteGo;e={[math]::Round($_.Size/1GB,1)}} -AutoSize
$n = [int](Read-Host (T 'ask_usb'))
$disk = $usbDisks | Where-Object Number -eq $n
if (-not $disk) { Write-Host (T 'not_usb') -ForegroundColor Red; return }
$isoTaille = (Get-Item -LiteralPath $iso).Length
if ($disk.Size -lt $isoTaille) {
    Write-Host (T 'too_small' ([math]::Round($disk.Size / 1GB, 2)), ([math]::Round($isoTaille / 1GB, 2))) -ForegroundColor Red
    return
}

# --- Disposition existante : on ne repartitionne pas une clé déjà compatible, et on protège les fichiers de la partition de données ---
$besoinBoot = $isoTaille + 512MB
$parts = @(Get-Partition -DiskNumber $n -ErrorAction SilentlyContinue | Where-Object { $_.Type -ne 'Reserved' -and $_.Size -gt 0 } | Sort-Object Offset)
$p1 = $null; $garde = $false; $risque = $false; $nbAutres = 0
if ($parts.Count -gt 0) {
    $p1 = $parts[0]
    $v1 = $p1 | Get-Volume -ErrorAction SilentlyContinue
    if ($v1 -and $v1.FileSystem -eq 'FAT32' -and $p1.Size -ge $besoinBoot -and $p1.Size -le 32GB) { $garde = $true }
    foreach ($q in ($parts | Select-Object -Skip 1)) {
        $nbAutres++
        $v = $q | Get-Volume -ErrorAction SilentlyContinue
        if (-not $v -or -not $v.FileSystem) { continue }
        if ($v.DriveLetter) {
            $fichiers = @(Get-ChildItem -LiteralPath ("{0}:\" -f $v.DriveLetter) -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'System Volume Information' -and $_.Name -ne '$RECYCLE.BIN' })
            if ($fichiers.Count -gt 0) { $risque = $true }
        } else { $risque = $true }   # pas de lettre : impossible de vérifier, on protège par précaution
    }
}
if ($garde) {
    if ((Read-Host (T 'keep_confirm' $disk.FriendlyName, $nbAutres)) -notmatch '^[oOyYsSjJ]') { return }
}
else {
    if ($risque) {
        Write-Host (T 'data_warn' ([math]::Round($besoinBoot / 1GB, 1))) -ForegroundColor Red
        $mot = T 'erase_word'
        if ((Read-Host (T 'data_ask' $mot)).Trim() -ne $mot) { return }
    }
    elseif ((Read-Host (T 'confirm_erase' $disk.FriendlyName)) -notmatch '^[oOyYsSjJ]') { return }
}

# --- Installation automatisée : questions de la première configuration de Windows ---
$bypass = $false; $nomCompte = ''; $nomPc = ''; $iLoc = 0; $iEd = 0; $uaAuto = $false; $mdp = ''; $pwdAsk = $false; $wifi = $false; $wifiSsid = ''; $wifiPwd = ''; $uaUpd = $false; $uaHw = $false
function Touche([string]$cle) {
    Write-Host (T $cle) -NoNewline
    try { $c = [Console]::ReadKey($true).KeyChar } catch { return (Read-Host '') }
    if ([char]::IsControl($c)) { Write-Host '' } else { Write-Host $c }
    return [string]$c
}
function Oui([string]$cle) { return ((Touche $cle) -match '^[oOyYsSjJ]') }
function Choix([string]$cle, [int]$max) { $n = 0; if ([int]::TryParse((Touche $cle), [ref]$n) -and $n -ge 0 -and $n -le $max) { return $n }; return 0 }
function Get-ModelePremiereSession {
    return @'
# PocketBoot : premiere ouverture de session (Wi-Fi, mot de passe provisoire, nettoyage)
$ErrorActionPreference = 'SilentlyContinue'
$dir = 'C:\PocketBoot'
$nom = '__NAME__'
$vider = __RESET__
$wifi = Join-Path $dir 'wifi.xml'
function Effacer([string]$f) {
    try {
        $len = (Get-Item -LiteralPath $f -Force).Length
        if ($len -gt 0) {
            $fs = [IO.File]::Open($f, 'Open', 'Write')
            $fs.Write((New-Object byte[] $len), 0, $len); $fs.Flush(); $fs.Dispose()
        }
    } catch { }
    Remove-Item -LiteralPath $f -Force
}
if (Test-Path -LiteralPath $wifi) {
    netsh wlan add profile filename="$wifi" user=all | Out-Null
    $ssid = ([xml](Get-Content -LiteralPath $wifi -Raw)).WLANProfile.name
    for ($i = 0; $i -lt 20; $i++) {
        netsh wlan connect name="$ssid" | Out-Null
        Start-Sleep -Seconds 4
        if (Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet) { break }
    }
}
if ($vider) { cmd.exe /c "net user ""$nom"" """"" | Out-Null }
foreach ($d in (Get-PSDrive -PSProvider FileSystem)) {
    $r = $d.Root
    if ($r -eq ($env:SystemDrive + '\')) { continue }
    $a = Join-Path $r 'autounattend.xml'
    if ((Test-Path -LiteralPath $a) -and (Select-String -LiteralPath $a -Pattern 'PocketBoot' -Quiet)) {
        Effacer $a
        $o = Join-Path $r 'sources\$OEM$'
        if (Test-Path -LiteralPath $o) {
            Get-ChildItem -LiteralPath $o -Recurse -File -Force | ForEach-Object { Effacer $_.FullName }
            Remove-Item -LiteralPath $o -Recurse -Force
        }
    }
}
foreach ($f in 'unattend.xml', 'autounattend.xml') {
    $p = Join-Path 'C:\Windows\Panther' $f
    if (Test-Path -LiteralPath $p) { Effacer $p }
}
Get-ChildItem -LiteralPath 'C:\Windows\Panther\UnattendGC' -File -Force | ForEach-Object { Effacer $_.FullName }
Get-ChildItem -LiteralPath $dir -File -Force | Where-Object { $_.FullName -ne $PSCommandPath } | ForEach-Object { Effacer $_.FullName }
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', "Start-Sleep 3; Remove-Item -LiteralPath '$dir' -Recurse -Force"
'@
}

function Lire-MotDePasse {
    while ($true) {
        $a = Read-Host (T 'ua_pwd') -AsSecureString
        $b = Read-Host (T 'ua_pwd2') -AsSecureString
        $p1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a))
        $p2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($b))
        if ($p1 -and ($p1 -ceq $p2)) { return $p1 }
        Write-Host (T 'ua_pwd_bad') -ForegroundColor Red
    }
}
$lOpt = @(
    @{ Type = 'c'; Label = (T 'm_bypass'); Val = 0; Opts = @(); Dep = $false },
    @{ Type = 's'; Label = (T 'm_lang'); Val = 0; Opts = @('Français', 'English (UK)', 'English (US)', 'Deutsch', 'Español', 'Italiano', 'Português', (T 'm_ask')); Dep = $true },
    @{ Type = 's'; Label = (T 'm_ed'); Val = 0; Opts = @('Pro', (T 'm_home'), (T 'm_ask')); Dep = $true },
    @{ Type = 'c'; Label = (T 'm_auto'); Val = 0; Opts = @(); Dep = $true },
    @{ Type = 's'; Label = (T 'm_pwdmode'); Val = 0; Opts = @((T 'm_pwd_auto'), (T 'm_pwd_ask')); Dep = $true },
    @{ Type = 'c'; Label = (T 'm_wifi'); Val = 0; Opts = @(); Dep = $true },
    @{ Type = 'c'; Label = (T 'm_upd'); Val = 0; Opts = @(); Dep = $true; Grey = 5 },
    @{ Type = 'c'; Label = (T 'm_hw'); Val = 0; Opts = @(); Dep = $true }
)
$menuOpt = Show-Menu (T 'menu_opts_title') $lOpt
if ($null -eq $menuOpt) { $bypass = Oui 'bypass_ask' }
elseif ($menuOpt -and $lOpt[0].Val -eq 1) {
    $bypass = $true; $iLoc = ($lOpt[1].Val + 1) % 8; $iEd = ($lOpt[2].Val + 1) % 3
    $uaAuto = ($lOpt[3].Val -eq 1); $pwdAsk = ($lOpt[4].Val -eq 1); $wifi = ($lOpt[5].Val -eq 1); $uaUpd = (($lOpt[6].Val -eq 1) -and -not $wifi); $uaHw = ($lOpt[7].Val -eq 1)
}
if ($bypass) {
    Write-Host (T 'ua_note') -ForegroundColor Yellow
    $saisie = Read-Host (T 'bypass_name' 'Utilisateur')
    $nomCompte = ([regex]::Replace([string]$saisie, '[\x00-\x1f"/\\\[\]:;|=,+*?<>@%&'']', '')).Trim().TrimEnd('.').Trim()
    if ($nomCompte.Length -gt 20) { $nomCompte = $nomCompte.Substring(0, 20).Trim() }
    if (-not $nomCompte) { $nomCompte = 'Utilisateur' }
    $nomPc = ((Read-Host (T 'ua_pc')) -replace '[ _]', '-') -replace '[^A-Za-z0-9-]', ''
    $nomPc = $nomPc.Trim('-'); if ($nomPc.Length -gt 15) { $nomPc = $nomPc.Substring(0, 15).Trim('-') }
    if ($nomPc -match '^[0-9]*$') { $nomPc = '' }
    if ($null -eq $menuOpt) {
        $iLoc = Choix 'ua_lang' 7
        $iEd = Choix 'ua_edition' 2
        $uaAuto = Oui 'ua_auto'
        if ($uaAuto) { $pwdAsk = Oui 'ua_pwdmode' }
        $wifi = Oui 'ua_wifi'
        if (-not $wifi) { $uaUpd = Oui 'ua_updates' }
        $uaHw = Oui 'ua_hw'
    }
    if ($uaAuto) {
        if ($pwdAsk) { $mdp = Lire-MotDePasse }
        else {
            $oct = New-Object byte[] 24
            [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($oct)
            $mdp = -join ($oct | ForEach-Object { 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[$_ % 62] })
        }
    }
    if ($wifi) {
        while ($true) {
            $wifiSsid = (Read-Host (T 'ua_wifi_ssid')).Trim()
            if (-not $wifiSsid) { continue }
            $a1 = Read-Host (T 'ua_wifi_pwd') -AsSecureString
            $a2 = Read-Host (T 'ua_wifi_pwd2') -AsSecureString
            $w1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a1))
            $w2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a2))
            if ($w1.Length -ge 8 -and ($w1 -ceq $w2)) { $wifiPwd = $w1; break }
            Write-Host (T 'ua_wifi_bad') -ForegroundColor Red
        }
    }
    if ($uaAuto -or $wifi) { Write-Host (T 'ua_clean') -ForegroundColor Yellow }
}

# --- Préparation de la clé ---
Start-Anim (T 'busy_prep')
try {
if ($garde) {
    Stop-Anim; Write-Host (T 'kept') -ForegroundColor Green; Start-Anim (T 'busy_prep')
    Format-Volume -Partition $p1 -FileSystem FAT32 -NewFileSystemLabel "WIN11" -Force | Out-Null
    if (-not (Get-Partition -DiskNumber $n -PartitionNumber $p1.PartitionNumber).DriveLetter) {
        Add-PartitionAccessPath -DiskNumber $n -PartitionNumber $p1.PartitionNumber -AssignDriveLetter
    }
    $part = Get-Partition -DiskNumber $n -PartitionNumber $p1.PartitionNumber
}
else {
    Clear-Disk -Number $n -RemoveData -RemoveOEM -Confirm:$false
    Initialize-Disk -Number $n -PartitionStyle GPT
    # FAT32 : ISO + 2 Go de marge (une future version de Windows plus grosse tiendra encore), 32 Go maximum ; le reste en exFAT pour les données
    $fatTaille = [math]::Min([int64]32GB, [int64]([math]::Ceiling(($isoTaille + 2GB) / 1GB) * 1GB))
    $libreDispo = (Get-Disk -Number $n).LargestFreeExtent
    if (($libreDispo - $fatTaille) -ge 3GB) {
        $part = New-Partition -DiskNumber $n -Size $fatTaille -AssignDriveLetter
        Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel "WIN11" -Force | Out-Null
        $pd = New-Partition -DiskNumber $n -UseMaximumSize -AssignDriveLetter
        Format-Volume -Partition $pd -FileSystem exFAT -NewFileSystemLabel "DONNEES" -Force | Out-Null
        Stop-Anim; Write-Host (T 'data_created' ([math]::Round($pd.Size / 1GB, 1))) -ForegroundColor Green
    }
    else {
        $taille = [math]::Min([int64]32GB, $libreDispo)
        $part = New-Partition -DiskNumber $n -Size $taille -AssignDriveLetter
        Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel "WIN11" -Force | Out-Null
    }
}
} finally { Stop-Anim }
$usb = ($part | Get-Volume).DriveLetter + ":"

# --- Montage de l'ISO ---
Mount-DiskImage -ImagePath $iso | Out-Null
$src = (Get-DiskImage -ImagePath $iso | Get-Volume).DriveLetter + ":"

try {
    # --- Copie (tout sauf install.wim et autorun.inf), liste affichée + journal, vitesse en direct ---
    Write-Host (T 'copying') -ForegroundColor Cyan
    $log = "$dossier\copie_cle.log"
    $libreAvant = [IO.DriveInfo]::new($usb).AvailableFreeSpace
    $swTotal = [Diagnostics.Stopwatch]::StartNew()
    $swCopie = [Diagnostics.Stopwatch]::StartNew()
    $rcArgs = "${src}\ ${usb}\ /E /XF install.wim autorun.inf /R:2 /W:2 /NJH /NJS /NP /TEE /LOG:`"$log`""
    $rc = Start-Process robocopy -ArgumentList $rcArgs -NoNewWindow -PassThru
    $null = $rc.Handle   # nécessaire pour récupérer ExitCode
    $dernierEcrit = [int64]0
    $dernierT = 0.0
    while (-not $rc.HasExited) {
        $ecrit = $libreAvant - [IO.DriveInfo]::new($usb).AvailableFreeSpace
        $t = $swCopie.Elapsed.TotalSeconds
        $v = Get-Vitesse ($ecrit - $dernierEcrit) ([math]::Max(1, $t - $dernierT))
        $dernierEcrit = $ecrit; $dernierT = $t
        Write-Progress -Activity (T 'copy_title') -Status (T 'copy_status' ([int]($ecrit / 1MB)), $v)
        Start-Sleep -Seconds 2
    }
    Write-Progress -Activity (T 'copy_title') -Completed
    $octetsCopie = $libreAvant - [IO.DriveInfo]::new($usb).AvailableFreeSpace
    Write-Host (T 'copy_summary' ([int]($octetsCopie / 1MB)), (Format-Duree $swCopie.Elapsed.TotalSeconds), (Get-Vitesse $octetsCopie $swCopie.Elapsed.TotalSeconds)) -ForegroundColor Green
    if ($rc.ExitCode -ge 8) {
        Write-Host (T 'robocopy_err' $rc.ExitCode, $log) -ForegroundColor Red
        return
    }
    if (-not (Test-Path "$usb\sources\boot.wim")) {
        Write-Host (T 'bootwim_missing' $log) -ForegroundColor Red
        return
    }

    # --- Fichier de réponses automatiques (racine de la clé) ---
    if ($bypass) {
        $ns = 'processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
        function RegLigne([int]$o, [string]$k, [string]$v) { "        <RunSynchronousCommand wcm:action=`"add`"><Order>$o</Order><Path>reg.exe add `"$k`" /v $v /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>" }
        $langues = @(
            @('fr-FR', '040c:0000040c', 'Romance Standard Time'), @('en-GB', '0809:00000809', 'GMT Standard Time'),
            @('en-US', '0409:00000409', ''), @('de-DE', '0407:00000407', 'W. Europe Standard Time'),
            @('es-ES', '0c0a:0000040a', 'Romance Standard Time'), @('it-IT', '0410:00000410', 'W. Europe Standard Time'),
            @('pt-PT', '0816:00000816', 'GMT Standard Time'))
        $loc = $null; if ($iLoc -ge 1) { $loc = $langues[$iLoc - 1] }
        $cle = ''; if ($iEd -eq 1) { $cle = 'W269N-WFGWX-YVC9B-4J6C9-T83GX' } elseif ($iEd -eq 2) { $cle = 'TX9XD-98N7V-6WMQ6-BX7FG-H8Q99' }
        $x = New-Object System.Collections.Generic.List[string]
        $x.Add('<?xml version="1.0" encoding="utf-8"?>'); $x.Add('<unattend xmlns="urn:schemas-microsoft-com:unattend">')
        if ($loc -or $cle -or $uaHw) {
            $x.Add('  <settings pass="windowsPE">')
            if ($loc) {
                $x.Add("    <component name=`"Microsoft-Windows-International-Core-WinPE`" $ns>")
                $x.Add("      <SetupUILanguage><UILanguage>$($loc[0])</UILanguage></SetupUILanguage>"); $x.Add("      <InputLocale>$($loc[1])</InputLocale>")
                $x.Add("      <SystemLocale>$($loc[0])</SystemLocale>"); $x.Add("      <UILanguage>$($loc[0])</UILanguage>"); $x.Add("      <UserLocale>$($loc[0])</UserLocale>")
                $x.Add('    </component>')
            }
            if ($cle -or $uaHw) {
                $x.Add("    <component name=`"Microsoft-Windows-Setup`" $ns>")
                if ($uaHw) {
                    $x.Add('      <RunSynchronous>'); $i = 1
                    foreach ($v in 'BypassTPMCheck', 'BypassSecureBootCheck', 'BypassRAMCheck', 'BypassCPUCheck') { $x.Add((RegLigne $i 'HKLM\SYSTEM\Setup\LabConfig' $v)); $i++ }
                    $x.Add('      </RunSynchronous>')
                }
                if ($cle) { $x.Add("      <UserData><AcceptEula>true</AcceptEula><ProductKey><Key>$cle</Key><WillShowUI>OnError</WillShowUI></ProductKey></UserData>") }
                $x.Add('    </component>')
            }
            $x.Add('  </settings>')
        }
        $x.Add('  <settings pass="specialize">'); $x.Add("    <component name=`"Microsoft-Windows-Deployment`" $ns>"); $x.Add('      <RunSynchronous>')
        $pol = 'HKLM\SOFTWARE\Policies\Microsoft\Windows'
        $regs = @(@('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE', 'BypassNRO'), @("$pol\CloudContent", 'DisableWindowsConsumerFeatures'), @("$pol\CloudContent", 'DisableSoftLanding'), @("$pol\OOBE", 'DisablePrivacyExperience'), @('HKLM\SOFTWARE\Policies\Microsoft\Edge', 'HideFirstRunExperience'))
        if ($uaUpd) { $regs += , @("$pol\WindowsUpdate\AU", 'NoAutoUpdate'); $regs += , @("$pol\WindowsUpdate", 'ExcludeWUDriversInQualityUpdate') }
        $i = 1; foreach ($r in $regs) { $x.Add((RegLigne $i $r[0] $r[1])); $i++ }
        $x.Add('      </RunSynchronous>'); $x.Add('    </component>')
        if ($nomPc -or ($loc -and $loc[2])) {
            $x.Add("    <component name=`"Microsoft-Windows-Shell-Setup`" $ns>")
            if ($nomPc) { $x.Add("      <ComputerName>$nomPc</ComputerName>") }
            if ($loc -and $loc[2]) { $x.Add("      <TimeZone>$($loc[2])</TimeZone>") }
            $x.Add('    </component>')
        }
        $x.Add('  </settings>'); $x.Add('  <settings pass="oobeSystem">')
        if ($loc) {
            $x.Add("    <component name=`"Microsoft-Windows-International-Core`" $ns>")
            $x.Add("      <InputLocale>$($loc[1])</InputLocale>"); $x.Add("      <SystemLocale>$($loc[0])</SystemLocale>"); $x.Add("      <UILanguage>$($loc[0])</UILanguage>"); $x.Add("      <UserLocale>$($loc[0])</UserLocale>")
            $x.Add('    </component>')
        }
        $x.Add("    <component name=`"Microsoft-Windows-Shell-Setup`" $ns>")
        $x.Add('      <OOBE><HideEULAPage>true</HideEULAPage><HideOEMRegistrationScreen>true</HideOEMRegistrationScreen><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE><ProtectYourPC>3</ProtectYourPC></OOBE>')
        $x.Add('      <UserAccounts><LocalAccounts><LocalAccount wcm:action="add">')
        $mdpXml = [Security.SecurityElement]::Escape($mdp)
        $pwXml = if ($uaAuto -and $mdp) { "<Password><Value>$mdpXml</Value><PlainText>true</PlainText></Password>" } else { '' }
        $x.Add("        $pwXml<Name>$nomCompte</Name><DisplayName>$nomCompte</DisplayName><Group>Administrators</Group>")
        $x.Add('      </LocalAccount></LocalAccounts></UserAccounts>')
        if ($uaAuto) { $x.Add("      <AutoLogon><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>$nomCompte</Username>$pwXml</AutoLogon>") }
        if ($uaAuto -or $wifi) {
            $x.Add('      <FirstLogonCommands><SynchronousCommand wcm:action="add"><Order>1</Order><CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\PocketBoot\firstlogon.ps1</CommandLine><Description>PocketBoot</Description></SynchronousCommand></FirstLogonCommands>')
        }
        $x.Add('    </component>')
        $x.Add('  </settings>'); $x.Add('  <!-- PocketBoot -->'); $x.Add('</unattend>')
        [IO.File]::WriteAllText("$usb\autounattend.xml", ($x -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding $false))
        if ($uaAuto -or $wifi) {
            $oem = Join-Path $usb 'sources\$OEM$\$1\PocketBoot'
            New-Item -ItemType Directory -Path $oem -Force | Out-Null
            $vider = if ($uaAuto -and -not $pwdAsk) { '$true' } else { '$false' }
            $modele = (Get-ModelePremiereSession).Replace('__NAME__', $nomCompte).Replace('__RESET__', $vider)
            [IO.File]::WriteAllText((Join-Path $oem 'firstlogon.ps1'), $modele, (New-Object Text.UTF8Encoding $true))
            if ($wifi) {
                $ws = [Security.SecurityElement]::Escape($wifiSsid); $wk = [Security.SecurityElement]::Escape($wifiPwd)
                $wx = '<?xml version="1.0"?><WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1"><name>' + $ws + '</name><SSIDConfig><SSID><name>' + $ws + '</name></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>auto</connectionMode><MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption><sharedKey><keyType>passphrase</keyType><protected>false</protected><keyMaterial>' + $wk + '</keyMaterial></sharedKey></security></MSM></WLANProfile>'
                [IO.File]::WriteAllText((Join-Path $oem 'wifi.xml'), $wx, (New-Object Text.UTF8Encoding $false))
            }
        }
        Write-Host (T 'bypass_done' $nomCompte) -ForegroundColor Green
    }

    # --- Image d'installation ---
    $wim = "$src\sources\install.wim"
    $esd = "$src\sources\install.esd"
    $dst = "$usb\sources"

    if (Test-Path $wim) {

        # 1. Vérifier qu'on peut écrire sur la clé
        if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
        try {
            [IO.File]::WriteAllText("$dst\test.tmp", "ok"); Remove-Item "$dst\test.tmp" -Force
            Write-Host (T 'write_ok') -ForegroundColor Green
        } catch {
            Write-Host (T 'write_fail' $dst, $_.Exception.Message) -ForegroundColor Red
            return
        }

        # 2. Découpage sur le disque local avec barre de progression, puis copie vers la clé
        $tmpSwm = "$dossier\swm_tmp"
        $dlog   = "$dossier\dism_split.log"
        New-Item -ItemType Directory -Path $tmpSwm -Force | Out-Null
        Remove-Item "$tmpSwm\*" -Force -ErrorAction SilentlyContinue

        $total    = (Get-Item $wim).Length
        $dismArgs = "/Split-Image /ImageFile:`"$wim`" /SWMFile:`"$tmpSwm\install.swm`" /FileSize:3800"
        Write-Host (T 'splitting' $tmpSwm) -ForegroundColor Cyan
        $swSplit = [Diagnostics.Stopwatch]::StartNew()
        $p = Start-Process dism.exe -ArgumentList $dismArgs -NoNewWindow -PassThru -RedirectStandardOutput $dlog
        $null = $p.Handle   # nécessaire pour récupérer ExitCode

        while (-not $p.HasExited) {
            $done = (Get-ChildItem $tmpSwm -Filter install*.swm -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum).Sum
            $pct = [math]::Min(99, [int](100 * $done / $total))
            Write-Progress -Activity (T 'split_title') `
                -Status (T 'split_status' ([int]($done/1MB)), ([int]($total/1MB)), (Get-Vitesse $done $swSplit.Elapsed.TotalSeconds)) `
                -PercentComplete $pct
            Start-Sleep -Milliseconds 500
        }
        Write-Progress -Activity (T 'split_title') -Completed
        $swSplit.Stop()

        if ($p.ExitCode -eq 0) {
            Write-Host (T 'split_summary' ([int]($total / 1MB)), (Format-Duree $swSplit.Elapsed.TotalSeconds), (Get-Vitesse $total $swSplit.Elapsed.TotalSeconds))
            Write-Host (T 'copying_swm') -ForegroundColor Cyan
            $morceaux = @(Get-ChildItem $tmpSwm -Filter install*.swm | Sort-Object Name)
            $r = Copy-AvecVitesse $morceaux "$dst"
            Write-Host (T 'swm_summary' ([int]($r.Octets / 1MB)), (Format-Duree $r.Secondes), (Get-Vitesse $r.Octets $r.Secondes))
            Remove-Item $tmpSwm -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host (T 'split_done') -ForegroundColor Green
        } else {
            Write-Host (T 'dism_fail' $p.ExitCode, $dlog) -ForegroundColor Red
            Get-Content $dlog -Tail 15
            return
        }
    }
    elseif (Test-Path $esd) {
        Write-Host (T 'esd_copy') -ForegroundColor Yellow
        Copy-Item $esd "$dst\" -Force
    }
    else {
        Write-Host (T 'no_image') -ForegroundColor Red
        return
    }

    # --- Vitesse d'écriture réelle : on vide le cache d'écriture de la clé, puis on mesure ---
    Start-Anim (T 'busy_flush')
    try { Write-VolumeCache -DriveLetter $usb.TrimEnd(':') -ErrorAction Stop } catch { }
    Stop-Anim
    $swTotal.Stop()
    $ecritTotal = $libreAvant - [IO.DriveInfo]::new($usb).AvailableFreeSpace
    $vTotal = Get-Vitesse $ecritTotal $swTotal.Elapsed.TotalSeconds
    Write-Host (T 'total_speed' ([math]::Round($ecritTotal / 1GB, 2)), (Format-Duree $swTotal.Elapsed.TotalSeconds), $vTotal) -ForegroundColor Green
    if ($vTotal -lt $SeuilLent) { Write-Host (T 'slow_drive' $vTotal) -ForegroundColor Yellow }
    if ($null -ne $script:DlVit) { Write-Host (T 'recap_speed' $script:DlVit, $vTotal) -ForegroundColor Green }

    # --- Inventaire de la clé ---
    Get-ChildItem "$usb\" -Recurse -File |
        Select-Object @{n=(T 'inv_file');e={$_.FullName.Substring($usb.Length)}}, @{n=(T 'inv_mb');e={[math]::Round($_.Length/1MB,1)}} |
        Out-File "$dossier\contenu_cle.txt"

    Write-Host (T 'done' $usb) -ForegroundColor Green
    Write-Host (T 'logs' $log, $dlog, "$dossier\contenu_cle.txt")
}
finally {
    Dismount-DiskImage -ImagePath $iso | Out-Null
}

Write-Host (T 'recap_key' ([math]::Round($disk.Size / 1GB, 1))) -ForegroundColor Cyan

# --- Éjection propre de la clé ---
if ((Read-Host (T 'eject_ask')) -match '^[oOyYsSjJ]') {
    $ejecte = $false
    Start-Anim (T 'busy_eject')
    try {
        Set-Location $env:SystemRoot
        $sh = New-Object -ComObject Shell.Application
        $sh.Namespace(17).ParseName($usb).InvokeVerb('Eject')
        Start-Sleep -Seconds 3
        $ejecte = -not (Test-Path -LiteralPath "$usb\")
    } catch { }
    if (-not $ejecte) {
        try { Set-Disk -Number $n -IsOffline $true -ErrorAction Stop; $ejecte = $true } catch { }
    }
    Stop-Anim
    if ($ejecte) { Write-Host (T 'eject_ok') -ForegroundColor Green }
    else { Write-Host (T 'eject_fail') -ForegroundColor Yellow }
}

Show-Banniere
