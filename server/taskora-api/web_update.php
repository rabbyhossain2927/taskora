<?php
// Updates the TaskOra website from GitHub right away (GitHub calls this after each build).
// Safe to open in a browser: it only installs the official build from the TaskOra GitHub repo.
declare(strict_types=1);
require __DIR__ . '/lib.php';

$res = maybe_web_update(true);
reply(200, ['web_root' => web_root()] + $res);
