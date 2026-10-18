<?php
// POST {"url":"https://..."} -> {title, description, image}
// Link previews for the website version (browsers can't read other sites directly).
declare(strict_types=1);
require __DIR__ . '/lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405, ['error' => 'Use POST.']);
require_user();
$url = trim((string) (json_input()['url'] ?? ''));
$p = parse_url($url);
if (!$p || !in_array(strtolower($p['scheme'] ?? ''), ['http', 'https'], true) || empty($p['host'])) reply(400, ['error' => 'Not a web link.']);

// Never fetch addresses inside the server's own network.
$ips = @gethostbynamel($p['host']) ?: [];
if (!$ips) reply(200, ['title' => '', 'description' => '', 'image' => '']);
foreach ($ips as $ip) {
    if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) reply(400, ['error' => 'Not allowed.']);
}

$cache = __DIR__ . '/cache/preview-' . sha1($url) . '.json';
if (is_file($cache) && filemtime($cache) > time() - 7 * 86400) reply(200, json_decode((string) file_get_contents($cache), true) ?: []);

$html = '';
if (function_exists('curl_init')) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 6, CURLOPT_FOLLOWLOCATION => true, CURLOPT_MAXREDIRS => 3,
        CURLOPT_PROTOCOLS => CURLPROTO_HTTP | CURLPROTO_HTTPS, CURLOPT_USERAGENT => 'Mozilla/5.0 TaskOra',
        CURLOPT_RANGE => '0-524288',
    ]);
    $html = (string) curl_exec($ch);
    curl_close($ch);
}
$html = substr($html, 0, 524288);
$meta = function (string $prop) use ($html): string {
    if (preg_match('/<meta[^>]+(?:property|name)=["\']' . preg_quote($prop, '/') . '["\'][^>]*content=["\']([^"\']*)["\']/i', $html, $m)
        || preg_match('/<meta[^>]+content=["\']([^"\']*)["\'][^>]*(?:property|name)=["\']' . preg_quote($prop, '/') . '["\']/i', $html, $m)) {
        return trim(html_entity_decode($m[1], ENT_QUOTES | ENT_HTML5));
    }
    return '';
};
$title = $meta('og:title');
if ($title === '' && preg_match('/<title[^>]*>([^<]*)<\/title>/i', $html, $m)) $title = trim(html_entity_decode($m[1], ENT_QUOTES | ENT_HTML5));
$desc = $meta('og:description') ?: $meta('description');
$img = $meta('og:image');
if ($img !== '' && strpos($img, '//') === 0) $img = ($p['scheme'] ?? 'https') . ':' . $img;
elseif ($img !== '' && $img[0] === '/') $img = $p['scheme'] . '://' . $p['host'] . $img;
$out = ['title' => mb_substr($title, 0, 300), 'description' => mb_substr($desc, 0, 500), 'image' => $img];
@file_put_contents($cache, json_encode($out));
reply(200, $out);
