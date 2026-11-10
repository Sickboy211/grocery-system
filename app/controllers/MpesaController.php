<?php
/**
 * Daraja STK Push integration placeholder.
 * No request is sent until credentials and callback verification are configured.
 * Keep secrets in environment/config outside version control when completing it.
 */
final class MpesaController
{
    // TODO: set these from protected configuration, never from a public view.
    private const CONSUMER_KEY = 'YOUR_DARAJA_CONSUMER_KEY';
    private const CONSUMER_SECRET = 'YOUR_DARAJA_CONSUMER_SECRET';
    private const SHORT_CODE = 'YOUR_BUSINESS_SHORT_CODE';
    private const PASSKEY = 'YOUR_STK_PASSKEY';
    private const CALLBACK_URL = 'https://YOUR_PUBLIC_HOST/mpesa/callback';

    /** Build a request only after credentials, HTTPS callback and phone validation exist. */
    public static function startStkPush(string $phone, int $amount, string $accountReference): array
    {
        if (self::CONSUMER_KEY === 'YOUR_DARAJA_CONSUMER_KEY') {
            return ['status' => 'pending', 'message' => 'Daraja credentials are not configured.'];
        }

        // TODO: obtain OAuth token, generate timestamp/password, then POST the
        // STK Push payload with PHP cURL. Persist CheckoutRequestID and amount.
        // Never mark a subscription paid based on the browser response.
        return ['status' => 'pending', 'message' => 'Complete Daraja request and callback handling.'];
    }

    /** Callback must validate transaction result and match the pending database row. */
    public static function handleCallback(array $payload): void
    {
        // TODO: validate callback fields against the stored CheckoutRequestID,
        // amount and phone; use a database transaction before granting Pro.
    }
}
