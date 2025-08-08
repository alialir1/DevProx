<?php
declare(strict_types=1);

/**
 * Lightweight Telegram Bot Webhook helper (no external deps)
 */

/**
 * Perform a Telegram Bot API request via cURL.
 *
 * @param string $botToken Bot token in the form 123456:ABC...
 * @param string $method Telegram API method (e.g., setWebhook)
 * @param array $params POST fields. If any value is CURLFile, a multipart request is sent
 * @param array $extraHeaders Additional headers (e.g., custom UA)
 * @return array Decoded JSON response (plus http_code when available)
 */
function tg_api_request(string $botToken, string $method, array $params = [], array $extraHeaders = []): array
{
    $apiBaseUrl = "https://api.telegram.org/bot{$botToken}/{$method}";

    $curlHandle = curl_init($apiBaseUrl);
    if ($curlHandle === false) {
        return [
            'ok' => false,
            'description' => 'Failed to initialize cURL',
        ];
    }

    $headers = array_merge([
        'Accept: application/json',
        'Expect:', // avoid 100-continue delays
        'User-Agent: TelegramWebhookHelper/1.0',
    ], $extraHeaders);

    curl_setopt_array($curlHandle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $params,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 30,
    ]);

    $rawResponse = curl_exec($curlHandle);
    $errno = curl_errno($curlHandle);
    $error = curl_error($curlHandle);
    $httpCode = (int) curl_getinfo($curlHandle, CURLINFO_RESPONSE_CODE);

    curl_close($curlHandle);

    if ($errno !== 0) {
        return [
            'ok' => false,
            'description' => 'cURL error: ' . $error,
            'error_code' => $errno,
            'http_code' => $httpCode,
        ];
    }

    $decoded = is_string($rawResponse) ? json_decode($rawResponse, true) : null;

    if (!is_array($decoded)) {
        return [
            'ok' => false,
            'description' => 'Invalid JSON response from Telegram',
            'response_raw' => $rawResponse,
            'http_code' => $httpCode,
        ];
    }

    // Ensure http_code is present for diagnostics
    if (!array_key_exists('http_code', $decoded)) {
        $decoded['http_code'] = $httpCode;
    }

    return $decoded;
}

/**
 * Set Telegram webhook.
 *
 * @param string $botToken
 * @param string $webhookUrl Public HTTPS URL accessible by Telegram
 * @param array $options Optional settings:
 *  - secret_token (string)                   Secret token Telegram will echo in header
 *  - max_connections (int)                   1..100, default 40
 *  - drop_pending_updates (bool)             Whether to drop pending updates
 *  - allowed_updates (array|string)          Update types; array or JSON string
 *  - ip_address (string)                     Fixed IP address for DNS resolution
 *  - certificate_path (string)               Path to public key certificate file
 * @return array Telegram API response
 */
function setTelegramWebhook(string $botToken, string $webhookUrl, array $options = []): array
{
    $payload = [
        'url' => $webhookUrl,
    ];

    if (isset($options['secret_token']) && $options['secret_token'] !== '') {
        $payload['secret_token'] = (string) $options['secret_token'];
    }
    if (isset($options['max_connections'])) {
        $payload['max_connections'] = (int) $options['max_connections'];
    }
    if (isset($options['drop_pending_updates'])) {
        $payload['drop_pending_updates'] = (bool) $options['drop_pending_updates'];
    }
    if (isset($options['allowed_updates'])) {
        $allowed = $options['allowed_updates'];
        // Telegram expects JSON-serialized array if provided as a form field
        if (is_array($allowed)) {
            $payload['allowed_updates'] = json_encode(array_values($allowed));
        } else {
            $payload['allowed_updates'] = (string) $allowed; // assume already JSON string
        }
    }
    if (isset($options['ip_address']) && $options['ip_address'] !== '') {
        $payload['ip_address'] = (string) $options['ip_address'];
    }

    if (isset($options['certificate_path']) && $options['certificate_path'] !== '') {
        $certificatePath = (string) $options['certificate_path'];
        if (is_readable($certificatePath)) {
            $payload['certificate'] = new CURLFile($certificatePath);
        } else {
            return [
                'ok' => false,
                'description' => 'Certificate file not readable: ' . $certificatePath,
            ];
        }
    }

    return tg_api_request($botToken, 'setWebhook', $payload);
}

/**
 * Delete Telegram webhook.
 *
 * @param string $botToken
 * @param bool $dropPendingUpdates
 * @return array
 */
function deleteTelegramWebhook(string $botToken, bool $dropPendingUpdates = false): array
{
    $payload = [
        'drop_pending_updates' => $dropPendingUpdates,
    ];

    return tg_api_request($botToken, 'deleteWebhook', $payload);
}

/**
 * Get current webhook info.
 *
 * @param string $botToken
 * @return array
 */
function getTelegramWebhookInfo(string $botToken): array
{
    // GET not supported by our helper; Telegram accepts POST with empty body as well
    return tg_api_request($botToken, 'getWebhookInfo');
}

/**
 * Convenience: send a text message (useful to test the webhook handler).
 *
 * @param string $botToken
 * @param int|string $chatId
 * @param string $text
 * @param array $options Optional Telegram sendMessage fields
 * @return array
 */
function sendTelegramMessage(string $botToken, int|string $chatId, string $text, array $options = []): array
{
    $payload = array_merge($options, [
        'chat_id' => $chatId,
        'text' => $text,
    ]);

    return tg_api_request($botToken, 'sendMessage', $payload);
}