# DiDIt KYC Integration - Quick Start Examples

## Backend Example: Edge Function Call

The backend Edge Function is automatically called by the Flutter app. However, you can also test it directly:

### Using cURL

```bash
# Get your Supabase access token first (from your logged-in session)
TOKEN="your_supabase_access_token"
PROJECT_URL="https://your-project.supabase.co"

# Create a KYC session
curl -X POST "$PROJECT_URL/functions/v1/didit-kyc" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "callback_url": "https://caresync.app/verify-callback",
    "features": ["id_document", "face_match", "liveness"]
  }'
```

### Using JavaScript/TypeScript

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://your-project.supabase.co',
  'your-anon-key'
)

async function createKYCSession() {
  // Ensure user is logged in
  const { data: { session } } = await supabase.auth.getSession()
  
  if (!session) {
    throw new Error('User not authenticated')
  }

  // Call the Edge Function
  const response = await fetch(
    `https://your-project.supabase.co/functions/v1/didit-kyc`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        callback_url: 'https://caresync.app/verify-callback',
        features: ['id_document', 'face_match', 'liveness']
      })
    }
  )

  const data = await response.json()
  
  if (data.success) {
    console.log('Session URL:', data.url)
    console.log('Session ID:', data.session_id)
    // Open data.url in a WebView or iframe
    return data
  } else {
    throw new Error(`KYC Error: ${data.error} - ${data.details}`)
  }
}
```

## Frontend Example: Flutter

### Simple Usage

```dart
import 'package:caresync/services/kyc_service.dart';

class MyKYCScreen extends StatefulWidget {
  @override
  _MyKYCScreenState createState() => _MyKYCScreenState();
}

class _MyKYCScreenState extends State<MyKYCScreen> {
  final _kycService = KYCService.instance;
  bool _isLoading = false;

  Future<void> _startVerification() async {
    setState(() => _isLoading = true);
    
    try {
      // This automatically calls the backend Edge Function
      final sessionUrl = await _kycService.createDiditSession();
      
      if (sessionUrl != null) {
        // Open the verification URL in a WebView
        await _openKYCWebView(sessionUrl);
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openKYCWebView(String url) async {
    // Use webview_flutter package
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            if (change.url?.contains('verify-callback') == true) {
              // Verification complete
              Navigator.pop(context);
              _handleVerificationComplete();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Identity Verification')),
          body: WebViewWidget(controller: controller),
        ),
      ),
    );
  }

  void _handleVerificationComplete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verification Submitted'),
        content: Text('Your documents are being reviewed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KYC Verification')),
      body: Center(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _startVerification,
          child: _isLoading 
            ? CircularProgressIndicator() 
            : Text('Start Verification'),
        ),
      ),
    );
  }
}
```

### Advanced Usage with Error Handling

```dart
Future<void> startKYCWithErrorHandling() async {
  final kycService = KYCService.instance;
  
  try {
    // Create DiDIt session through backend
    final sessionUrl = await kycService.createDiditSession();
    
    if (sessionUrl == null) {
      throw Exception('No session URL returned');
    }
    
    print('Session URL: $sessionUrl');
    
    // Open WebView with the session URL
    await openKYCWebView(sessionUrl);
    
  } on KYCException catch (e) {
    // Handle KYC-specific errors
    print('KYC Error: $e');
    
    if (e.message.contains('not authenticated')) {
      // Redirect to login
      navigateToLogin();
    } else if (e.message.contains('DiDIt API Error')) {
      // Show user-friendly message
      showErrorDialog('Verification service is temporarily unavailable');
    } else {
      showErrorDialog('Failed to start verification: ${e.message}');
    }
    
  } catch (e) {
    // Handle other errors
    print('Unexpected error: $e');
    showErrorDialog('An unexpected error occurred');
  }
}
```

## Common Integration Patterns

### 1. Check KYC Status Before Starting

```dart
Future<void> checkAndStartKYC() async {
  final kycService = KYCService.instance;
  
  // Check if user already has KYC
  final isVerified = await kycService.isKYCVerified();
  
  if (isVerified) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Already Verified'),
        content: Text('Your identity has been verified.'),
      ),
    );
    return;
  }
  
  // Check existing status
  final kycStatus = await kycService.getKYCStatus();
  
  if (kycStatus?.status == KYCStatus.pending) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verification Pending'),
        content: Text('Your documents are being reviewed.'),
      ),
    );
    return;
  }
  
  // Start new verification
  await startVerification();
}
```

### 2. Handle Verification Callback

```dart
class KYCWebViewScreen extends StatefulWidget {
  final String sessionUrl;
  
  const KYCWebViewScreen({required this.sessionUrl});
  
  @override
  _KYCWebViewScreenState createState() => _KYCWebViewScreenState();
}

class _KYCWebViewScreenState extends State<KYCWebViewScreen> {
  late WebViewController _controller;
  
  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('Loading: $url');
          },
          onPageFinished: (url) {
            print('Loaded: $url');
          },
          onWebResourceError: (error) {
            print('Error: ${error.description}');
            showErrorDialog('Failed to load verification page');
          },
          onUrlChange: (change) {
            final url = change.url ?? '';
            
            // Check for callback URL
            if (url.contains('verify-callback')) {
              // Extract any parameters if needed
              final uri = Uri.parse(url);
              final sessionId = uri.queryParameters['session_id'];
              
              print('Verification complete. Session: $sessionId');
              
              // Close WebView and navigate back
              Navigator.pop(context, true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.sessionUrl));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Identity Verification'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

// Usage
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => KYCWebViewScreen(sessionUrl: sessionUrl),
  ),
);

if (result == true) {
  showSuccessDialog('Verification submitted successfully!');
}
```

### 3. Retry Logic for Network Errors

```dart
Future<String?> createSessionWithRetry({int maxRetries = 3}) async {
  final kycService = KYCService.instance;
  
  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      print('Attempt ${attempt + 1} of $maxRetries');
      
      final sessionUrl = await kycService.createDiditSession();
      
      if (sessionUrl != null) {
        return sessionUrl;
      }
    } catch (e) {
      print('Attempt ${attempt + 1} failed: $e');
      
      if (attempt < maxRetries - 1) {
        // Wait before retrying (exponential backoff)
        final delay = Duration(seconds: (attempt + 1) * 2);
        print('Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      } else {
        // Last attempt failed
        throw Exception('Failed after $maxRetries attempts: $e');
      }
    }
  }
  
  return null;
}
```

## Environment Setup

### Development

1. Create `.env` file in project root:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

2. Ensure DiDIt credentials are set in Supabase Dashboard:
   - Go to Settings → Edge Functions
   - Add `DIDIT_APP_ID` and `DIDIT_API_KEY`

### Production

1. Use production Supabase URL
2. Rotate API keys regularly
3. Monitor Edge Function logs
4. Set up error alerts
5. Update callback URL to production domain

## Troubleshooting

### Error: "User not authenticated"

**Solution:**
```dart
// Ensure user is logged in before calling KYC
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
  // Redirect to login
  Navigator.pushNamed(context, '/login');
  return;
}
```

### Error: "No active session"

**Solution:**
```dart
// Refresh session if needed
final session = await Supabase.instance.client.auth.refreshSession();
if (session == null) {
  // Re-authenticate
  await signInAgain();
}
```

### Error: "DiDIt credentials not configured"

**Solution:**
1. Go to Supabase Dashboard
2. Navigate to Edge Functions
3. Add environment variables:
   - `DIDIT_APP_ID`
   - `DIDIT_API_KEY`
4. Redeploy the function

## Testing

### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:caresync/services/kyc_service.dart';

void main() {
  group('KYCService', () {
    test('createDiditSession returns URL on success', () async {
      // Mock HTTP client
      // Mock Supabase client
      // Test the service
      
      final kycService = KYCService.instance;
      final url = await kycService.createDiditSession();
      
      expect(url, isNotNull);
      expect(url, contains('verification.didit.me'));
    });
    
    test('createDiditSession throws on error', () async {
      // Mock error response
      
      final kycService = KYCService.instance;
      
      expect(
        () => kycService.createDiditSession(),
        throwsA(isA<KYCException>()),
      );
    });
  });
}
```

## Next Steps

1. Deploy the Edge Function to Supabase
2. Test with a real user account
3. Implement callback handling
4. Add webhook integration for automatic status updates
5. Monitor Edge Function logs for errors
6. Set up alerts for failed verifications
7. Document the complete KYC flow for your team

## Support

- **DiDIt API Issues:** Check DiDIt documentation or contact support
- **Supabase Issues:** Check Supabase documentation
- **Integration Issues:** Review logs and error messages
