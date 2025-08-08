<?php
declare(strict_types=1);

require_once __DIR__ . '/telegram_webhook.php';

header('Content-Type: application/json; charset=utf-8');

$botToken     = getenv('TELEGRAM_BOT_TOKEN') ?: ($_GET['token'] ?? '');
$webhookUrl   = getenv('WEBHOOK_URL') ?: ($_GET['url'] ?? '');
$secretToken  = getenv('WEBHOOK_SECRET_TOKEN') ?: ($_GET['secret'] ?? '');
$maxConnEnv   = getenv('MAX_CONNECTIONS') ?: ($_GET['max'] ?? '');
$dropPending  = getenv('DROP_PENDING') ?: ($_GET['drop'] ?? '');
$ipAddress    = getenv('WEBHOOK_IP') ?: ($_GET['ip'] ?? '');
$certPath     = getenv('WEBHOOK_CERT_PATH') ?: ($_GET['cert'] ?? '');
$updatesParam = getenv('ALLOWED_UPDATES') ?: ($_GET['updates'] ?? '');

if ($botToken === '' || $webhookUrl === '') {
    http_response_code(400);
    echo json_encode([
        'ok' => false,
        'description' => 'Missing required parameters: token and url',
        'usage' => '/set_webhook.php?token=BOT_TOKEN&url=HTTPS_URL[&secret=SECRET][&max=40][&drop=0|1][&updates=message,callback_query][&ip=1.2.3.4][&cert=/path/to/cert.pem]',
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    exit;
}

$options = [];
if ($secretToken !== '') {
    $options['secret_token'] = $secretToken;
}
if ($maxConnEnv !== '') {
    $options['max_connections'] = (int) $maxConnEnv;
}
if ($dropPending !== '') {
    $options['drop_pending_updates'] = (bool) (int) $dropPending;
}
if ($ipAddress !== '') {
    $options['ip_address'] = $ipAddress;
}
if ($certPath !== '') {
    $options['certificate_path'] = $certPath;
}
if ($updatesParam !== '') {
    // Accept both JSON array or comma-separated list
    $decoded = json_decode($updatesParam, true);
    if (is_array($decoded)) {
        $options['allowed_updates'] = $decoded;
    } else {
        $options['allowed_updates'] = array_filter(array_map('trim', explode(',', (string) $updatesParam)));
    }
}

$response = setTelegramWebhook($botToken, $webhookUrl, $options);

echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);