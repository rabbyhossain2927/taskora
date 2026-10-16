<?php
// POST {"name": "...", "message": "..."} -> emails the app owner.
declare(strict_types=1);
require __DIR__ . '/lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') reply(405, ['error' => 'Use POST.']);
$uid = require_user();
$in = json_input();
$name = trim(mb_substr((string) ($in['name'] ?? ''), 0, 100));
$msg = trim(mb_substr((string) ($in['message'] ?? ''), 0, 5000));
$kind = trim(mb_substr((string) ($in['kind'] ?? 'Feedback'), 0, 40));
$appVersion = trim(mb_substr((string) ($in['appVersion'] ?? ''), 0, 40));
if ($msg === '') reply(400, ['error' => 'Please write a message.']);

// At most 5 messages per hour per person
$rl = __DIR__ . '/cache/fb-' . substr(hash('sha256', $uid), 0, 20) . '.json';
$times = is_file($rl) ? (json_decode((string) file_get_contents($rl), true) ?: []) : [];
$times = array_values(array_filter($times, fn($t) => $t > time() - 3600));
if (count($times) >= 5) reply(429, ['error' => 'Thanks! You have sent a lot of messages. Please try again in an hour.']);
$times[] = time();
@file_put_contents($rl, json_encode($times), LOCK_EX);

$user = token_user();
$to = (string) (cfg('feedback_to') ?? 'contact@rabbyhossain.com');
$host = preg_replace('/^www\./', '', (string) ($_SERVER['HTTP_HOST'] ?? 'rabbyhossain.com'));
$clean = fn(string $s) => str_replace(["\r", "\n"], ' ', $s);
$subject = 'TaskOra ' . $clean($kind) . ' from ' . $clean($name !== '' ? $name : ($user['name'] ?: 'a user'));
$body = "Name: $name\nAccount name: {$user['name']}\nEmail: {$user['email']}\nApp version: $appVersion\nType: $kind\nTime: " . gmdate('Y-m-d H:i') . " UTC\n\n$msg\n";
$headers = "From: TaskOra <noreply@$host>\r\nContent-Type: text/plain; charset=UTF-8\r\n";
if (filter_var($user['email'], FILTER_VALIDATE_EMAIL)) $headers .= 'Reply-To: ' . $clean($user['email']) . "\r\n";

$ok = @mail($to, '=?UTF-8?B?' . base64_encode($subject) . '?=', $body, $headers);
// Keep a copy too, in case email is slow or blocked
@file_put_contents(__DIR__ . '/cache/feedback.log', json_encode(['t' => time(), 'uid' => $uid, 'name' => $name, 'email' => $user['email'], 'kind' => $kind, 'msg' => $msg]) . "\n", FILE_APPEND | LOCK_EX);
if (!$ok) reply(500, ['error' => 'Could not send the email right now, but your message was saved.']);
reply(200, ['sent' => true]);
