<?php
// POST {since, changes:[{col,id,data,deleted}]}
// -> saves the phone's changes, then returns everything that changed on the server since `since`.
declare(strict_types=1);
require __DIR__ . '/lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405, ['error' => 'Use POST.']);
$uid = require_user();
$in = json_input();
// Position from the last sync: "time|collection|id" (items are sorted by those three).
$sinceRaw = (string) ($in['since'] ?? '0');
$sp = explode('|', $sinceRaw, 3);
$sinceT = max(0, (int) $sp[0]);
$sinceC = (string) ($sp[1] ?? '');
$sinceI = (string) ($sp[2] ?? '');
$changes = $in['changes'] ?? [];
if (!is_array($changes)) reply(400, ['error' => 'changes must be a list.']);
if (count($changes) > (int) cfg('max_changes_per_request')) reply(413, ['error' => 'Too many changes in one request.']);

$pdo = db();
$saved = 0;
if ($changes) {
    $now = now_ms();
    $up = $pdo->prepare(
        'INSERT INTO taskora_docs (uid, col, doc_id, data, deleted, updated_at) VALUES (?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE data = VALUES(data), deleted = VALUES(deleted), updated_at = VALUES(updated_at)'
    );
    $pdo->beginTransaction();
    try {
        foreach ($changes as $c) {
            $col = (string) ($c['col'] ?? '');
            $id = (string) ($c['id'] ?? '');
            if (!in_array($col, COLLECTIONS, true) || !preg_match('/^[A-Za-z0-9_-]{1,64}$/', $id)) continue;
            $deleted = !empty($c['deleted']) || !isset($c['data']);
            $data = $deleted ? null : json_encode($c['data'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            if ($data !== null && strlen($data) > (int) cfg('max_doc_bytes')) continue;
            $up->execute([$uid, $col, $id, $data, $deleted ? 1 : 0, $now]);
            $saved++;
        }
        $pdo->commit();
    } catch (Throwable $e) {
        $pdo->rollBack();
        reply(500, ['error' => 'Could not save changes.']);
    }
}

$limit = (int) cfg('page_size');
$q = $pdo->prepare(
    'SELECT col, doc_id, data, deleted, updated_at FROM taskora_docs
     WHERE uid = ? AND (updated_at > ? OR (updated_at = ? AND (col > ? OR (col = ? AND doc_id > ?))))
     ORDER BY updated_at ASC, col ASC, doc_id ASC LIMIT ' . ($limit + 1)
);
$q->execute([$uid, $sinceT, $sinceT, $sinceC, $sinceC, $sinceI]);
$rows = $q->fetchAll();
$more = count($rows) > $limit;
if ($more) array_pop($rows);

$out = [];
$last = null;
foreach ($rows as $r) {
    $out[] = [
        'col' => $r['col'],
        'id' => $r['doc_id'],
        'deleted' => (bool) $r['deleted'],
        'data' => $r['deleted'] ? null : json_decode((string) $r['data'], true),
    ];
    $last = $r;
}
if ($more) {
    // More pages: continue exactly after the last item sent.
    $cursor = $last['updated_at'] . '|' . $last['col'] . '|' . $last['doc_id'];
} else {
    // Done: next time start a little before "now", so a save that was still in progress
    // on another phone is never missed. Getting a few items twice is harmless.
    $lastT = $last ? (int) $last['updated_at'] : $sinceT;
    $cursor = (string) max($sinceT, min($lastT, now_ms() - 10000));
}

reply(200, ['saved' => $saved, 'changes' => $out, 'cursor' => $cursor, 'more' => $more, 'serverTime' => now_ms()]);
