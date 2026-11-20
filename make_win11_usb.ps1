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
        eject_ok        = "Clé éjectée : tu peux la débrancher."
        eject_fail      = "Éjection impossible (clé encore utilisée ?). Ferme les fenêtres qui l'utilisent puis éjecte-la depuis le système avant de la débrancher."
        bypass_ask      = "Ignorer les questions de l'installation de Windows (compte local, sans compte Microsoft ni offres Microsoft 365) ? (O/N) "
        bypass_name     = "Nom du compte local Windows [{0}] : "
        bypass_done     = "Réponses automatiques écrites sur la clé : autounattend.xml (compte local « {0} »). Les écrans langue, édition et disque restent affichés."
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
        eject_ok        = "Drive ejected: you can unplug it."
        eject_fail      = "Could not eject (drive still in use?). Close any window using it, then eject it from the system before unplugging."
        bypass_ask      = "Skip the Windows setup questions (local account, no Microsoft account or Microsoft 365 offers)? (Y/N) "
        bypass_name     = "Windows local account name [{0}]: "
        bypass_done     = "Answer file written to the drive: autounattend.xml (local account '{0}'). The language, edition and disk screens are still shown."
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
        eject_ok        = "Unidad expulsada: ya puedes desconectarla."
        eject_fail      = "No se pudo expulsar (¿unidad en uso?). Cierra las ventanas que la usen y exprúlsala desde el sistema antes de desconectarla."
        bypass_ask      = "¿Omitir las preguntas de la instalación de Windows (cuenta local, sin cuenta Microsoft ni ofertas de Microsoft 365)? (S/N) "
        bypass_name     = "Nombre de la cuenta local de Windows [{0}]: "
        bypass_done     = "Archivo de respuestas escrito en la unidad: autounattend.xml (cuenta local '{0}'). Las pantallas de idioma, edición y disco siguen apareciendo."
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
        step2           = "  2. Wähle unter „Windows 11-Datenträgerabbild (ISO) für x64-Geräte herunterladen“ die ISO mit`n     mehreren Editionen, dann die Produktsprache (deine Systemsprache: {0}) und klicke auf „Bestätigen“."
        step3           = "  3. Rechtsklick auf die 64-Bit-Download-Schaltfläche > „Link-Adresse kopieren“: Das Skript erkennt ihn selbst.`n     Füge den GANZEN Link ein, einschließlich dessen, was nach „.iso?“ folgt: Dieser Teil autorisiert ihn."
        open_fail       = "Browser konnte nicht geöffnet werden: Seite von Hand öffnen."
        wait_link       = "Warte auf den Link: Klicke im Browser auf „Link-Adresse kopieren“.`n(Eingabe = Link von Hand einfügen)"
        clip_found      = "Link in der Zwischenablage erkannt: {0}. Verwenden? (J/n)"
        ask_url         = "Link-URL hier einfügen (https://...microsoft.com/....iso)"
        url_refused     = "URL abgelehnt: Sie muss https verwenden, zu einer *.microsoft.com-Domain gehören und der Pfad muss auf .iso enden."
        file_exists     = "{0} existiert bereits in {1}: vorhandene Datei wird verwendet."
        querying        = "Microsoft-Server wird abgefragt..."
        http_err        = "Der Microsoft-Server antwortete mit HTTP {0} (0 = keine Antwort): Link abgelaufen, unvollständig (Teil nach „.iso?“ fehlt) oder Netzwerk nicht erreichbar.`nErzeuge einen neuen Link auf der offiziellen Seite."
        size_unknown    = "ISO-Größe nicht mitgeteilt: Annahme von 8 GB."
        size_line       = "  ISO-Größe                             : {0} GB"
        split_line      = "  Lokale Aufteilung von install.wim (gesch.) : {0} GB"
        need_line       = "  Benötigter Platz (mit Reserve)        : {0} GB"
        free_unknown    = "  Freier Platz: für {0} nicht ermittelbar, Prüfung übersprungen."
        free_line       = "  Freier Platz                          : {0} GB ({1})"
        insufficient    = "Nicht genug Speicherplatz: {0} GB fehlen."
        confirm_dl      = "Download nach {0} starten? (J/N)"
        dl_running      = "Download läuft..."
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
        eject_ok        = "Laufwerk ausgeworfen: Du kannst es abziehen."
        eject_fail      = "Auswerfen nicht möglich (Laufwerk noch in Benutzung?). Schließe Fenster, die es nutzen, und wirf es im System aus, bevor du es abziehst."
        bypass_ask      = "Fragen der Windows-Einrichtung überspringen (lokales Konto, ohne Microsoft-Konto und Microsoft-365-Angebote)? (J/N) "
        bypass_name     = "Name des lokalen Windows-Kontos [{0}]: "
        bypass_done     = "Antwortdatei auf den Stick geschrieben: autounattend.xml (lokales Konto '{0}'). Sprach-, Editions- und Datenträgerauswahl bleiben sichtbar."
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
        eject_ok        = "Chiavetta espulsa: puoi scollegarla."
        eject_fail      = "Impossibile espellere (chiavetta ancora in uso?). Chiudi le finestre che la usano ed espellila dal sistema prima di scollegarla."
        bypass_ask      = "Saltare le domande dell'installazione di Windows (account locale, senza account Microsoft né offerte Microsoft 365)? (S/N) "
        bypass_name     = "Nome dell'account locale di Windows [{0}]: "
        bypass_done     = "File di risposte scritto sulla chiavetta: autounattend.xml (account locale '{0}'). Le schermate di lingua, edizione e disco restano visibili."
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
        eject_ok        = "Pen ejetada: já a podes desligar."
        eject_fail      = "Não foi possível ejetar (pen ainda em uso?). Fecha as janelas que a usam e ejeta-a pelo sistema antes de a desligar."
        bypass_ask      = "Ignorar as perguntas da instalação do Windows (conta local, sem conta Microsoft nem ofertas do Microsoft 365)? (S/N) "
        bypass_name     = "Nome da conta local do Windows [{0}]: "
        bypass_done     = "Ficheiro de respostas escrito na pen: autounattend.xml (conta local '{0}'). Os ecrãs de idioma, edição e disco continuam visíveis."
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
function Invoke-TelechargementMicrosoft {
    Write-Host (T 'dl_title') -ForegroundColor Cyan
    $loc = Get-LangueSysteme
    $rep = (Read-Host (T 'ask_lang' $loc)).Trim().ToLower().Replace('_', '-')
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
    try {
        Start-BitsTransfer -Source $url -Destination $part -DisplayName "ISO Windows 11" -ErrorAction Stop
        $ok = $true
    }
    catch {
        Write-Host (T 'bits_fail' $_.Exception.Message) -ForegroundColor Yellow
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
    Write-Host (T 'dl_speed' (Get-Vitesse (Get-Item -LiteralPath $dest).Length $swDl.Elapsed.TotalSeconds))

    Write-Host (T 'sha_calc') -ForegroundColor Cyan
    $calc = (Get-FileHash -Algorithm SHA256 -LiteralPath $dest).Hash
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

# --- Réponses automatiques : ignorer les questions de la première configuration de Windows ---
$bypass = $false; $nomCompte = ''
if ((Read-Host (T 'bypass_ask')) -match '^[oOyYsSjJ]') {
    $bypass = $true
    $saisie = Read-Host (T 'bypass_name' 'Utilisateur')
    $nomCompte = ([regex]::Replace([string]$saisie, '[\x00-\x1f"/\\\[\]:;|=,+*?<>@%&'']', '')).Trim().TrimEnd('.').Trim()
    if ($nomCompte.Length -gt 20) { $nomCompte = $nomCompte.Substring(0, 20).Trim() }
    if (-not $nomCompte) { $nomCompte = 'Utilisateur' }
}

# --- Préparation de la clé ---
if ($garde) {
    Write-Host (T 'kept') -ForegroundColor Green
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
        Write-Host (T 'data_created' ([math]::Round($pd.Size / 1GB, 1))) -ForegroundColor Green
    }
    else {
        $taille = [math]::Min([int64]32GB, $libreDispo)
        $part = New-Partition -DiskNumber $n -Size $taille -AssignDriveLetter
        Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel "WIN11" -Force | Out-Null
    }
}
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
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add"><Order>1</Order><Path>reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add"><Order>2</Order><Path>reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add"><Order>3</Order><Path>reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add"><Order>4</Order><Path>reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add"><Order>5</Order><Path>reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>@NOM@</Name>
            <DisplayName>@NOM@</DisplayName>
            <Group>Administrators</Group>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
    </component>
  </settings>
</unattend>
'@
        $xml = $xml.Replace('@NOM@', $nomCompte)
        [IO.File]::WriteAllText("$usb\autounattend.xml", $xml, (New-Object Text.UTF8Encoding $false))
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
    try { Write-VolumeCache -DriveLetter $usb.TrimEnd(':') -ErrorAction Stop } catch { }
    $swTotal.Stop()
    $ecritTotal = $libreAvant - [IO.DriveInfo]::new($usb).AvailableFreeSpace
    $vTotal = Get-Vitesse $ecritTotal $swTotal.Elapsed.TotalSeconds
    Write-Host (T 'total_speed' ([math]::Round($ecritTotal / 1GB, 2)), (Format-Duree $swTotal.Elapsed.TotalSeconds), $vTotal) -ForegroundColor Green
    if ($vTotal -lt $SeuilLent) { Write-Host (T 'slow_drive' $vTotal) -ForegroundColor Yellow }

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

# --- Éjection propre de la clé ---
if ((Read-Host (T 'eject_ask')) -match '^[oOyYsSjJ]') {
    $ejecte = $false
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
    if ($ejecte) { Write-Host (T 'eject_ok') -ForegroundColor Green }
    else { Write-Host (T 'eject_fail') -ForegroundColor Yellow }
}
