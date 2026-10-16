<?php
// Shared helpers: config, database, JSON replies, Firebase sign-in check.
declare(strict_types=1);

if (basename($_SERVER['SCRIPT_FILENAME'] ?? '') === 'lib.php') { http_response_code(404); exit; }

const SERVER_VERSION = '1.1.0';

if (!defined('NO_JSON_HEADER')) {
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
}

function cfg(string $key) {
    static $c = null;
    if ($c === null) {
        $file = __DIR__ . '/config.php';
        if (!is_file($file)) reply(500, ['error' => 'config.php is missing. Copy config.sample.php to config.php and fill it in.']);
        $c = require $file;
    }
    return $c[$key] ?? null;
}

function reply(int $status, array $body): void {
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    // Send the reply now; anything registered with register_shutdown_function runs after.
    if (function_exists('fastcgi_finish_request')) @fastcgi_finish_request();
    exit;
}

function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        try {
            $pdo = new PDO(
                'mysql:host=' . cfg('db_host') . ';dbname=' . cfg('db_name') . ';charset=utf8mb4',
                cfg('db_user'), cfg('db_pass'),
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES => false]
            );
        } catch (Throwable $e) {
            $code = $e instanceof PDOException && isset($e->errorInfo[1]) ? (int) $e->errorInfo[1] : (int) $e->getCode();
            $hint = [
                1045 => 'Wrong db_user or db_pass. Use the FULL user name cPanel shows (like yourname_taskora) and re-type the password.',
                1044 => 'This user has no access to the database. In cPanel > MySQL Databases > Add User To Database, add it with ALL PRIVILEGES.',
                1049 => 'Wrong db_name. Use the FULL database name cPanel shows (like yourname_taskora).',
                2002 => 'Cannot reach the database server. Keep db_host as localhost (ask your host if they use a different one).',
                2005 => 'Unknown db_host. Keep it as localhost.',
            ][$code] ?? ('MySQL error ' . $code . '.');
            reply(500, ['error' => 'Database connection failed. Check config.php.', 'reason' => $hint]);
        }
    }
    return $pdo;
}

function now_ms(): int { return (int) floor(microtime(true) * 1000); }

function json_input(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') return [];
    $d = json_decode($raw, true);
    if (!is_array($d)) reply(400, ['error' => 'Body must be JSON.']);
    return $d;
}

function b64url_decode(string $s): string {
    $s = strtr($s, '-_', '+/');
    $pad = strlen($s) % 4;
    if ($pad) $s .= str_repeat('=', 4 - $pad);
    $out = base64_decode($s, true);
    return $out === false ? '' : $out;
}

function http_get(string $url): ?string {
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 15, CURLOPT_FOLLOWLOCATION => true, CURLOPT_USERAGENT => 'TaskOra-API']);
        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return ($body !== false && $code === 200) ? $body : null;
    }
    $body = @file_get_contents($url, false, stream_context_create(['http' => ['timeout' => 15, 'header' => "User-Agent: TaskOra-API\r\n"]]));
    return $body === false ? null : $body;
}

/** Google's public keys that sign Firebase ID tokens (cached for 1 hour). */
function google_certs(bool $force = false): array {
    $cacheFile = __DIR__ . '/cache/firebase-certs.json';
    if (!$force && is_file($cacheFile) && filemtime($cacheFile) > time() - 3600) {
        $c = json_decode((string) file_get_contents($cacheFile), true);
        if (is_array($c) && $c) return $c;
    }
    $body = http_get('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
    $c = $body ? json_decode($body, true) : null;
    if (!is_array($c) || !$c) reply(503, ['error' => 'Could not download Google sign-in keys. Is outgoing internet allowed on this hosting?']);
    @file_put_contents($cacheFile, json_encode($c), LOCK_EX);
    return $c;
}

function auth_token(): string {
    $h = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    if ($h === '') {
        $a = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        if ($a === '' && function_exists('getallheaders')) {
            foreach (getallheaders() as $k => $v) if (strcasecmp($k, 'Authorization') === 0) $a = $v;
        }
        if (stripos($a, 'Bearer ') === 0) $h = trim(substr($a, 7));
    }
    return $h;
}

/** Checks the Firebase ID token the app sends and returns the user's id. */
function require_user(): string {
    $jwt = auth_token();
    $parts = explode('.', $jwt);
    if (count($parts) !== 3) reply(401, ['error' => 'Not signed in.']);
    [$h64, $p64, $s64] = $parts;
    $header = json_decode(b64url_decode($h64), true);
    $p = json_decode(b64url_decode($p64), true);
    $sig = b64url_decode($s64);
    if (!is_array($header) || !is_array($p) || ($header['alg'] ?? '') !== 'RS256' || empty($header['kid'])) reply(401, ['error' => 'Bad token.']);

    $certs = google_certs();
    if (!isset($certs[$header['kid']])) $certs = google_certs(true);
    if (!isset($certs[$header['kid']])) reply(401, ['error' => 'Unknown signing key.']);
    $key = openssl_pkey_get_public($certs[$header['kid']]);
    if ($key === false || openssl_verify("$h64.$p64", $sig, $key, OPENSSL_ALGO_SHA256) !== 1) reply(401, ['error' => 'Token signature is not valid.']);

    $project = (string) cfg('firebase_project_id');
    $now = time();
    if (($p['aud'] ?? '') !== $project) reply(401, ['error' => 'Token is for another Firebase project. Check firebase_project_id in config.php.']);
    if (($p['iss'] ?? '') !== 'https://securetoken.google.com/' . $project) reply(401, ['error' => 'Wrong token issuer.']);
    if ((int) ($p['exp'] ?? 0) < $now - 60) reply(401, ['error' => 'Token expired.', 'code' => 'expired']);
    if ((int) ($p['iat'] ?? 0) > $now + 300) reply(401, ['error' => 'Token from the future. Check the server clock.']);
    $uid = (string) ($p['sub'] ?? '');
    if ($uid === '' || strlen($uid) > 128) reply(401, ['error' => 'Token has no user.']);
    $GLOBALS['token_payload'] = $p;
    return $uid;
}

const COLLECTIONS = ['projects', 'todos', 'notes', 'sections', 'notices', 'meta'];

/** Email and name from the signed-in user's token. */
function token_user(): array {
    $p = $GLOBALS['token_payload'] ?? [];
    return ['email' => (string) ($p['email'] ?? ''), 'name' => (string) ($p['name'] ?? '')];
}

/** Creates tables added after the first version (safe to call often). */
function ensure_tables(): void {
    db()->exec('CREATE TABLE IF NOT EXISTS taskora_files (
      id         CHAR(40)     NOT NULL PRIMARY KEY,
      uid        VARCHAR(128) NOT NULL,
      name       VARCHAR(255) NOT NULL,
      mime       VARCHAR(127) NOT NULL,
      size       BIGINT       NOT NULL,
      created_at BIGINT       NOT NULL,
      KEY by_user (uid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');
}

function files_dir(): string {
    $d = __DIR__ . '/files';
    if (!is_dir($d)) @mkdir($d, 0755, true);
    if (!is_file("$d/.htaccess")) @file_put_contents("$d/.htaccess", "Require all denied\n");
    return $d;
}

/**
 * Keeps this folder up to date with server/taskora-api in the GitHub repo.
 * Runs at most every 6 hours, after the reply has been sent. config.php is never touched.
 */
function maybe_self_update(): void {
    $repo = (string) (cfg('update_repo') ?? 'rabbyhossain2927/taskora');
    if ($repo === '' || cfg('auto_update') === false) return;
    $state = __DIR__ . '/cache/update-state.json';
    $st = is_file($state) ? (json_decode((string) file_get_contents($state), true) ?: []) : [];
    if (time() - (int) ($st['checked'] ?? 0) < 6 * 3600) return;
    $st['checked'] = time();
    @file_put_contents($state, json_encode($st), LOCK_EX);

    $list = http_get("https://api.github.com/repos/$repo/contents/server/taskora-api?ref=main");
    $items = $list ? json_decode($list, true) : null;
    if (!is_array($items)) return;
    $shas = $st['shas'] ?? [];
    $changed = [];
    foreach ($items as $it) {
        $name = (string) ($it['name'] ?? '');
        if (($it['type'] ?? '') !== 'file' || $name === 'config.php' || !preg_match('/^[A-Za-z0-9._-]+$/', $name)) continue;
        if (($shas[$name] ?? '') === ($it['sha'] ?? '') && is_file(__DIR__ . "/$name")) continue;
        $body = http_get((string) $it['download_url']);
        if ($body === null || $body === '') continue;
        if (substr($name, -4) === '.php' && strpos($body, '<?php') !== 0) continue; // sanity check
        $tmp = __DIR__ . "/.$name.tmp";
        if (@file_put_contents($tmp, $body) === false) continue;
        if (@rename($tmp, __DIR__ . "/$name")) { $shas[$name] = $it['sha']; $changed[] = $name; }
    }
    $st['shas'] = $shas;
    if ($changed) { $st['updated'] = time(); $st['last_changed'] = $changed; }
    @file_put_contents($state, json_encode($st), LOCK_EX);
}
