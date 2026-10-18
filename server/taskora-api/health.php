<?php
// Open this in a browser to check the setup: https://your-site.com/taskora-api/health.php
declare(strict_types=1);
require __DIR__ . '/lib.php';

$checks = [];
$checks['server_version'] = SERVER_VERSION;
$checks['php'] = PHP_VERSION;
$checks['php_ok'] = version_compare(PHP_VERSION, '7.4.0', '>=');
$checks['openssl'] = function_exists('openssl_verify');
$checks['config'] = is_file(__DIR__ . '/config.php');
$checks['firebase_project_id'] = $checks['config'] ? (string) cfg('firebase_project_id') : '';
try {
    db()->query('SELECT 1 FROM taskora_docs LIMIT 1');
    $checks['database'] = true;
} catch (Throwable $e) {
    $checks['database'] = false;
    $checks['database_hint'] = 'Table missing? Open install.php once, or import schema.sql in phpMyAdmin.';
}
$checks['cache_writable'] = is_writable(__DIR__ . '/cache');
$checks['files_writable'] = is_writable(files_dir());
$checks['upload_max'] = ini_get('upload_max_filesize') . ' / ' . ini_get('post_max_size');
$us = __DIR__ . '/cache/update-state.json';
$checks['last_auto_update'] = is_file($us) ? (json_decode((string) file_get_contents($us), true)['updated'] ?? null) : null;
try { ensure_tables(); } catch (Throwable $e) {}
$checks['google_keys'] = (bool) http_get('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
$checks['https'] = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
$checks['all_good'] = $checks['php_ok'] && $checks['openssl'] && $checks['config'] && $checks['database'] && $checks['cache_writable'] && $checks['google_keys'] && $checks['firebase_project_id'] !== '' && $checks['firebase_project_id'] !== 'your-firebase-project-id';
$ws = __DIR__ . '/cache/web-state.json';
$checks['website_updated'] = is_file($ws) ? (json_decode((string) file_get_contents($ws), true)['updated'] ?? null) : null;
$checks['zip_extension'] = class_exists('ZipArchive');
register_shutdown_function('maybe_self_update');
register_shutdown_function('maybe_web_update');
reply(200, ['app' => 'TaskOra sync API', 'checks' => $checks]);
