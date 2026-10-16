<?php
// Files for projects and notes.
//   GET  files.php?id=...                 -> the file (anyone with the 40-character id; ids can't be guessed)
//   POST multipart "file"                 -> upload (max 30 MB, 2 GB per person)
//   POST {"action":"delete","id":"..."}   -> delete your file
//   POST {"action":"usage"}               -> {used, limit}
declare(strict_types=1);
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'GET') define('NO_JSON_HEADER', true);
require __DIR__ . '/lib.php';

const MAX_FILE = 30 * 1024 * 1024;
const QUOTA = 2 * 1024 * 1024 * 1024;

function file_path(string $uid, string $id): string {
    $d = files_dir() . '/' . substr(hash('sha256', $uid), 0, 24);
    if (!is_dir($d)) @mkdir($d, 0755, true);
    return "$d/$id";
}

ensure_tables();
$pdo = db();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $id = (string) ($_GET['id'] ?? '');
    if (!preg_match('/^[a-f0-9]{40}$/', $id)) { http_response_code(404); exit; }
    $st = $pdo->prepare('SELECT uid, name, mime, size FROM taskora_files WHERE id = ?');
    $st->execute([$id]);
    $f = $st->fetch();
    $path = $f ? file_path($f['uid'], $id) : '';
    if (!$f || !is_file($path)) { http_response_code(404); exit; }
    header('Content-Type: ' . $f['mime']);
    header('Content-Length: ' . filesize($path));
    header('Cache-Control: private, max-age=31536000, immutable');
    header('Content-Disposition: inline; filename="' . str_replace('"', '', $f['name']) . '"');
    header('X-Content-Type-Options: nosniff');
    readfile($path);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405, ['error' => 'Use GET or POST.']);
$uid = require_user();

$usedQ = $pdo->prepare('SELECT COALESCE(SUM(size), 0) FROM taskora_files WHERE uid = ?');
$usedQ->execute([$uid]);
$used = (int) $usedQ->fetchColumn();

if (!empty($_FILES['file'])) {
    $u = $_FILES['file'];
    if (($u['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_INI_SIZE || ($u['error'] ?? 0) === UPLOAD_ERR_FORM_SIZE) {
        reply(413, ['error' => 'File is bigger than this server allows (' . ini_get('upload_max_filesize') . ').']);
    }
    if (($u['error'] ?? 1) !== UPLOAD_ERR_OK || !is_uploaded_file($u['tmp_name'])) reply(400, ['error' => 'Upload failed. Try again.']);
    $size = (int) $u['size'];
    if ($size > MAX_FILE) reply(413, ['error' => 'Files can be up to 30 MB.']);
    if ($used + $size > QUOTA) reply(413, ['error' => 'Your 2 GB storage is full. Delete some files first.']);
    $name = preg_replace('/[^\pL\pN ._()-]+/u', '_', (string) ($u['name'] ?? 'file')) ?: 'file';
    $name = mb_substr($name, 0, 200);
    $mime = 'application/octet-stream';
    if (function_exists('finfo_open')) {
        $fi = finfo_open(FILEINFO_MIME_TYPE);
        $mime = (string) (finfo_file($fi, $u['tmp_name']) ?: $mime);
    }
    if ($mime === 'application/octet-stream' || $mime === 'text/plain') {
        $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
        $map = ['png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'gif' => 'image/gif', 'webp' => 'image/webp',
                'heic' => 'image/heic', 'pdf' => 'application/pdf', 'mp4' => 'video/mp4', 'mp3' => 'audio/mpeg', 'txt' => 'text/plain',
                'doc' => 'application/msword', 'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'zip' => 'application/zip'];
        if (isset($map[$ext])) $mime = $map[$ext];
    }
    // Never serve active content from our domain
    if (preg_match('#(html|javascript|xml|svg|x-php)#i', $mime)) $mime = 'application/octet-stream';
    $id = bin2hex(random_bytes(20));
    if (!move_uploaded_file($u['tmp_name'], file_path($uid, $id))) reply(500, ['error' => 'Could not save the file.']);
    $pdo->prepare('INSERT INTO taskora_files (id, uid, name, mime, size, created_at) VALUES (?, ?, ?, ?, ?, ?)')
        ->execute([$id, $uid, $name, $mime, $size, now_ms()]);
    $base = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' ? 'https' : 'https') . '://' . $_SERVER['HTTP_HOST'] . rtrim(dirname($_SERVER['SCRIPT_NAME']), '/');
    reply(200, ['id' => $id, 'name' => $name, 'mime' => $mime, 'size' => $size, 'url' => "$base/files.php?id=$id", 'used' => $used + $size, 'limit' => QUOTA]);
}

$in = json_input();
$action = (string) ($in['action'] ?? '');
if ($action === 'usage') reply(200, ['used' => $used, 'limit' => QUOTA]);
if ($action === 'delete') {
    $id = (string) ($in['id'] ?? '');
    $st = $pdo->prepare('SELECT id FROM taskora_files WHERE id = ? AND uid = ?');
    $st->execute([$id, $uid]);
    if ($st->fetch()) {
        @unlink(file_path($uid, $id));
        $pdo->prepare('DELETE FROM taskora_files WHERE id = ? AND uid = ?')->execute([$id, $uid]);
    }
    reply(200, ['deleted' => true]);
}
reply(400, ['error' => 'Send a file, or an action.']);
