import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart'; // REQUIRED IMPORT

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';

class KYCVerificationScreen extends ConsumerStatefulWidget {
  const KYCVerificationScreen({super.key});

  @override
  ConsumerState<KYCVerificationScreen> createState() =>
      _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends ConsumerState<KYCVerificationScreen> {
  bool _isLoading = false;
  final _kycService = KYCService.instance;

  @override
  void initState() {
    super.initState();
    _checkExistingKYC();
  }

  Future<void> _checkExistingKYC() async {
    try {
      final kyc = await _kycService.getKYCStatus();
      if (kyc != null && mounted) {
        if (kyc.status == KYCStatus.verified) {
          _showStatusDialog(
            title: 'Verified',
            message: 'Your identity has been verified.',
            icon: Icons.check_circle,
            color: AppColors.success,
            onContinue: () => context.go(RouteNames.roleSelection),
          );
        } else if (kyc.status == KYCStatus.pending) {
          _showStatusDialog(
            title: 'Under Review',
            message: 'Your documents are being processed.',
            icon: Icons.access_time,
            color: AppColors.warning,
            onContinue: () => context.go(RouteNames.roleSelection),
          );
        }
      }
    } catch (e) {
      // Ignore initial check errors
    }
  }

  void _showStatusDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required VoidCallback onContinue,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(title)]),
        content: Text(message),
        actions: [TextButton(onPressed: onContinue, child: const Text('Continue'))],
      ),
    );
  }

  Future<void> _startDiditVerification() async {
    setState(() => _isLoading = true);
    try {
      final sessionUrl = await _kycService.createDiditSession();
      if (sessionUrl != null && mounted) {
        await _openVerificationWebView(sessionUrl);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openVerificationWebView(String url) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            if (change.url != null && change.url!.contains('verify-callback')) {
              Navigator.pop(context);
              _handleVerificationSuccess();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Identity Verification'),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            body: WebViewWidget(controller: controller),
          ),
        ),
      ),
    );
  }

  void _handleVerificationSuccess() {
    _showStatusDialog(
      title: 'Submission Received',
      message: 'Your documents have been submitted securely.',
      icon: Icons.lock_clock,
      color: AppColors.primary,
      onContinue: () {
        _checkExistingKYC();
        context.go(RouteNames.roleSelection);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biometric KYC')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.face_retouching_natural, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text('Identity Verification Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _startDiditVerification,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Start Face Scan'),
            ),
            TextButton(
              onPressed: () => context.go(RouteNames.roleSelection),
              child: const Text('Skip (Demo)'),
            ),
          ],
        ),
      ),
    );
  }
}