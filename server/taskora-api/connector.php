<?php
// TaskOra connector for Claude (MCP server).
// Lets Claude add projects and to-dos to ONE TaskOra account, using a secret link.
//
//   POST connector.php?setup=1   (signed in with the TaskOra token)  -> makes the secret link
//   POST connector.php?setup=off (signed in with the TaskOra token)  -> turns the link off
//   POST connector.php?k=SECRET  (JSON-RPC from Claude)              -> the connector itself
//
// Only a hash of the secret is stored. It writes to taskora_docs the same way sync.php does,
// so the website and the phone app pick the changes up on their next sync.
declare(strict_types=1);
require __DIR__ . '/lib.php';

const MCP_VERSIONS = ['2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05'];
const MCP_DEFAULT_VERSION = '2025-06-18';

function connector_table(): void {
    db()->exec('CREATE TABLE IF NOT EXISTS taskora_connectors (
      uid        VARCHAR(128) NOT NULL PRIMARY KEY,
      key_hash   CHAR(64)     NOT NULL,
      created_at BIGINT       NOT NULL
    )');
}

// ---------- Setup: make or remove the secret link ----------
if (isset($_GET['setup'])) {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405, ['error' => 'Use POST.']);
    $uid = require_user();
    connector_table();
    $pdo = db();
    $pdo->prepare('DELETE FROM taskora_connectors WHERE uid = ?')->execute([$uid]);
    if ($_GET['setup'] === 'off') reply(200, ['connected' => false]);
    $key = bin2hex(random_bytes(24));
    $pdo->prepare('INSERT INTO taskora_connectors (uid, key_hash, created_at) VALUES (?, ?, ?)')
        ->execute([$uid, hash('sha256', $key), now_ms()]);
    $self = 'https://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . strtok((string) ($_SERVER['REQUEST_URI'] ?? '/connector.php'), '?');
    reply(200, ['connected' => true, 'url' => $self . '?k=' . $key]);
}

// ---------- Who is calling? ----------
function connector_uid(): string {
    $key = (string) ($_GET['k'] ?? '');
    if ($key === '') $key = auth_token();
    if (!preg_match('/^[a-f0-9]{48}$/', $key)) reply(401, ['error' => 'Connector key is missing or wrong.']);
    try {
        $q = db()->prepare('SELECT uid FROM taskora_connectors WHERE key_hash = ?');
        $q->execute([hash('sha256', $key)]);
        $uid = $q->fetchColumn();
    } catch (Throwable $e) {
        $uid = false;
    }
    if (!is_string($uid) || $uid === '') reply(401, ['error' => 'Connector key is missing or wrong.']);
    return $uid;
}

// ---------- Small helpers ----------
function tz(): DateTimeZone {
    try { return new DateTimeZone((string) (cfg('connector_timezone') ?: 'Asia/Dhaka')); }
    catch (Throwable $e) { return new DateTimeZone('Asia/Dhaka'); }
}

/** "2026-11-25" or "2026-11-25 17:00" -> milliseconds. A date alone means "that day, no time". */
function to_ms($v, string $field): ?int {
    if ($v === null || $v === '') return null;
    if (!is_string($v) || !preg_match('/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?$/', trim($v), $m)) {
        throw new InvalidArgumentException("$field must look like 2026-11-25 or 2026-11-25 17:00.");
    }
    if (!checkdate((int) $m[2], (int) $m[3], (int) $m[1])) throw new InvalidArgumentException("$field is not a real date.");
    $d = new DateTime(sprintf('%s-%s-%s %s:%s:00', $m[1], $m[2], $m[3], $m[4] ?? '00', $m[5] ?? '00'), tz());
    return $d->getTimestamp() * 1000;
}

function from_ms($ms): ?string {
    if (!is_int($ms) && !is_float($ms)) return null;
    $d = (new DateTime('@' . (int) floor($ms / 1000)))->setTimezone(tz());
    return $d->format('H:i') === '00:00' ? $d->format('Y-m-d') : $d->format('Y-m-d H:i');
}

function uuid4(): string {
    $b = random_bytes(16);
    $b[6] = chr((ord($b[6]) & 0x0f) | 0x40);
    $b[8] = chr((ord($b[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($b), 4));
}

function text_arg(array $a, string $k, int $max, string $default = ''): string {
    $v = $a[$k] ?? $default;
    if (!is_string($v)) throw new InvalidArgumentException("$k must be text.");
    $v = trim($v);
    return function_exists('mb_substr') ? mb_substr($v, 0, $max) : substr($v, 0, $max);
}

function int_arg(array $a, string $k, int $min, int $max, int $default): int {
    if (!isset($a[$k])) return $default;
    if (!is_numeric($a[$k])) throw new InvalidArgumentException("$k must be a number.");
    return max($min, min($max, (int) $a[$k]));
}

function docs(string $uid, string $col): array {
    $q = db()->prepare('SELECT doc_id, data FROM taskora_docs WHERE uid = ? AND col = ? AND deleted = 0');
    $q->execute([$uid, $col]);
    $out = [];
    foreach ($q->fetchAll() as $r) {
        $d = json_decode((string) $r['data'], true);
        if (is_array($d)) $out[(string) $r['doc_id']] = $d;
    }
    return $out;
}

function doc(string $uid, string $col, string $id): ?array {
    if (!preg_match('/^[A-Za-z0-9_-]{1,64}$/', $id)) return null;
    $q = db()->prepare('SELECT data FROM taskora_docs WHERE uid = ? AND col = ? AND doc_id = ? AND deleted = 0');
    $q->execute([$uid, $col, $id]);
    $d = json_decode((string) $q->fetchColumn(), true);
    return is_array($d) ? $d : null;
}

function put_doc(string $uid, string $col, string $id, array $data): void {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if ($json === false || strlen($json) > (int) (cfg('max_doc_bytes') ?: 1000000)) throw new InvalidArgumentException('That item is too big to save.');
    db()->prepare('REPLACE INTO taskora_docs (uid, col, doc_id, data, deleted, updated_at) VALUES (?, ?, ?, ?, 0, ?)')
        ->execute([$uid, $col, $id, $json, now_ms()]);
}

function new_todo(array $t, ?string $projectId, int $now): array {
    $title = text_arg($t, 'title', 300);
    if ($title === '') throw new InvalidArgumentException('Every task needs a title.');
    $subs = [];
    foreach ((array) ($t['subtasks'] ?? []) as $s) {
        if (is_string($s) && trim($s) !== '') $subs[] = ['title' => trim($s), 'done' => false];
    }
    return [
        'title' => $title, 'notes' => text_arg($t, 'notes', 5000), 'projectId' => $projectId,
        'start' => $now, 'deadline' => to_ms($t['deadline'] ?? null, 'Task deadline'),
        'reminder' => to_ms($t['reminder'] ?? null, 'Task reminder'),
        'priority' => int_arg($t, 'priority', 1, 5, 5), 'category' => text_arg($t, 'category', 40, 'work'),
        'done' => false, 'subtasks' => $subs, 'createdAt' => $now, 'completedAt' => null,
    ];
}

function save_tasks(string $uid, $tasks, ?string $projectId): array {
    if (!is_array($tasks)) throw new InvalidArgumentException('tasks must be a list.');
    if (count($tasks) > 100) throw new InvalidArgumentException('At most 100 tasks at a time.');
    $now = now_ms();
    $ready = [];
    foreach ($tasks as $t) {
        if (!is_array($t)) throw new InvalidArgumentException('Each task must be an object with a title.');
        $ready[uuid4()] = new_todo($t, $projectId, $now);
    }
    $out = [];
    foreach ($ready as $id => $data) {
        put_doc($uid, 'todos', $id, $data);
        $out[] = ['id' => $id, 'title' => $data['title'], 'deadline' => from_ms($data['deadline'])];
    }
    return $out;
}

function todo_view(string $id, array $t, array $projects): array {
    $pid = $t['projectId'] ?? null;
    return [
        'id' => $id, 'title' => $t['title'] ?? '', 'done' => !empty($t['done']),
        'deadline' => from_ms($t['deadline'] ?? null), 'priority' => $t['priority'] ?? 5,
        'project_id' => $pid, 'project' => is_string($pid) ? ($projects[$pid]['title'] ?? null) : null,
        'notes' => $t['notes'] ?? '',
    ];
}

// ---------- The tools ----------
function tool_list(): array {
    $date = 'Date as YYYY-MM-DD, or YYYY-MM-DD HH:MM for a set time (TaskOra owner\'s local time).';
    $task = [
        'type' => 'object',
        'properties' => [
            'title' => ['type' => 'string'],
            'notes' => ['type' => 'string'],
            'deadline' => ['type' => 'string', 'description' => $date],
            'reminder' => ['type' => 'string', 'description' => 'Optional phone reminder. ' . $date],
            'priority' => ['type' => 'integer', 'description' => '1 urgent, 2 high, 3 medium, 4 low, 5 none (default).'],
            'category' => ['type' => 'string', 'description' => 'work (default), home, errands, health, study, someday.'],
            'subtasks' => ['type' => 'array', 'items' => ['type' => 'string']],
        ],
        'required' => ['title'],
    ];
    return [
        [
            'name' => 'add_project',
            'description' => 'Create a project in TaskOra, with its tasks (to-dos) in the same call. Use for a big piece of work or a client order broken into small dated steps.',
            'inputSchema' => ['type' => 'object', 'properties' => [
                'title' => ['type' => 'string'],
                'description' => ['type' => 'string', 'description' => 'Brief, client or buyer name, order number, requirements.'],
                'deadline' => ['type' => 'string', 'description' => 'Final deadline. ' . $date],
                'priority' => ['type' => 'integer', 'description' => '1 urgent, 2 high, 3 medium (default), 4 low.'],
                'category' => ['type' => 'string', 'description' => 'client (default), personal, design, dev, marketing, learning.'],
                'platform' => ['type' => 'string', 'enum' => ['direct', 'fiverr', 'upwork'], 'description' => 'Where the order came from; sets the fee TaskOra shows.'],
                'amount' => ['type' => 'number', 'description' => 'Order price before fees.'],
                'currency' => ['type' => 'string', 'description' => 'USD (default), BDT, ...'],
                'tasks' => ['type' => 'array', 'items' => $task],
            ], 'required' => ['title']],
        ],
        [
            'name' => 'add_tasks',
            'description' => 'Add tasks (to-dos) to TaskOra. Give project_id to put them in an existing project, or leave it out for stand-alone to-dos.',
            'inputSchema' => ['type' => 'object', 'properties' => [
                'project_id' => ['type' => 'string'],
                'tasks' => ['type' => 'array', 'items' => $task],
            ], 'required' => ['tasks']],
        ],
        [
            'name' => 'list_projects',
            'description' => 'List TaskOra projects with deadlines and how many tasks are open and done.',
            'inputSchema' => ['type' => 'object', 'properties' => [
                'include_done' => ['type' => 'boolean', 'description' => 'Also show finished projects. Default false.'],
            ]],
            'annotations' => ['readOnlyHint' => true],
        ],
        [
            'name' => 'list_tasks',
            'description' => 'List TaskOra tasks, soonest deadline first. Use due_by with today\'s date to see what is due today or overdue.',
            'inputSchema' => ['type' => 'object', 'properties' => [
                'project_id' => ['type' => 'string'],
                'due_by' => ['type' => 'string', 'description' => 'Only tasks due on or before this day (YYYY-MM-DD).'],
                'include_done' => ['type' => 'boolean', 'description' => 'Also show finished tasks. Default false.'],
            ]],
            'annotations' => ['readOnlyHint' => true],
        ],
        [
            'name' => 'update_task',
            'description' => 'Change one task: mark it done or not done, or change its title, notes, deadline or priority.',
            'inputSchema' => ['type' => 'object', 'properties' => [
                'task_id' => ['type' => 'string'],
                'done' => ['type' => 'boolean'],
                'title' => ['type' => 'string'],
                'notes' => ['type' => 'string'],
                'deadline' => ['type' => 'string', 'description' => $date . ' Empty text removes the deadline.'],
                'priority' => ['type' => 'integer'],
            ], 'required' => ['task_id']],
        ],
        [
            'name' => 'update_project',
            'description' => 'Change one project: mark it done or not done, or change its title, description or deadline.',
            'inputSchema' => ['type' => 'object', 'properties' => [
                'project_id' => ['type' => 'string'],
                'done' => ['type' => 'boolean'],
                'title' => ['type' => 'string'],
                'description' => ['type' => 'string'],
                'deadline' => ['type' => 'string', 'description' => $date . ' Empty text removes the deadline.'],
            ], 'required' => ['project_id']],
        ],
    ];
}

function tool_call(string $uid, string $name, array $a): array {
    switch ($name) {
        case 'add_project':
            $title = text_arg($a, 'title', 300);
            if ($title === '') throw new InvalidArgumentException('The project needs a title.');
            $platform = text_arg($a, 'platform', 20, 'direct');
            if (!in_array($platform, ['direct', 'fiverr', 'upwork'], true)) $platform = 'direct';
            $amount = isset($a['amount']) && is_numeric($a['amount']) ? (float) $a['amount'] : null;
            $now = now_ms();
            $id = uuid4();
            $project = [
                'title' => $title, 'description' => text_arg($a, 'description', 10000),
                'color' => random_int(0, 19), 'icon' => 'work', 'status' => 'todo',
                'priority' => int_arg($a, 'priority', 1, 4, 3), 'category' => text_arg($a, 'category', 40, 'client'),
                'start' => $now, 'deadline' => to_ms($a['deadline'] ?? null, 'Project deadline'), 'reminder' => null,
                'done' => false, 'amount' => $amount, 'currency' => strtoupper(text_arg($a, 'currency', 8, 'USD')),
                'platform' => $platform, 'customFee' => 15, 'createdAt' => $now, 'files' => [],
            ];
            $pdo = db();
            $pdo->beginTransaction();
            try {
                put_doc($uid, 'projects', $id, $project);
                $tasks = save_tasks($uid, $a['tasks'] ?? [], $id);
                $pdo->commit();
            } catch (Throwable $e) {
                $pdo->rollBack();
                throw $e;
            }
            return ['project_id' => $id, 'title' => $title, 'deadline' => from_ms($project['deadline']), 'tasks' => $tasks];

        case 'add_tasks':
            $pid = isset($a['project_id']) && $a['project_id'] !== '' ? (string) $a['project_id'] : null;
            if ($pid !== null && doc($uid, 'projects', $pid) === null) throw new InvalidArgumentException('No project with that project_id. Use list_projects to find it.');
            $pdo = db();
            $pdo->beginTransaction();
            try {
                $tasks = save_tasks($uid, $a['tasks'] ?? null, $pid);
                $pdo->commit();
            } catch (Throwable $e) {
                $pdo->rollBack();
                throw $e;
            }
            return ['project_id' => $pid, 'tasks' => $tasks];

        case 'list_projects':
            $todos = docs($uid, 'todos');
            $out = [];
            foreach (docs($uid, 'projects') as $id => $p) {
                if (!empty($p['done']) && empty($a['include_done'])) continue;
                $open = 0; $done = 0;
                foreach ($todos as $t) {
                    if (($t['projectId'] ?? null) !== $id) continue;
                    if (!empty($t['done'])) $done++; else $open++;
                }
                $out[] = ['id' => $id, 'title' => $p['title'] ?? '', 'done' => !empty($p['done']), 'status' => $p['status'] ?? '',
                    'deadline' => from_ms($p['deadline'] ?? null), 'category' => $p['category'] ?? '',
                    'platform' => $p['platform'] ?? 'direct', 'open_tasks' => $open, 'done_tasks' => $done, '_d' => $p['deadline'] ?? PHP_INT_MAX];
            }
            usort($out, fn($x, $y) => $x['_d'] <=> $y['_d']);
            foreach ($out as &$o) unset($o['_d']);
            return ['projects' => $out];

        case 'list_tasks':
            $projects = docs($uid, 'projects');
            $pid = isset($a['project_id']) && $a['project_id'] !== '' ? (string) $a['project_id'] : null;
            $dueBy = to_ms($a['due_by'] ?? null, 'due_by');
            if ($dueBy !== null) $dueBy += 86400000 - 1;
            $rows = [];
            foreach (docs($uid, 'todos') as $id => $t) {
                if (!empty($t['done']) && empty($a['include_done'])) continue;
                if ($pid !== null && ($t['projectId'] ?? null) !== $pid) continue;
                $d = $t['deadline'] ?? null;
                if ($dueBy !== null && (!is_numeric($d) || $d > $dueBy)) continue;
                $rows[] = [is_numeric($d) ? $d : PHP_INT_MAX, todo_view($id, $t, $projects)];
            }
            usort($rows, fn($x, $y) => $x[0] <=> $y[0]);
            $total = count($rows);
            return ['today' => (new DateTime('now', tz()))->format('Y-m-d'), 'total' => $total, 'tasks' => array_column(array_slice($rows, 0, 200), 1)];

        case 'update_task':
            $id = (string) ($a['task_id'] ?? '');
            $t = doc($uid, 'todos', $id);
            if ($t === null) throw new InvalidArgumentException('No task with that task_id. Use list_tasks to find it.');
            if (array_key_exists('title', $a)) { $v = text_arg($a, 'title', 300); if ($v !== '') $t['title'] = $v; }
            if (array_key_exists('notes', $a)) $t['notes'] = text_arg($a, 'notes', 5000);
            if (array_key_exists('deadline', $a)) $t['deadline'] = to_ms($a['deadline'], 'Task deadline');
            if (array_key_exists('priority', $a)) $t['priority'] = int_arg($a, 'priority', 1, 5, 5);
            if (array_key_exists('done', $a)) {
                $t['done'] = (bool) $a['done'];
                $t['completedAt'] = $t['done'] ? ($t['completedAt'] ?? now_ms()) : null;
            }
            put_doc($uid, 'todos', $id, $t);
            return ['task' => todo_view($id, $t, docs($uid, 'projects'))];

        case 'update_project':
            $id = (string) ($a['project_id'] ?? '');
            $p = doc($uid, 'projects', $id);
            if ($p === null) throw new InvalidArgumentException('No project with that project_id. Use list_projects to find it.');
            if (array_key_exists('title', $a)) { $v = text_arg($a, 'title', 300); if ($v !== '') $p['title'] = $v; }
            if (array_key_exists('description', $a)) $p['description'] = text_arg($a, 'description', 10000);
            if (array_key_exists('deadline', $a)) $p['deadline'] = to_ms($a['deadline'], 'Project deadline');
            if (array_key_exists('done', $a)) {
                $p['done'] = (bool) $a['done'];
                $p['status'] = $p['done'] ? 'complete' : (($p['status'] ?? '') === 'complete' ? 'progress' : ($p['status'] ?? 'todo'));
            }
            put_doc($uid, 'projects', $id, $p);
            return ['project' => ['id' => $id, 'title' => $p['title'] ?? '', 'done' => !empty($p['done']), 'status' => $p['status'] ?? '', 'deadline' => from_ms($p['deadline'] ?? null)]];
    }
    throw new DomainException("Unknown tool: $name");
}

// ---------- JSON-RPC (MCP over HTTP) ----------
function rpc(string $uid, $msg): ?array {
    if (!is_array($msg) || ($msg['jsonrpc'] ?? '') !== '2.0' || !isset($msg['method']) || !is_string($msg['method'])) {
        return ['jsonrpc' => '2.0', 'id' => is_array($msg) ? ($msg['id'] ?? null) : null, 'error' => ['code' => -32600, 'message' => 'Invalid request.']];
    }
    if (!array_key_exists('id', $msg)) return null; // a notification: nothing to answer
    $id = $msg['id'];
    $params = is_array($msg['params'] ?? null) ? $msg['params'] : [];
    $ok = fn($result) => ['jsonrpc' => '2.0', 'id' => $id, 'result' => $result];
    switch ($msg['method']) {
        case 'initialize':
            $v = (string) ($params['protocolVersion'] ?? '');
            return $ok([
                'protocolVersion' => in_array($v, MCP_VERSIONS, true) ? $v : MCP_DEFAULT_VERSION,
                'capabilities' => ['tools' => new stdClass()],
                'serverInfo' => ['name' => 'TaskOra', 'version' => SERVER_VERSION],
                'instructions' => 'TaskOra is the owner\'s project and to-do app. Break big work into small tasks with their own deadlines spread before the final deadline. Show the plan and get a yes before saving. Dates are in the owner\'s local time.',
            ]);
        case 'ping':
            return $ok(new stdClass());
        case 'tools/list':
            return $ok(['tools' => tool_list()]);
        case 'tools/call':
            $text = fn(array $r, bool $err) => $ok(['content' => [['type' => 'text', 'text' => json_encode($r, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)]], 'isError' => $err]);
            try {
                $args = is_array($params['arguments'] ?? null) ? $params['arguments'] : [];
                return $text(tool_call($uid, (string) ($params['name'] ?? ''), $args), false);
            } catch (DomainException $e) {
                return ['jsonrpc' => '2.0', 'id' => $id, 'error' => ['code' => -32602, 'message' => $e->getMessage()]];
            } catch (InvalidArgumentException $e) {
                return $text(['error' => $e->getMessage()], true);
            } catch (Throwable $e) {
                return $text(['error' => 'TaskOra could not save that. Nothing was changed.'], true);
            }
    }
    return ['jsonrpc' => '2.0', 'id' => $id, 'error' => ['code' => -32601, 'message' => 'Method not found.']];
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    reply(405, ['error' => 'This is the TaskOra connector. It only answers POST.']);
}
$uid = connector_uid();
$in = json_decode((string) file_get_contents('php://input'), true);
if ($in === null) reply(400, ['jsonrpc' => '2.0', 'id' => null, 'error' => ['code' => -32700, 'message' => 'Parse error.']]);

if (is_array($in) && $in !== [] && array_keys($in) === range(0, count($in) - 1)) {
    $out = [];
    foreach ($in as $m) { $r = rpc($uid, $m); if ($r !== null) $out[] = $r; }
    if (!$out) { http_response_code(202); exit; }
    http_response_code(200);
    echo json_encode($out, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
$r = rpc($uid, $in);
if ($r === null) { http_response_code(202); exit; }
reply(200, $r);
