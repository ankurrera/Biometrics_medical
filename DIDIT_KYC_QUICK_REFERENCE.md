# DiDIt KYC Integration - Quick Reference

## 🚀 Quick Start (3 Steps)

### 1. Set Environment Variables in Supabase
```bash
# Go to Supabase Dashboard → Settings → Edge Functions → Secrets
DIDIT_APP_ID=your_actual_app_id
DIDIT_API_KEY=your_actual_api_key
```

### 2. Deploy Edge Function
```bash
./deploy-didit-kyc.sh
```

### 3. Configure Frontend (Optional)
```bash
# Edit .env file
DIDIT_CALLBACK_URL=https://caresync.app/verify-callback  # Production
# OR
DIDIT_CALLBACK_URL=http://localhost:3000/verify-callback  # Development
```

## 📋 What Was Fixed

| Issue | Solution |
|-------|----------|
| ❌ "Method POST not allowed" error | ✅ Fixed DiDIt API endpoint |
| ❌ API keys exposed in client | ✅ Moved to backend environment variables |
| ❌ Direct client-to-DiDIt calls | ✅ Backend proxy via Edge Function |
| ❌ CORS issues | ✅ Resolved with backend architecture |
| ❌ Poor error handling | ✅ Comprehensive logging added |

## 🏗️ Architecture

**Before (Insecure)**
```
Flutter App → DiDIt API ❌
(API keys exposed, CORS issues)
```

**After (Secure)**
```
Flutter App → Supabase Edge Function → DiDIt API ✅
(API keys secure, no CORS, production-ready)
```

## 🔍 How to Test

### Backend Test
```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/didit-kyc" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"features": ["id_document", "face_match", "liveness"]}'
```

**Expected Response:**
```json
{
  "success": true,
  "url": "https://verification.didit.me/session/...",
  "session_id": "..."
}
```

### Frontend Test
1. Login to app
2. Go to KYC verification screen
3. Click "Start Face Scan"
4. Check logs:
   ```
   [KYC] Creating DiDIt session via backend...
   [KYC] Backend response status: 200
   [KYC] Session created successfully
   ```

## 📝 Logging

### Backend Logs (Supabase Dashboard)
```
[DIDIT-KYC] Initializing session for user: <user_id>
[DIDIT-KYC] Creating DiDIt session with features: id_document, face_match, liveness
[DIDIT-KYC] DiDIt API response status: 200
[DIDIT-KYC] Session created successfully: <session_id>
```

### Frontend Logs (Flutter Console)
```
[KYC] Creating DiDIt session via backend for user: <user_id>
[KYC] Backend response status: 200
[KYC] Session created successfully: <session_id>
```

## ❌ Common Errors

### "Missing authorization header"
**Fix**: Ensure user is logged in
```dart
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
  // Redirect to login
}
```

### "DiDIt credentials not configured"
**Fix**: Set environment variables in Supabase Dashboard

### CORS errors
**Fix**: Should not occur with backend proxy (if it does, check CORS headers in Edge Function)

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `DIDIT_KYC_FIX_SUMMARY.md` | Complete fix summary with testing |
| `DIDIT_KYC_BACKEND_IMPLEMENTATION.md` | Full implementation guide |
| `DIDIT_KYC_EXAMPLES.md` | Code examples and patterns |
| `supabase/functions/didit-kyc/README.md` | Edge Function documentation |
| `deploy-didit-kyc.sh` | Automated deployment script |

## 🔐 Security Checklist

- [x] API keys stored on backend only
- [x] User authentication required
- [x] All requests validated
- [x] Complete audit trail
- [x] No credentials in version control
- [x] Environment-specific configuration
- [x] Production-ready error handling

## 🎯 Key Files

### Backend
- `supabase/functions/didit-kyc/index.ts` - Edge Function

### Frontend
- `lib/services/kyc_service.dart` - KYC service
- `lib/core/config/env_config.dart` - Configuration

### Config
- `.env.example` - Environment variables template
- `deploy-didit-kyc.sh` - Deployment automation

## 💡 Pro Tips

1. **Development**: Use local callback URL in `.env`
2. **Testing**: Check both backend and frontend logs
3. **Deployment**: Use the deployment script for convenience
4. **Monitoring**: Set up alerts for Edge Function errors
5. **Security**: Rotate API keys regularly

## 📞 Support

- **DiDIt API Issues**: Contact DiDIt support
- **Supabase Issues**: Check Supabase documentation  
- **Integration Help**: Review `DIDIT_KYC_FIX_SUMMARY.md`

## ✅ Success Criteria

You know it's working when:
- ✅ No "Method POST not allowed" errors
- ✅ Backend logs show "Session created successfully"
- ✅ Frontend logs show "Session created successfully"
- ✅ WebView opens with DiDIt verification
- ✅ Callback is handled correctly after verification

## 🔄 Workflow

```
User clicks "Start Face Scan"
    ↓
Frontend calls KYCService.createDiditSession()
    ↓
POST to /functions/v1/didit-kyc (with auth token)
    ↓
Edge Function validates user
    ↓
Edge Function calls DiDIt API (with API keys)
    ↓
DiDIt returns session URL
    ↓
Frontend opens WebView with URL
    ↓
User completes verification
    ↓
DiDIt redirects to callback URL
    ↓
Frontend handles callback
    ↓
Success! ✅
```

---

**Need more details?** See `DIDIT_KYC_FIX_SUMMARY.md` for complete documentation.
