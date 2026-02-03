import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../../services/secure_storage_service.dart';

/// A widget that protects its child with biometric authentication
/// Use this to wrap any sensitive screen or action
class BiometricGuard extends StatefulWidget {
  final Widget child;
  final String reason;
  final VoidCallback? onAuthenticationFailed;
  final bool allowBiometricOnly;

  const BiometricGuard({
    super.key,
    required this.child,
    this.reason = 'Please authenticate to continue',
    this.onAuthenticationFailed,
    this.allowBiometricOnly = true,
  });

  @override
  State<BiometricGuard> createState() => _BiometricGuardState();
}

class _BiometricGuardState extends State<BiometricGuard> {
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    // Check if biometric is enabled in settings
    final enabled = await SecureStorageService.instance.isBiometricEnabled();
    setState(() => _biometricEnabled = enabled);

    // If biometric is enabled, require authentication
    if (enabled) {
      await _authenticate();
    } else {
      // Biometric not enabled, allow access
      setState(() => _isAuthenticated = true);
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    try {
      // Check if biometric is available
      final isAvailable = await BiometricService.instance.isBiometricAvailable();
      
      if (!isAvailable) {
        // Biometric not available, allow access or fail based on settings
        setState(() {
          _isAuthenticated = !widget.allowBiometricOnly;
          _isAuthenticating = false;
        });
        
        if (!_isAuthenticated && mounted) {
          _showBiometricUnavailableDialog();
        }
        return;
      }

      // Attempt biometric authentication
      final authenticated = await BiometricService.instance.authenticate(
        reason: widget.reason,
        biometricOnly: widget.allowBiometricOnly,
      );

      if (mounted) {
        setState(() {
          _isAuthenticated = authenticated;
          _isAuthenticating = false;
        });

        if (!authenticated) {
          widget.onAuthenticationFailed?.call();
          Navigator.of(context).pop();
        }
      }
    } on BiometricException catch (e) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
        _showErrorDialog(e.message);
      }
    }
  }

  void _showBiometricUnavailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometric Unavailable'),
        content: const Text(
          'Biometric authentication is not available on this device or not properly configured.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authenticate();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Authenticating...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              const Text(
                'Authentication Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.reason,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Authenticate'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Helper function to show biometric authentication dialog before an action
/// Returns true if authentication succeeded, false otherwise
Future<bool> showBiometricAuthDialog({
  required BuildContext context,
  String reason = 'Please authenticate to continue',
  bool allowBiometricOnly = true,
}) async {
  // Check if biometric is enabled
  final biometricEnabled = await SecureStorageService.instance.isBiometricEnabled();
  
  // If biometric is not enabled, allow the action
  if (!biometricEnabled) {
    return true;
  }

  // Check if biometric is available
  final isAvailable = await BiometricService.instance.isBiometricAvailable();
  
  if (!isAvailable) {
    // Show error dialog
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Biometric Unavailable'),
          content: const Text(
            'Biometric authentication is not available on this device or not properly configured.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  try {
    // Attempt authentication
    final authenticated = await BiometricService.instance.authenticate(
      reason: reason,
      biometricOnly: allowBiometricOnly,
    );

    return authenticated;
  } on BiometricException catch (e) {
    // Show error dialog
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Authentication Failed'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return false;
  }
}
