# DiDIt KYC Edge Function

This Supabase Edge Function handles secure communication between the CareSync app and DiDIt's KYC verification API.

## Features

- ✅ Secure API key management (never exposed to client)
- ✅ User authentication validation
- ✅ Comprehensive error handling
- ✅ Audit trail logging
- ✅ CORS support

## Environment Variables Required

Set these in your Supabase project:

```
DIDIT_APP_ID=your_app_id_here
DIDIT_API_KEY=your_api_key_here
```

## Deployment

```bash
supabase functions deploy didit-kyc
```

## Testing

```bash
# Local testing
supabase functions serve didit-kyc

# Test with curl
curl -X POST http://localhost:54321/functions/v1/didit-kyc \
  -H "Authorization: Bearer YOUR_SUPABASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"features": ["id_document", "face_match", "liveness"]}'
```

## API

### Request

```
POST /functions/v1/didit-kyc
Headers:
  Authorization: Bearer <supabase_access_token>
  Content-Type: application/json

Body (optional):
{
  "callback_url": "https://caresync.app/verify-callback",
  "features": ["id_document", "face_match", "liveness"]
}
```

### Success Response

```json
{
  "success": true,
  "url": "https://verification.didit.me/session/...",
  "session_id": "..."
}
```

### Error Response

```json
{
  "error": "Error type",
  "details": "Error details",
  "status_code": 400
}
```

## Logs

View logs in Supabase Dashboard under Edge Functions > didit-kyc

Look for:
- `[DIDIT-KYC] Initializing session for user: ...`
- `[DIDIT-KYC] Session created successfully: ...`
- `[DIDIT-KYC] DiDIt API error: ...`
