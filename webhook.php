<?php
declare(strict_types=1);

require_once __DIR__ . '/telegram_webhook.php';

// Optional security: verify Telegram secret token header if configured
$expectedSecret = getenv('WEBHOOK_SECRET_TOKEN') ?: '';

function http_get_all_headers_normalized(): array
{
    // Normalize headers to lowercase keys
    $headers = [];
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $key => $value) {
            $headers[strtolower($key)] = $value;
        }
        return $headers;
    }

    foreach ($_SERVER as $key => $value) {
        if (str_starts_with($key, 'HTTP_')) {
            $normalized = strtolower(str_replace('_', '-', substr($key, 5)));
            $headers[$normalized] = $value;
        }
    }
    return $headers;
}

$headers = http_get_all_headers_normalized();
$receivedSecret = $headers['x-telegram-bot-api-secret-token'] ?? '';

if ($expectedSecret !== '' && hash_equals($expectedSecret, (string) $receivedSecret) === false) {
    http_response_code(401);
    echo 'Unauthorized';
    exit;
}

$raw = file_get_contents('php://input') ?: '';
$update = json_decode($raw, true);
if (!is_array($update)) {
    http_response_code(400);
    echo 'Bad Request';
    exit;
}

// Optional: basic echo response to confirm webhook is working
$botToken = getenv('TELEGRAM_BOT_TOKEN') ?: '';

if ($botToken !== '' && isset($update['message']['chat']['id'])) {
    $chatId = $update['message']['chat']['id'];
    $text   = $update['message']['text'] ?? '';

    $replyText = 'Webhook OK';
    if (is_string($text) && $text !== '') {
        $replyText = "You said: " . mb_substr($text, 0, 256);
    }

    // Fire-and-forget; ignore response
    sendTelegramMessage($botToken, $chatId, $replyText);
}

// Always acknowledge to Telegram quickly
http_response_code(200);
echo 'OK';