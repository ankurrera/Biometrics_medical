# DiDIt KYC Integration - Backend Implementation Guide

## Problem Fixed

**Original Issue:**
- Frontend was directly calling DiDIt API
- API keys were exposed in the client code
- Error: "Method 'POST' not allowed" from DiDIt API
- CORS issues
- Insecure architecture

**Solution:**
- Implemented backend-first architecture using Supabase Edge Functions
- All DiDIt API calls now go through the backend
- API keys are stored securely on the server
- Proper error handling and logging
- Production-ready and secure

## Architecture

```
┌──────────────┐          ┌──────────────────┐          ┌─────────────┐
│   Flutter    │  HTTPS   │    Supabase      │  HTTPS   │   DiDIt     │
│   Frontend   │ ───────> │  Edge Function   │ ───────> │   API       │
│              │          │  (didit-kyc)     │          │             │
└──────────────┘          └──────────────────┘          └─────────────┘
       │                           │                           │
       │ 1. POST with             │ 2. Validate user         │
       │    auth token            │    & session             │
       │                           │                           │
       │                           │ 3. Call DiDIt API        │
       │                           │    with server keys      │
       │                           │                           │
       │                           │ 4. Log audit trail       │
       │ 5. Return session URL    │                           │
       │    & session ID          │                           │
```

## Components

### 1. Backend: Supabase Edge Function

**File:** `supabase/functions/didit-kyc/index.ts`

**Features:**
- ✅ User authentication validation
- ✅ Secure API key management (server-side only)
- ✅ Error handling with detailed logging
- ✅ CORS headers for cross-origin requests
- ✅ Audit trail logging
- ✅ Comprehensive error responses

**Endpoint:** `https://[your-project].supabase.co/functions/v1/didit-kyc`

**Request:**
```json
POST /functions/v1/didit-kyc
Headers:
  Authorization: Bearer <supabase_access_token>
  Content-Type: application/json

Body:
{
  "callback_url": "https://caresync.app/verify-callback",  // optional
  "features": ["id_document", "face_match", "liveness"]    // optional
}
```

**Success Response:**
```json
{
  "success": true,
  "url": "https://verification.didit.me/session/abc123...",
  "session_id": "abc123..."
}
```

**Error Response:**
```json
{
  "error": "Error type",
  "details": "Detailed error message",
  "status_code": 400
}
```

### 2. Frontend: Flutter KYC Service

**File:** `lib/services/kyc_service.dart`

**Changes:**
- ✅ Calls backend Edge Function instead of DiDIt directly
- ✅ Uses Supabase authentication token
- ✅ Enhanced error handling and logging
- ✅ No API keys exposed to client

**Usage:**
```dart
final kycService = KYCService.instance;

try {
  final sessionUrl = await kycService.createDiditSession();
  if (sessionUrl != null) {
    // Open WebView with sessionUrl
    await _openVerificationWebView(sessionUrl);
  }
} catch (e) {
  // Handle error
  print('KYC Error: $e');
}
```

### 3. Environment Configuration

**File:** `lib/core/config/env_config.dart`

**Changes:**
- ❌ Removed hardcoded DiDIt credentials from frontend
- ✅ Added comments about backend credential management

## Deployment Instructions

### Step 1: Set Environment Variables in Supabase

1. Go to your Supabase Dashboard
2. Navigate to **Settings** → **Edge Functions**
3. Add the following environment variables:

```env
DIDIT_APP_ID=c8d23e40-b59d-43d1-9e82-6597b158adea
DIDIT_API_KEY=BzuGk-BYOedLezdMHI6WAFDmrm8bSG3TYO526UuZVms
```

### Step 2: Deploy the Edge Function

```bash
# Login to Supabase
supabase login

# Link your project
supabase link --project-ref [your-project-ref]

# Deploy the function
supabase functions deploy didit-kyc

# Test the function
supabase functions serve didit-kyc
```

### Step 3: Update Frontend Code

The frontend code has already been updated. Just ensure you:

1. Run `flutter pub get` to ensure all dependencies are installed
2. Rebuild your app:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Testing

### Test Backend Function

```bash
# Test with curl (replace with your token and URL)
curl -X POST \
  https://[your-project].supabase.co/functions/v1/didit-kyc \
  -H "Authorization: Bearer [your-supabase-token]" \
  -H "Content-Type: application/json" \
  -d '{"features": ["id_document", "face_match", "liveness"]}'
```

### Test Frontend Flow

1. Login to the app
2. Navigate to KYC verification screen
3. Click "Start Face Scan"
4. Verify the WebView opens with DiDIt session
5. Complete the verification flow
6. Check the callback is handled correctly

### Debugging

Check logs in Supabase Dashboard:
1. Go to **Edge Functions** → **didit-kyc**
2. View logs to see:
   - `[DIDIT-KYC] Initializing session for user: <user_id>`
   - `[DIDIT-KYC] Creating DiDIt session with features: ...`
   - `[DIDIT-KYC] DiDIt API response status: 200`
   - `[DIDIT-KYC] Session created successfully: <session_id>`

Check Flutter logs:
1. Run app with `flutter run`
2. Look for:
   - `[KYC] Creating DiDIt session via backend for user: <user_id>`
   - `[KYC] Backend response status: 200`
   - `[KYC] Session created successfully: <session_id>`

## Error Handling

### Common Errors and Solutions

1. **"Missing authorization header"**
   - Ensure user is logged in
   - Check Supabase session is active
   - Verify auth token is being sent

2. **"DiDIt credentials not configured"**
   - Set DIDIT_APP_ID and DIDIT_API_KEY in Supabase
   - Redeploy the Edge Function
   - Restart Edge Function if needed

3. **"Method POST not allowed"**
   - This should be fixed by using correct endpoint
   - Verify endpoint URL in Edge Function: `https://verification.didit.me/api/v3/sessions`
   - Check DiDIt API documentation for any changes

4. **CORS errors**
   - CORS headers are already configured
   - Ensure OPTIONS requests are handled
   - Check browser console for specific CORS issues

## Security Best Practices

✅ **API keys are server-side only**
- DiDIt credentials never exposed to client
- Stored as environment variables in Supabase

✅ **User authentication required**
- Edge Function validates Supabase auth token
- Only authenticated users can create sessions

✅ **Audit trail logging**
- All KYC session creations are logged
- User ID and session ID tracked

✅ **Error handling**
- Detailed error messages for debugging
- Generic errors to client for security

✅ **No direct client-to-DiDIt communication**
- All traffic routed through backend
- Backend controls all API interactions

## DiDIt API Integration Details

### Correct Endpoint Format

According to DiDIt API v3 documentation:
- **Endpoint:** `https://verification.didit.me/api/v3/sessions`
- **Method:** POST (to create a new session)
- **Headers:**
  - `Authorization: Bearer <API_KEY>`
  - `Content-Type: application/json`
  - `X-App-Id: <APP_ID>`

### Request Body Schema

```typescript
{
  vendor_data: string;      // User identifier (e.g., user ID)
  callback_url: string;     // URL to redirect after verification
  features: string[];       // Features to enable: ["id_document", "face_match", "liveness"]
}
```

### Response Schema (Success)

```typescript
{
  url: string;              // URL to open in WebView
  session_id: string;       // Unique session identifier
}
```

### Response Schema (Error)

```typescript
{
  detail: string;           // Error message
  message?: string;         // Alternative error message
}
```

## API Flow Diagram

```
User clicks "Start Face Scan"
    ↓
Frontend calls KYCService.createDiditSession()
    ↓
POST /functions/v1/didit-kyc
    ├─ Headers: Authorization Bearer token
    └─ Body: { callback_url, features }
    ↓
Edge Function validates user session
    ↓
Edge Function calls DiDIt API
    ├─ URL: https://verification.didit.me/api/v3/sessions
    ├─ Method: POST
    ├─ Headers: Authorization Bearer + X-App-Id
    └─ Body: { vendor_data, callback_url, features }
    ↓
DiDIt creates verification session
    ↓
Edge Function receives { url, session_id }
    ↓
Edge Function logs to audit trail
    ↓
Edge Function returns { success: true, url, session_id }
    ↓
Frontend opens WebView with url
    ↓
User completes verification in WebView
    ↓
DiDIt redirects to callback_url
    ↓
Frontend detects callback and closes WebView
    ↓
Frontend shows success message
```

## Production Checklist

- [ ] Set DIDIT_APP_ID in Supabase environment
- [ ] Set DIDIT_API_KEY in Supabase environment
- [ ] Deploy didit-kyc Edge Function
- [ ] Remove hardcoded credentials from frontend code
- [ ] Test complete KYC flow end-to-end
- [ ] Verify audit trail logging is working
- [ ] Set up monitoring for Edge Function errors
- [ ] Configure rate limiting if needed
- [ ] Update callback_url to production domain
- [ ] Test error scenarios (network failures, invalid tokens, etc.)
- [ ] Document DiDIt webhook integration if needed
- [ ] Set up alerts for KYC session failures

## Additional Features (Optional Enhancements)

1. **Webhook Handler for DiDIt Callbacks**
   - Create another Edge Function to receive DiDIt webhooks
   - Update KYC status in database automatically
   - Send notifications to users

2. **Rate Limiting**
   - Limit number of KYC session creations per user
   - Prevent abuse and unnecessary API calls

3. **Session Caching**
   - Store active session IDs in database
   - Allow users to resume incomplete sessions

4. **Admin Dashboard**
   - View all KYC sessions
   - Manual verification for edge cases
   - Analytics and reporting

## Support

For issues related to:
- **DiDIt API:** Contact DiDIt support
- **Supabase Edge Functions:** Check Supabase documentation
- **Flutter integration:** Review this guide and logs

## References

- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [DiDIt KYC API Documentation](https://docs.didit.me)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [Flutter WebView Package](https://pub.dev/packages/webview_flutter)
