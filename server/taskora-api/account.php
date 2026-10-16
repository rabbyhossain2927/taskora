<?php
// POST {action:"delete"} -> removes all of this user's synced data from the server.
declare(strict_types=1);
require __DIR__ . '/lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405, ['error' => 'Use POST.']);
$uid = require_user();
$in = json_input();
if (($in['action'] ?? '') === 'delete') {
    $st = db()->prepare('DELETE FROM taskora_docs WHERE uid = ?');
    $st->execute([$uid]);
    reply(200, ['deleted' => $st->rowCount()]);
}
if (($in['action'] ?? '') === 'stats') {
    $st = db()->prepare('SELECT col, COUNT(*) n FROM taskora_docs WHERE uid = ? AND deleted = 0 GROUP BY col');
    $st->execute([$uid]);
    reply(200, ['counts' => $st->fetchAll()]);
}
reply(400, ['error' => 'Unknown action.']);
