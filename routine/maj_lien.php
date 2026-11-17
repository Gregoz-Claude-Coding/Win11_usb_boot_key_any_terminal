#!/usr/bin/env php
<?php
declare(strict_types=1);

/**
 * Routine quotidienne : ouvre la page Microsoft dans un Chrome headless, choisit l'ISO et la langue
 * comme le ferait un utilisateur (clics réels), relève le lien généré et le publie dans le dépôt GitHub.
 *
 * Sécurité :
 *  - aucun port réseau n'est ouvert : Chrome est piloté par tuyaux (--remote-debugging-pipe), pas de serveur web ;
 *  - le jeton GitHub vient du trousseau macOS (ou de la variable GITHUB_TOKEN), jamais du script ;
 *  - le lien (qui contient une signature) n'est ni affiché ni journalisé, sauf avec --show.
 *
 * Aucun contournement de détection de robot : si la page refuse, la routine s'arrête et le journal le dit.
 *
 * Une exécution génère un lien pour CHAQUE langue proposée par Microsoft (la liste est lue sur la page) :
 * la page est rechargée pour chaque langue, avec une pause entre deux. Tous les liens sont publiés en une seule fois.
 * Si Microsoft limite les demandes (3 échecs de suite), la routine s'arrête et publie ce qu'elle a obtenu.
 *
 * Usage : php maj_lien.php [--dry-run] [--show] [--langue=French] [--delai=8] [--max=N] [--help]
 * Codes de sortie : 0 ok (au moins un lien), 1 configuration, 2 page ou lien introuvable, 3 publication GitHub.
 */

// ------------------------------------------------------------------ Configuration
const DEPOT             = 'gregorybrice-coder/Win11_usb_boot_key_any_terminal';
const FICHIER           = 'iso_links.txt';
const BRANCHE           = 'main';
const PAGE              = 'https://www.microsoft.com/fr-fr/software-download/windows11';
const SERVICE_TROUSSEAU = 'win11-liens-github';
const VALIDITE_MIN      = 3600;   // un lien qui expire dans moins d'une heure est refusé

$dir = __DIR__;

// ------------------------------------------------------------------ Journal
function journal(string $msg): void
{
    global $dir;
    $ligne = date('Y-m-d H:i:s') . '  ' . $msg . "\n";
    @file_put_contents($dir . '/maj_lien.log', $ligne, FILE_APPEND);
    fwrite(STDERR, $ligne);
}

// ------------------------------------------------------------------ Client minimal du protocole Chrome (par tuyaux)
final class Chrome
{
    /** @var resource */
    private $proc;
    /** @var array<int,resource> */
    private array $tuyaux = [];
    private int $id = 0;
    private string $tampon = '';

    public function __construct(string $bin, string $profil, string $journalChrome, bool $sansSandbox)
    {
        $cmd = [$bin, '--headless=new', '--remote-debugging-pipe', '--user-data-dir=' . $profil,
                '--no-first-run', '--no-default-browser-check', '--disable-gpu', '--window-size=1280,900'];
        if ($sansSandbox) {
            $cmd[] = '--no-sandbox';
        }
        $cmd[] = 'about:blank';
        $spec = [
            0 => ['file', '/dev/null', 'r'],
            1 => ['file', '/dev/null', 'w'],
            2 => ['file', $journalChrome, 'w'],
            3 => ['pipe', 'r'],   // Chrome lit ici nos commandes
            4 => ['pipe', 'w'],   // Chrome écrit ici ses réponses
        ];
        $proc = proc_open($cmd, $spec, $this->tuyaux);
        if (!is_resource($proc)) {
            throw new RuntimeException('Chrome ne démarre pas.');
        }
        $this->proc = $proc;
        stream_set_blocking($this->tuyaux[4], false);
    }

    private function lire(float $attente): ?array
    {
        if (strpos($this->tampon, "\0") === false) {
            $r = [$this->tuyaux[4]];
            $w = null;
            $e = null;
            $sec = (int)$attente;
            $usec = (int)(($attente - $sec) * 1000000);
            if (stream_select($r, $w, $e, $sec, $usec) > 0) {
                $d = fread($this->tuyaux[4], 65536);
                if ($d === false || $d === '') {
                    if (feof($this->tuyaux[4])) {
                        throw new RuntimeException("Chrome s'est arrêté.");
                    }
                } else {
                    $this->tampon .= $d;
                }
            }
        }
        $pos = strpos($this->tampon, "\0");
        if ($pos === false) {
            return null;
        }
        $brut = substr($this->tampon, 0, $pos);
        $this->tampon = substr($this->tampon, $pos + 1);
        $m = json_decode($brut, true);
        return is_array($m) ? $m : null;
    }

    public function envoyer(string $methode, array $params = [], ?string $session = null, float $delai = 30.0): array
    {
        $this->id++;
        $id = $this->id;
        $msg = ['id' => $id, 'method' => $methode, 'params' => (object)$params];
        if ($session !== null) {
            $msg['sessionId'] = $session;
        }
        fwrite($this->tuyaux[3], json_encode($msg) . "\0");
        $fin = microtime(true) + $delai;
        while (microtime(true) < $fin) {
            $m = $this->lire(0.2);
            if ($m === null) {
                continue;
            }
            if (isset($m['id']) && $m['id'] === $id) {
                if (isset($m['error'])) {
                    throw new RuntimeException($methode . ' : ' . json_encode($m['error']));
                }
                return $m['result'] ?? [];
            }
        }
        throw new RuntimeException('Délai dépassé : ' . $methode);
    }

    /** Exécute du JavaScript dans la page et renvoie la valeur. */
    public function evaluer(string $session, string $js)
    {
        $r = $this->envoyer('Runtime.evaluate',
            ['expression' => $js, 'awaitPromise' => true, 'returnByValue' => true], $session, 60.0);
        if (isset($r['exceptionDetails'])) {
            throw new RuntimeException('Erreur JavaScript : ' . ($r['exceptionDetails']['text'] ?? '?'));
        }
        return $r['result']['value'] ?? null;
    }

    /** Répète le script JS jusqu'à ce qu'il renvoie une valeur « vraie ». */
    public function attendre(string $session, string $js, float $delai)
    {
        $max = getenv('DELAI_MAX');           // plafond des attentes (utile pour les tests)
        if ($max !== false && $max !== '') {
            $delai = min($delai, (float)$max);
        }
        $fin = microtime(true) + $delai;
        do {
            $v = $this->evaluer($session, $js);
            if ($v) {
                return $v;
            }
            usleep(500000);
        } while (microtime(true) < $fin);
        return null;
    }

    /** Clic de souris réel au point (x, y). */
    public function clic(string $session, float $x, float $y): void
    {
        $base = ['x' => $x, 'y' => $y, 'button' => 'left', 'clickCount' => 1];
        $this->envoyer('Input.dispatchMouseEvent', ['type' => 'mouseMoved', 'x' => $x, 'y' => $y], $session);
        $this->envoyer('Input.dispatchMouseEvent', $base + ['type' => 'mousePressed'], $session);
        usleep(80000);
        $this->envoyer('Input.dispatchMouseEvent', $base + ['type' => 'mouseReleased'], $session);
    }

    public function fermer(): void
    {
        try {
            $this->envoyer('Browser.close', [], null, 5.0);
        } catch (Throwable $e) {
            // Chrome peut se fermer avant de répondre
        }
        $fin = microtime(true) + 5;
        while (microtime(true) < $fin) {
            $etat = proc_get_status($this->proc);
            if (!$etat['running']) {
                break;
            }
            usleep(200000);
        }
        if (proc_get_status($this->proc)['running']) {
            proc_terminate($this->proc);
        }
        foreach ($this->tuyaux as $t) {
            if (is_resource($t)) {
                fclose($t);
            }
        }
        proc_close($this->proc);
    }
}

// ------------------------------------------------------------------ Outils
function trouver_chrome(): ?string
{
    $env = getenv('CHROME_BIN');
    if ($env && is_executable($env)) {
        return $env;
    }
    foreach (['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
              '/Applications/Chromium.app/Contents/MacOS/Chromium',
              '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'] as $c) {
        if (is_executable($c)) {
            return $c;
        }
    }
    return null;
}

function supprimer_dossier(string $d): void
{
    if (!is_dir($d)) {
        return;
    }
    $it = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($d, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST);
    foreach ($it as $f) {
        if ($f->isDir() && !$f->isLink()) {
            @rmdir($f->getPathname());
        } else {
            @unlink($f->getPathname());
        }
    }
    @rmdir($d);
}

/** Script JS qui renvoie {x, y} (centre de l'élément trouvé, visible et activé) ou null. */
function js_centre(string $corpsRecherche): string
{
    return '(() => { const el = (() => { ' . $corpsRecherche . ' })(); if (!el) return null;
        el.scrollIntoView({block: "center"}); const r = el.getBoundingClientRect();
        return {x: r.left + r.width / 2, y: r.top + r.height / 2}; })()';
}

/** Clic réel sur l'élément ; si l'étape suivante n'apparaît pas, nouvel essai par un clic JavaScript. */
function cliquer(Chrome $c, string $s, string $corpsRecherche, string $jsSuite, float $delai, string $nom): void
{
    $pt = $c->attendre($s, js_centre($corpsRecherche), 60);
    if (!$pt) {
        throw new RuntimeException("Élément introuvable : $nom");
    }
    $c->clic($s, (float)$pt['x'], (float)$pt['y']);
    if ($c->attendre($s, $jsSuite, 5)) {
        return;
    }
    journal("Clic « $nom » sans effet visible : nouvel essai par clic JavaScript.");
    $c->evaluer($s, '(() => { const el = (() => { ' . $corpsRecherche . ' })(); if (el) el.click(); return true; })()');
    if (!$c->attendre($s, $jsSuite, $delai)) {
        throw new RuntimeException("Pas de suite après « $nom ».");
    }
}

function js_select_edition(): string
{
    return 'return [...document.querySelectorAll("select")].find(s => [...s.options].some(o => /ISO/i.test(o.text) && o.value !== "null"));';
}

function js_select_langue(string $langue): string
{
    $motif = json_encode('"language":"' . $langue . '"');
    return 'return [...document.querySelectorAll("select")].find(s => [...s.options].some(o => o.value.includes(' . $motif . ')));';
}

/** Sélecteur du menu des langues, quelle que soit la langue (options de la forme {"id":..,"language":".."}). */
function js_select_langues(): string
{
    return 'return [...document.querySelectorAll("select")].find(s => [...s.options].some(o => /"language"\\s*:/.test(o.value)));';
}

/** Liste des langues proposées par la page : [['language' => 'French', 'label' => 'Français'], ...] */
function js_liste_langues(): string
{
    return '(() => { const s = (() => { ' . js_select_langues() . ' })(); if (!s) return null;
        return [...s.options].map(o => { try { const j = JSON.parse(o.value); return j.language ? {language: j.language, label: o.text.trim()} : null; }
            catch (e) { return null; } }).filter(Boolean); })()';
}

function js_bouton_apres(string $selecteur, string $regex): string
{
    return 'const sel = (() => { ' . $selecteur . ' })(); if (!sel) return null;
        return [...document.querySelectorAll("button")].find(b => !b.disabled && b.offsetParent !== null
            && (sel.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING)
            && ' . $regex . '.test((b.innerText || b.textContent || "") + " " + (b.getAttribute("aria-label") || "")));';
}

/** Contrôle l'URL relevée et en extrait l'expiration (paramètre P1) et le numéro de build. */
function analyser_lien(string $url): array
{
    $p = parse_url($url);
    $hote = strtolower((string)($p['host'] ?? ''));
    $chemin = (string)($p['path'] ?? '');
    $ok = ($p['scheme'] ?? '') === 'https'
        && !isset($p['port']) && !isset($p['user'])
        && strlen($hote) > 14 && substr_compare($hote, '.microsoft.com', -14) === 0
        && preg_match('/^[a-z0-9.-]+$/', $hote) === 1
        && strtolower(substr($chemin, -4)) === '.iso';
    if (!$ok) {
        throw new RuntimeException("Lien refusé : il doit être en https, sur un domaine *.microsoft.com, et se terminer par .iso.");
    }
    parse_str((string)($p['query'] ?? ''), $q);
    if (!isset($q['P1']) || !ctype_digit((string)$q['P1']) || !isset($q['t'])) {
        throw new RuntimeException('Lien refusé : signature absente (paramètres t / P1).');
    }
    $expiration = (int)$q['P1'];
    $build = preg_match('/_(\d+)_(\d+)\.iso$/i', $chemin, $m) ? $m[1] . '.' . $m[2] : 'inconnu';
    return ['expiration' => $expiration, 'build' => $build, 'fichier' => basename($chemin)];
}

/** Code de langue lu dans le nom du fichier (Windows11_Client_x64_fr-fr_26300_9457.iso -> fr-fr). */
function code_langue(string $fichier): ?string
{
    return preg_match('/_x64_([a-z]{2,3}(?:-[a-z0-9]+){1,2})_\\d+_\\d+\\.iso$/i', $fichier, $m) ? strtolower($m[1]) : null;
}

/** Fusionne les nouveaux liens ($entrees : code => [build, expiration, url]) dans le contenu du fichier.
 *  Les anciennes lignes des autres langues sont conservées tant qu'elles n'ont pas expiré. */
function maj_contenu(string $ancien, array $entrees, int $maintenant): string
{
    $entete = "# Direct Windows 11 (x64) ISO links, generated daily by routine/maj_lien.php.\n"
            . "# Format: language;build;expiry (Unix epoch);url\n"
            . "# Links are signed by Microsoft and expire after 24 h: do not use them past the expiry.\n";
    $lignes = [];
    foreach (preg_split('/\r?\n/', $ancien) as $l) {
        $l = trim($l);
        if ($l === '' || $l[0] === '#') {
            continue;
        }
        $champs = explode(';', $l);
        if (count($champs) >= 4 && ctype_digit($champs[2]) && (int)$champs[2] > $maintenant && !isset($entrees[$champs[0]])) {
            $lignes[$champs[0]] = $l;
        }
    }
    foreach ($entrees as $code => $e) {
        $lignes[$code] = $code . ';' . $e['build'] . ';' . $e['expiration'] . ';' . $e['url'];
    }
    ksort($lignes);
    return $entete . implode("\n", $lignes) . "\n";
}

function lire_token(): ?string
{
    $t = getenv('GITHUB_TOKEN');
    if ($t) {
        return trim($t);
    }
    if (PHP_OS_FAMILY === 'Darwin') {
        $sortie = [];
        $rc = 1;
        exec('security find-generic-password -s ' . escapeshellarg(SERVICE_TROUSSEAU) . ' -w 2>/dev/null', $sortie, $rc);
        if ($rc === 0 && isset($sortie[0]) && $sortie[0] !== '') {
            return trim($sortie[0]);
        }
    }
    return null;
}

/** Appel à l'API GitHub. Renvoie [code HTTP, corps décodé]. */
function api(string $methode, string $url, string $token, ?array $corps = null): array
{
    $entetes = "Authorization: Bearer $token\r\nUser-Agent: win11-liens-routine\r\n"
             . "Accept: application/vnd.github+json\r\nX-GitHub-Api-Version: 2022-11-28\r\n";
    $http = ['method' => $methode, 'header' => $entetes, 'ignore_errors' => true, 'timeout' => 30];
    if ($corps !== null) {
        $http['header'] .= "Content-Type: application/json\r\n";
        $http['content'] = json_encode($corps);
    }
    $rep = @file_get_contents($url, false, stream_context_create(['http' => $http]));
    $code = 0;
    foreach ($http_response_header ?? [] as $h) {
        if (preg_match('#^HTTP/\S+\s+(\d+)#', $h, $m)) {
            $code = (int)$m[1];
        }
    }
    $decode = json_decode((string)$rep, true);
    return [$code, is_array($decode) ? $decode : []];
}

function publier(string $base, string $token, array $entrees): bool
{
    $point = rtrim($base, '/') . '/repos/' . DEPOT . '/contents/' . FICHIER;
    [$c, $cur] = api('GET', $point . '?ref=' . BRANCHE, $token);
    $ancien = '';
    $sha = null;
    if ($c === 200 && isset($cur['content'], $cur['sha'])) {
        $ancien = (string)base64_decode(str_replace("\n", '', (string)$cur['content']));
        $sha = (string)$cur['sha'];
    } elseif ($c !== 404) {
        throw new RuntimeException("Lecture de " . FICHIER . " impossible (HTTP $c).");
    }
    $nouveau = maj_contenu($ancien, $entrees, time());
    if ($nouveau === $ancien) {
        journal('Fichier inchangé : rien à publier.');
        return false;
    }
    $corps = ['message' => 'Mise à jour des liens ISO (' . count($entrees) . ' langues)',
              'content' => base64_encode($nouveau), 'branch' => BRANCHE];
    if ($sha !== null) {
        $corps['sha'] = $sha;
    }
    [$c2] = api('PUT', $point, $token, $corps);
    if ($c2 !== 200 && $c2 !== 201) {
        throw new RuntimeException("Publication refusée (HTTP $c2).");
    }
    return true;
}

function notifier(string $texte): void
{
    if (PHP_OS_FAMILY === 'Darwin') {
        $s = 'display notification ' . json_encode($texte) . ' with title "Routine lien ISO Windows 11"';
        @exec('osascript -e ' . escapeshellarg($s) . ' >/dev/null 2>&1');
    }
}

// ------------------------------------------------------------------ Étapes de la page
/** Charge la page, choisit l'ISO dans le menu des éditions et valide : attend l'apparition du menu des langues. */
function ouvrir_page_edition(Chrome $chrome, string $s, string $page): void
{
    $chrome->envoyer('Page.navigate', ['url' => $page], $s);
    $edition = $chrome->attendre($s, '(() => { const sel = (() => { ' . js_select_edition() . ' })(); if (!sel) return false;
        const o = [...sel.options].find(o => /ISO/i.test(o.text) && o.value !== "null");
        sel.value = o.value;
        sel.dispatchEvent(new Event("input", {bubbles: true}));
        sel.dispatchEvent(new Event("change", {bubbles: true}));
        return o.text; })()', 90);
    if (!$edition) {
        $texte = (string)$chrome->evaluer($s, 'document.body ? document.body.innerText.substring(0, 300) : ""');
        throw new RuntimeException("Menu des éditions introuvable (page refusée ou modifiée ?). Début de page : "
            . str_replace("\n", ' / ', $texte));
    }
    cliquer($chrome, $s,
        js_bouton_apres(js_select_edition(), '/(Télécharger|Download)/i'),
        '!!(() => { ' . js_select_langues() . ' })()', 30, 'Télécharger');
}

/** Choisit la langue du produit, confirme, et renvoie le lien généré. */
function lien_pour_langue(Chrome $chrome, string $s, string $langue): string
{
    $chrome->evaluer($s, '(() => { const sel = (() => { ' . js_select_langue($langue) . ' })();
        if (!sel) throw new Error("langue absente");
        const o = [...sel.options].find(o => o.value.includes(' . json_encode('"language":"' . $langue . '"') . '));
        sel.value = o.value;
        sel.dispatchEvent(new Event("input", {bubbles: true}));
        sel.dispatchEvent(new Event("change", {bubbles: true}));
        return true; })()');
    $jsLien = '(() => { const a = [...document.querySelectorAll("a[href]")].find(a => /\.iso\?/i.test(a.href) && /[?&]P1=/.test(a.href));
        return a ? a.href : null; })()';
    cliquer($chrome, $s,
        js_bouton_apres(js_select_langue($langue), '/(Confirmer|Confirm)/i'),
        $jsLien, 90, 'Confirmer');
    return (string)$chrome->evaluer($s, $jsLien);
}

// ------------------------------------------------------------------ Programme
$opt = getopt('', ['dry-run', 'show', 'page-url:', 'api-base:', 'langue:', 'delai:', 'max:', 'help']);
if (isset($opt['help'])) {
    echo "Usage : php maj_lien.php [--dry-run] [--show] [--langue=French] [--delai=8] [--max=N]\n"
       . "  --dry-run  génère les liens mais ne publie rien\n"
       . "  --show     affiche les liens complets (ils contiennent une signature : à ne pas partager)\n"
       . "  --langue   une seule langue, par son nom anglais chez Microsoft (French, German...) ; défaut : toutes\n"
       . "  --delai    pause en secondes entre deux langues (défaut 8)\n"
       . "  --max      nombre maximal de langues traitées (défaut : toutes)\n";
    exit(0);
}
$dry     = isset($opt['dry-run']);
$show    = isset($opt['show']);
$filtre  = isset($opt['langue']) ? (string)$opt['langue'] : null;
$delaiEnv = getenv('DELAI_LANGUES');
$delai   = isset($opt['delai']) ? (int)$opt['delai'] : (($delaiEnv !== false && $delaiEnv !== '') ? (int)$delaiEnv : 8);
$max     = (int)($opt['max'] ?? 0);
$page    = (string)($opt['page-url'] ?? PAGE);
$apiBase = (string)($opt['api-base'] ?? 'https://api.github.com');

$verrou = fopen($dir . '/.verrou', 'c');
if ($verrou === false || !flock($verrou, LOCK_EX | LOCK_NB)) {
    journal('Une autre exécution est déjà en cours : abandon.');
    exit(0);
}

$bin = trouver_chrome();
if ($bin === null) {
    journal('Chrome introuvable (variable CHROME_BIN possible).');
    exit(1);
}
$token = null;
if (!$dry) {
    $token = lire_token();
    if ($token === null) {
        journal("Jeton GitHub introuvable (trousseau '" . SERVICE_TROUSSEAU . "' ou variable GITHUB_TOKEN).");
        exit(1);
    }
}

$profil = $dir . '/chrome_profil';
supprimer_dossier($profil);
mkdir($profil, 0700, true);
$sansSandbox = (function_exists('posix_geteuid') && posix_geteuid() === 0) || getenv('CHROME_NO_SANDBOX') === '1';

$chrome = null;
$sortie = 0;
try {
    journal('Démarrage (' . ($filtre ?? 'toutes les langues') . ', ' . ($dry ? 'simulation' : 'publication') . ').');
    $chrome = new Chrome($bin, $profil, $dir . '/chrome.log', $sansSandbox);
    $t = $chrome->envoyer('Target.createTarget', ['url' => 'about:blank']);
    $a = $chrome->envoyer('Target.attachToTarget', ['targetId' => $t['targetId'], 'flatten' => true]);
    $s = (string)$a['sessionId'];
    $chrome->envoyer('Page.enable', [], $s);
    $chrome->envoyer('Runtime.enable', [], $s);

    // 1. Ouvrir la page, choisir l'ISO, lire la liste des langues proposées par Microsoft
    ouvrir_page_edition($chrome, $s, $page);
    $liste = $chrome->evaluer($s, js_liste_langues());
    if (!is_array($liste) || count($liste) === 0) {
        throw new RuntimeException('Aucune langue lue dans le menu de la page.');
    }
    $langues = array_values(array_unique(array_map(fn($l) => (string)$l['language'], $liste)));
    if ($filtre !== null) {
        $langues = array_values(array_filter($langues, fn($n) => $n === $filtre));
        if (!$langues) {
            throw new RuntimeException("Langue « $filtre » absente de la page.");
        }
    }
    if ($max > 0) {
        $langues = array_slice($langues, 0, $max);
    }
    journal(count($langues) . ' langue(s) à traiter : ' . implode(', ', $langues));

    // 2. Un lien par langue (page rechargée à chaque fois, pause entre deux)
    $entrees = [];
    $echecs = [];
    $consecutifs = 0;
    foreach ($langues as $i => $nom) {
        if ($i > 0) {
            sleep($delai);
        }
        try {
            if ($i > 0) {
                ouvrir_page_edition($chrome, $s, $page);
            }
            $url = lien_pour_langue($chrome, $s, $nom);
            $info = analyser_lien($url);
            $reste = $info['expiration'] - time();
            if ($reste < VALIDITE_MIN) {
                throw new RuntimeException('le lien expire dans moins d\'une heure : refusé');
            }
            $code = code_langue($info['fichier']);
            if ($code === null) {
                throw new RuntimeException('code de langue illisible dans le nom du fichier ' . $info['fichier']);
            }
            if (isset($entrees[$code])) {
                throw new RuntimeException("code $code déjà obtenu pour une autre langue");
            }
            $entrees[$code] = ['build' => $info['build'], 'expiration' => $info['expiration'], 'url' => $url];
            $consecutifs = 0;
            journal(sprintf('%s (%s) : lien obtenu, build %s, valable jusqu\'au %s.',
                $nom, $code, $info['build'], date('Y-m-d H:i', $info['expiration'])));
            if ($show) {
                echo $url . "\n";
            }
        } catch (Throwable $e) {
            $echecs[] = $nom;
            journal("$nom : ÉCHEC : " . $e->getMessage());
            if (++$consecutifs >= 3) {
                journal('3 échecs de suite : arrêt (Microsoft limite peut-être les demandes). Aucune tentative de contournement.');
                break;
            }
        }
    }
    journal(count($entrees) . ' lien(s) obtenu(s), ' . count($echecs) . ' échec(s)' . ($echecs ? ' (' . implode(', ', $echecs) . ')' : '') . '.');
    if (!$entrees) {
        throw new RuntimeException('Aucun lien obtenu.');
    }

    // 3. Publier tout en une seule fois
    if ($dry) {
        journal('Simulation : rien n\'est publié.');
    } else {
        try {
            if (publier($apiBase, (string)$token, $entrees)) {
                journal('Liens publiés sur GitHub (' . DEPOT . ', ' . FICHIER . ').');
            }
        } catch (Throwable $e) {
            journal('ERREUR de publication : ' . $e->getMessage());
            $sortie = 3;
        }
    }
    if ($echecs && $sortie === 0) {
        notifier(count($entrees) . ' langue(s) mises à jour, ' . count($echecs) . ' en échec : voir maj_lien.log');
    }
} catch (Throwable $e) {
    journal('ERREUR : ' . $e->getMessage());
    $sortie = 2;
} finally {
    if ($chrome !== null) {
        $chrome->fermer();
    }
    supprimer_dossier($profil);
}
if ($sortie !== 0) {
    notifier('Échec (code ' . $sortie . ') : voir maj_lien.log');
}
exit($sortie);
