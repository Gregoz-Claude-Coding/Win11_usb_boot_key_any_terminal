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
 * Usage : php maj_lien.php [--dry-run] [--show] [--langue=French] [--code=fr-fr] [--help]
 * Codes de sortie : 0 ok, 1 configuration, 2 page ou lien introuvable, 3 publication GitHub.
 */

// ------------------------------------------------------------------ Configuration
const DEPOT             = 'gregorybrice-coder/Win11_usb_boot_key_any_terminal';
const FICHIER           = 'liens_iso.txt';
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

/** Remplace (ou ajoute) la ligne de la langue dans le contenu du fichier de liens. */
function maj_contenu(string $ancien, string $code, string $build, int $expiration, string $url): string
{
    $entete = "# Liens directs ISO Windows 11 (x64), générés chaque jour par la routine maj_lien.php.\n"
            . "# Format : langue;build;expiration (epoch Unix);url\n"
            . "# Ces liens sont signés par Microsoft et expirent au bout de 24 h : ne pas les utiliser au-delà de l'expiration.\n";
    $lignes = [];
    foreach (preg_split('/\r?\n/', $ancien) as $l) {
        $l = trim($l);
        if ($l === '' || $l[0] === '#') {
            continue;
        }
        $champs = explode(';', $l);
        if (($champs[0] ?? '') !== $code) {
            $lignes[$champs[0] ?? $l] = $l;
        }
    }
    $lignes[$code] = $code . ';' . $build . ';' . $expiration . ';' . $url;
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

function publier(string $base, string $token, string $code, array $info, string $url): bool
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
    $nouveau = maj_contenu($ancien, $code, $info['build'], $info['expiration'], $url);
    if ($nouveau === $ancien) {
        journal('Fichier inchangé : rien à publier.');
        return false;
    }
    $corps = ['message' => "Mise à jour du lien ISO $code (build {$info['build']})",
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

// ------------------------------------------------------------------ Programme
$opt = getopt('', ['dry-run', 'show', 'page-url:', 'api-base:', 'langue:', 'code:', 'help']);
if (isset($opt['help'])) {
    echo "Usage : php maj_lien.php [--dry-run] [--show] [--langue=French] [--code=fr-fr]\n"
       . "  --dry-run  génère le lien mais ne publie rien\n"
       . "  --show     affiche le lien complet (il contient une signature : à ne pas partager)\n";
    exit(0);
}
$dry    = isset($opt['dry-run']);
$show   = isset($opt['show']);
$langue = (string)($opt['langue'] ?? 'French');
$code   = (string)($opt['code'] ?? 'fr-fr');
$page   = (string)($opt['page-url'] ?? PAGE);
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
    journal("Démarrage ($code, " . ($dry ? 'simulation' : 'publication') . ').');
    $chrome = new Chrome($bin, $profil, $dir . '/chrome.log', $sansSandbox);
    $t = $chrome->envoyer('Target.createTarget', ['url' => 'about:blank']);
    $a = $chrome->envoyer('Target.attachToTarget', ['targetId' => $t['targetId'], 'flatten' => true]);
    $s = (string)$a['sessionId'];
    $chrome->envoyer('Page.enable', [], $s);
    $chrome->envoyer('Runtime.enable', [], $s);
    $chrome->envoyer('Page.navigate', ['url' => $page], $s);

    // 1. Choisir l'ISO dans le menu déroulant
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
    journal("Édition choisie : $edition");

    // 2. Valider le choix de l'ISO
    cliquer($chrome, $s,
        js_bouton_apres(js_select_edition(), '/(Télécharger|Download)/i'),
        '!!(() => { ' . js_select_langue($langue) . ' })()', 30, 'Télécharger');

    // 3. Choisir la langue du produit
    $chrome->evaluer($s, '(() => { const sel = (() => { ' . js_select_langue($langue) . ' })();
        const o = [...sel.options].find(o => o.value.includes(' . json_encode('"language":"' . $langue . '"') . '));
        sel.value = o.value;
        sel.dispatchEvent(new Event("input", {bubbles: true}));
        sel.dispatchEvent(new Event("change", {bubbles: true}));
        return true; })()');

    // 4. Confirmer
    $jsLien = '(() => { const a = [...document.querySelectorAll("a[href]")].find(a => /\.iso\?/i.test(a.href) && /[?&]P1=/.test(a.href));
        return a ? a.href : null; })()';
    cliquer($chrome, $s,
        js_bouton_apres(js_select_langue($langue), '/(Confirmer|Confirm)/i'),
        $jsLien, 90, 'Confirmer');

    // 5. Relever le lien généré
    $url = (string)$chrome->evaluer($s, $jsLien);
    $info = analyser_lien($url);
    $reste = $info['expiration'] - time();
    if ($reste < VALIDITE_MIN) {
        throw new RuntimeException('Le lien relevé expire dans moins d\'une heure : refusé.');
    }
    journal(sprintf("Lien obtenu : %s, build %s, valable jusqu'au %s (%d h %02d min).",
        $info['fichier'], $info['build'], date('Y-m-d H:i', $info['expiration']), intdiv($reste, 3600), intdiv($reste % 3600, 60)));
    if ($show) {
        echo $url . "\n";
    }

    // 6. Publier
    if ($dry) {
        journal('Simulation : rien n\'est publié.');
    } else {
        try {
            if (publier($apiBase, (string)$token, $code, $info, $url)) {
                journal('Lien publié sur GitHub (' . DEPOT . ', ' . FICHIER . ').');
            }
        } catch (Throwable $e) {
            journal('ERREUR de publication : ' . $e->getMessage());
            $sortie = 3;
        }
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
