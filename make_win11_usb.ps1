# Création d'une clé USB bootable Windows 11 (UEFI/GPT, FAT32) à partir d'un ISO
# Creates a bootable Windows 11 USB drive (UEFI/GPT, FAT32) from an ISO

# --- Langue des menus : langue d'affichage de Windows (repli : anglais) ---
# Forcer une langue : $env:WIN11_LANG = 'en' avant de coller le script. Ajouter une langue : ajouter un bloc dans $Textes.
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
        sha_unknown     = 'Empreinte non reconnue (version ou langue absente de versions_iso.txt, ou fichier altéré).'
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
        sha_unknown     = 'Hash not recognized (version or language missing from versions_iso.txt, or altered file).'
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
$UrlHashes     = "https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/versions_iso.txt"
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
    if ((Read-Host (T 'confirm_dl' $dest)) -notmatch '^[oOyY]') { return $false }

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
if ((Read-Host (T 'confirm_erase' $disk.FriendlyName)) -notmatch '^[oOyY]') { return }

# --- Préparation de la clé ---
Clear-Disk -Number $n -RemoveData -RemoveOEM -Confirm:$false
Initialize-Disk -Number $n -PartitionStyle GPT
$taille = [math]::Min([int64]32GB, (Get-Disk -Number $n).LargestFreeExtent)
$part = New-Partition -DiskNumber $n -Size $taille -AssignDriveLetter
Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel "WIN11" -Force | Out-Null
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
