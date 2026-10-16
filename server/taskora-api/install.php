<?php
// Open once in a browser to create the table, then DELETE this file.
declare(strict_types=1);
require __DIR__ . '/lib.php';
try {
    db()->exec((string) file_get_contents(__DIR__ . '/schema.sql'));
    reply(200, ['ok' => true, 'message' => 'Table created. Now delete install.php from the server.']);
} catch (Throwable $e) {
    reply(500, ['ok' => false, 'error' => $e->getMessage()]);
}
