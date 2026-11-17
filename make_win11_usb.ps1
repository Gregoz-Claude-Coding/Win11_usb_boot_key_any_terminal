# Création d'une clé USB bootable Windows 11 (UEFI/GPT, FAT32) à partir d'un ISO

# --- Droits administrateur ---
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host "Ouvre la console en administrateur." -ForegroundColor Red; return }

# --- Paramètres et fonctions de téléchargement ---
$UrlMicrosoft  = "https://www.microsoft.com/fr-fr/software-download/windows11"
$UrlHashes     = "https://raw.githubusercontent.com/gregorybrice-coder/Win11_usb_boot_key_any_terminal/main/versions_iso.txt"
$Marge         = 512MB   # journaux et fichiers temporaires
$EstimationWim = 6GB     # taille estimée de install.wim, découpé en local avant la copie sur la clé

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

# Télécharge l'ISO dans $dossier. Renvoie $true et renseigne $script:isoTelecharge en cas de succès.
function Invoke-TelechargementMicrosoft {
    Write-Host "Téléchargement de l'ISO Windows 11 depuis Microsoft" -ForegroundColor Cyan
    $loc = Get-LangueSysteme
    $rep = (Read-Host "Langue de la page Microsoft [$loc] (Entrée pour valider, ou autre code, ex. en-us)").Trim().ToLower().Replace('_', '-')
    if ($rep) {
        if ($rep -match '^[a-z]{2,3}(-[a-z0-9]{2,4}){1,2}$') { $loc = $rep }
        else { Write-Host "Code invalide : langue détectée conservée ($loc)." -ForegroundColor Yellow }
    }
    $page = "https://www.microsoft.com/$loc/software-download/windows11"
    Write-Host "Page officielle : $page"
    Write-Host "Microsoft ne publie pas de lien fixe : le lien direct est généré à chaque téléchargement"
    Write-Host "et n'est valable que 24 heures."
    Write-Host "  1. Ouvre la page officielle ci-dessus dans ton navigateur."
    Write-Host "  2. Dans « Télécharger l'image disque Windows 11 (ISO) pour les appareils x64 », choisis l'ISO"
    Write-Host "     multi-éditions, puis la langue du produit (ta langue système : $loc) et clique sur « Confirmer »."
    Write-Host "  3. Clic droit sur le bouton de téléchargement 64 bits > « Copier l'adresse du lien »."
    Write-Host "     Colle le lien ENTIER, y compris ce qui suit « .iso? » : c'est ce qui l'autorise."
    $url = (Read-Host "Colle ici l'URL du lien (https://...microsoft.com/....iso)").Trim().Trim('"')
    if (-not (Test-UrlMicrosoft $url)) {
        Write-Host "URL refusée : elle doit être en https, sur un domaine *.microsoft.com, et son chemin doit se terminer par .iso." -ForegroundColor Red
        return $false
    }
    $nom = [IO.Path]::GetFileName(([Uri]$url).AbsolutePath) -replace '[^A-Za-z0-9._-]', ''
    if (-not $nom) { $nom = "Win11.iso" }
    $dest = Join-Path $dossier $nom
    if (Test-Path -LiteralPath $dest) {
        Write-Host "$nom existe déjà dans $dossier : utilisation du fichier existant." -ForegroundColor Yellow
        $script:isoTelecharge = $dest
        return $true
    }

    Write-Host "Interrogation du serveur Microsoft..." -ForegroundColor Cyan
    $taille = Get-TailleDistante $url
    if ($taille -le 0) {
        $code = Get-CodeHttp $url
        if ($code -lt 200 -or $code -ge 300) {
            Write-Host "Le serveur Microsoft a répondu HTTP $code (0 = pas de réponse) : lien expiré, incomplet (sans la partie après « .iso? ») ou réseau injoignable." -ForegroundColor Red
            Write-Host "Génère un nouveau lien sur la page officielle." -ForegroundColor Red
            return $false
        }
        $taille = 8GB
        Write-Host "Taille de l'ISO non communiquée : hypothèse de 8 Go." -ForegroundColor Yellow
    }
    # install.wim est découpé en local (swm_tmp) avant d'être copié sur la clé :
    # il faut la place de l'ISO + celle des morceaux (environ la taille de install.wim).
    $besoin = $taille + $EstimationWim + $Marge
    $libre  = Get-EspaceLibre $dossier
    Write-Host ("  Taille de l'ISO                       : {0} Go" -f [math]::Round($taille / 1GB, 2))
    Write-Host ("  Découpage local de install.wim (est.) : {0} Go" -f [math]::Round($EstimationWim / 1GB, 2))
    Write-Host ("  Espace nécessaire (avec marge)        : {0} Go" -f [math]::Round($besoin / 1GB, 2))
    if ($null -eq $libre) {
        Write-Host "  Espace libre : impossible à déterminer pour $dossier, contrôle ignoré." -ForegroundColor Yellow
    }
    else {
        Write-Host ("  Espace libre                          : {0} Go ({1})" -f [math]::Round($libre / 1GB, 2), $dossier)
        if ($libre -lt $besoin) {
            Write-Host ("Espace disque insuffisant : il manque {0} Go." -f [math]::Round(($besoin - $libre) / 1GB, 2)) -ForegroundColor Red
            return $false
        }
    }
    if ((Read-Host "Lancer le téléchargement vers $dest ? (O/N)") -notmatch '^[oOyY]') { return $false }

    Write-Host "Téléchargement..." -ForegroundColor Cyan
    $part = "$dest.part"
    $ok = $false
    try {
        Start-BitsTransfer -Source $url -Destination $part -DisplayName "ISO Windows 11" -ErrorAction Stop
        $ok = $true
    }
    catch {
        Write-Host "BITS en échec ($($_.Exception.Message)) : essai avec curl.exe..." -ForegroundColor Yellow
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        & curl.exe -L --fail --progress-bar -o $part $url | Out-Host
        $ok = ($LASTEXITCODE -eq 0)
    }
    if (-not $ok) {
        Write-Host "Échec du téléchargement (lien expiré ou réseau ?). Génère un nouveau lien sur la page Microsoft." -ForegroundColor Red
        if ((Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part).Length -eq 0)) { Remove-Item -LiteralPath $part -Force }
        return $false
    }
    Move-Item -LiteralPath $part -Destination $dest -Force
    Write-Host "Téléchargement terminé : $dest" -ForegroundColor Green

    Write-Host "Calcul de l'empreinte SHA-256 (quelques minutes)..." -ForegroundColor Cyan
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
        Write-Host "Empreinte conforme à celle publiée par Microsoft ($($c[0]) - $($c[1]))." -ForegroundColor Green
    }
    else {
        Write-Host "Empreinte non reconnue (version ou langue absente de versions_iso.txt, ou fichier altéré)." -ForegroundColor Yellow
        Write-Host "SHA-256 calculé : $calc"
        $attendu = (Read-Host "Empreinte SHA-256 affichée par Microsoft pour cette langue (Entrée pour ignorer)").Trim()
        if ($attendu) {
            if ($calc -ne ($attendu -replace '\s', '')) {
                Write-Host "Empreinte différente : fichier corrompu ou incomplet. Supprime-le et recommence." -ForegroundColor Red
                return $false
            }
            Write-Host "Empreinte conforme." -ForegroundColor Green
        }
    }
    $script:isoTelecharge = $dest
    return $true
}

# --- Recherche des ISO dans le répertoire courant ---
$dossier = (Get-Location).ProviderPath
$isos = @(Get-ChildItem -LiteralPath $dossier -Filter *.iso -File -ErrorAction SilentlyContinue | Sort-Object Name)

if ($isos.Count -eq 0) {
    Write-Host "Aucun fichier .iso trouvé dans $dossier." -ForegroundColor Yellow
    $saisie = (Read-Host "T pour télécharger l'ISO depuis Microsoft, ou chemin complet de l'ISO").Trim('"')
    if ($saisie -eq 'T') {
        if (-not (Invoke-TelechargementMicrosoft)) { return }
        $iso = $script:isoTelecharge
    }
    else { $iso = $saisie }
}
else {
    Write-Host "ISO trouvés dans $dossier :" -ForegroundColor Cyan
    for ($i = 0; $i -lt $isos.Count; $i++) {
        Write-Host ("  [{0}] {1}  ({2} Go)" -f ($i + 1), $isos[$i].Name, [math]::Round($isos[$i].Length / 1GB, 2))
    }
    Write-Host "  [T] Télécharger un ISO Windows 11 depuis Microsoft"
    $saisie = Read-Host "Numéro de l'ISO à utiliser (ou T)"
    if ($saisie -eq 'T') {
        if (-not (Invoke-TelechargementMicrosoft)) { return }
        $iso = $script:isoTelecharge
    }
    else {
        $choix = 0
        if (-not [int]::TryParse($saisie, [ref]$choix) -or $choix -lt 1 -or $choix -gt $isos.Count) {
            Write-Host "Choix invalide." -ForegroundColor Red
            return
        }
        $iso = $isos[$choix - 1].FullName
    }
    Write-Host "ISO sélectionné : $iso" -ForegroundColor Green
}
if (-not (Test-Path -LiteralPath $iso)) { Write-Host "ISO introuvable." -ForegroundColor Red; return }

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
        Write-Host ("Espace disque insuffisant dans {0} : {1} Go nécessaires pour découper install.wim, {2} Go libres." -f $dossier, [math]::Round($besoin / 1GB, 2), [math]::Round($libre / 1GB, 2)) -ForegroundColor Red
        return
    }
}

# --- Choix de la clé USB ---
$usbDisks = Get-Disk | Where-Object BusType -eq 'USB'
if (-not $usbDisks) { Write-Host "Aucune clé USB détectée." -ForegroundColor Red; return }
$usbDisks | Format-Table Number, FriendlyName, @{n='Go';e={[math]::Round($_.Size/1GB,1)}} -AutoSize
$n = [int](Read-Host "Numéro du disque USB à EFFACER")
$disk = $usbDisks | Where-Object Number -eq $n
if (-not $disk) { Write-Host "Ce numéro n'est pas une clé USB." -ForegroundColor Red; return }
$isoTaille = (Get-Item -LiteralPath $iso).Length
if ($disk.Size -lt $isoTaille) {
    Write-Host ("Clé trop petite : {0} Go pour un ISO de {1} Go." -f [math]::Round($disk.Size / 1GB, 2), [math]::Round($isoTaille / 1GB, 2)) -ForegroundColor Red
    return
}
if ((Read-Host "Confirmer l'effacement de '$($disk.FriendlyName)' ? (O/N)") -notmatch '^[oOyY]') { return }

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
    # --- Copie (tout sauf install.wim et autorun.inf), liste affichée + journal ---
    Write-Host "Copie des fichiers..." -ForegroundColor Cyan
    $log = "$dossier\copie_cle.log"
    robocopy "$src\" "$usb\" /E /XF install.wim autorun.inf /R:2 /W:2 /NJH /NJS /NP /TEE /LOG:"$log"
    if ($LASTEXITCODE -ge 8) {
        Write-Host "robocopy a rencontré des erreurs (code $LASTEXITCODE). Voir $log" -ForegroundColor Red
        return
    }
    if (-not (Test-Path "$usb\sources\boot.wim")) {
        Write-Host "sources\boot.wim absent de la clé : copie incomplète. Voir $log" -ForegroundColor Red
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
            Write-Host "Écriture sur la clé : OK" -ForegroundColor Green
        } catch {
            Write-Host "Écriture impossible sur $dst : $($_.Exception.Message)" -ForegroundColor Red
            return
        }

        # 2. Découpage sur le disque local avec barre de progression, puis copie vers la clé
        $tmpSwm = "$dossier\swm_tmp"
        $dlog   = "$dossier\dism_split.log"
        New-Item -ItemType Directory -Path $tmpSwm -Force | Out-Null
        Remove-Item "$tmpSwm\*" -Force -ErrorAction SilentlyContinue

        $total    = (Get-Item $wim).Length
        $dismArgs = "/Split-Image /ImageFile:`"$wim`" /SWMFile:`"$tmpSwm\install.swm`" /FileSize:3800"
        Write-Host "Découpage de install.wim dans $tmpSwm (~5 Go libres nécessaires)..." -ForegroundColor Cyan
        $p = Start-Process dism.exe -ArgumentList $dismArgs -NoNewWindow -PassThru -RedirectStandardOutput $dlog
        $null = $p.Handle   # nécessaire pour récupérer ExitCode

        while (-not $p.HasExited) {
            $done = (Get-ChildItem $tmpSwm -Filter install*.swm -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum).Sum
            $pct = [math]::Min(99, [int](100 * $done / $total))
            Write-Progress -Activity "Découpage de install.wim" `
                -Status ("{0} Mo / {1} Mo" -f [int]($done/1MB), [int]($total/1MB)) `
                -PercentComplete $pct
            Start-Sleep -Milliseconds 500
        }
        Write-Progress -Activity "Découpage de install.wim" -Completed

        if ($p.ExitCode -eq 0) {
            Write-Host "Copie des morceaux vers la clé..." -ForegroundColor Cyan
            Copy-Item "$tmpSwm\install*.swm" "$dst\" -Force -Verbose
            Remove-Item $tmpSwm -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Découpage terminé." -ForegroundColor Green
        } else {
            Write-Host "Échec de DISM (code $($p.ExitCode)). Dernières lignes de $dlog :" -ForegroundColor Red
            Get-Content $dlog -Tail 15
            return
        }
    }
    elseif (Test-Path $esd) {
        Write-Host "install.esd détecté : copie directe." -ForegroundColor Yellow
        Copy-Item $esd "$dst\" -Force
    }
    else {
        Write-Host "Ni install.wim ni install.esd trouvé dans l'ISO." -ForegroundColor Red
        return
    }

    # --- Inventaire de la clé ---
    Get-ChildItem "$usb\" -Recurse -File |
        Select-Object @{n='Fichier';e={$_.FullName.Substring($usb.Length)}}, @{n='Mo';e={[math]::Round($_.Length/1MB,1)}} |
        Out-File "$dossier\contenu_cle.txt"

    Write-Host "Terminé : clé prête sur $usb" -ForegroundColor Green
    Write-Host "Journaux : $log, $dlog et $dossier\contenu_cle.txt"
}
finally {
    Dismount-DiskImage -ImagePath $iso | Out-Null
}
