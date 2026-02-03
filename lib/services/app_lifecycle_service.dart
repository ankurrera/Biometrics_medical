import 'package:flutter/material.dart';
import 'secure_storage_service.dart';
import 'biometric_service.dart';

/// Service for tracking app lifecycle and managing biometric re-authentication
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService._();
  static final AppLifecycleService instance = AppLifecycleService._();

  final _secureStorage = SecureStorageService.instance;
  final _biometric = BiometricService.instance;

  // Callback to be invoked when biometric re-authentication is required
  VoidCallback? onBiometricRequired;

  // Track if we're currently showing biometric prompt to avoid duplicates
  bool _isAuthenticating = false;

  /// Initialize the lifecycle service
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Dispose the lifecycle service
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    assert(() {
      print('[LIFECYCLE] App state changed to: ${state.name}');
      return true;
    }());

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResume();
        break;
      case AppLifecycleState.paused:
        _handleAppPause();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No action needed for these states
        break;
    }
  }

  /// Handle app resume - check if biometric re-authentication is required
  Future<void> _handleAppResume() async {
    // Update last activity
    await _secureStorage.updateLastActivity();

    // Check if biometric is enabled
    final biometricEnabled = await _secureStorage.isBiometricEnabled();
    if (!biometricEnabled) {
      return;
    }

    // Check if session has timed out
    final hasTimedOut = await _secureStorage.hasSessionTimedOut();
    
    if (hasTimedOut && !_isAuthenticating) {
      assert(() {
        print('[LIFECYCLE] Session timed out, requiring biometric re-authentication');
        return true;
      }());

      // Trigger biometric re-authentication
      onBiometricRequired?.call();
    }
  }

  /// Handle app pause - update last activity timestamp
  Future<void> _handleAppPause() async {
    await _secureStorage.updateLastActivity();
  }

  /// Manually trigger biometric authentication check
  /// Returns true if authentication succeeded or not required, false otherwise
  Future<bool> checkBiometricAuth({
    required BuildContext context,
    String reason = 'Please authenticate to continue',
  }) async {
    if (_isAuthenticating) {
      return false;
    }

    // Check if biometric is enabled
    final biometricEnabled = await _secureStorage.isBiometricEnabled();
    if (!biometricEnabled) {
      return true;
    }

    // Check if session has timed out
    final hasTimedOut = await _secureStorage.hasSessionTimedOut();
    
    if (!hasTimedOut) {
      // Update last activity and allow access
      await _secureStorage.updateLastActivity();
      return true;
    }

    // Session timed out, require biometric
    _isAuthenticating = true;

    try {
      final isAvailable = await _biometric.isBiometricAvailable();
      
      if (!isAvailable) {
        _isAuthenticating = false;
        // Biometric not available, show error
        if (context.mounted) {
          await _showBiometricUnavailableDialog(context);
        }
        return false;
      }

      final authenticated = await _biometric.authenticate(
        reason: reason,
        biometricOnly: true,
      );

      if (authenticated) {
        // Update last activity on successful authentication
        await _secureStorage.updateLastActivity();
      }

      _isAuthenticating = false;
      return authenticated;
    } on BiometricException catch (e) {
      _isAuthenticating = false;
      
      if (context.mounted) {
        await _showErrorDialog(context, e.message);
      }
      
      return false;
    }
  }

  Future<void> _showBiometricUnavailableDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometric Unavailable'),
        content: const Text(
          'Biometric authentication is not available. Please sign in again.',
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

  Future<void> _showErrorDialog(BuildContext context, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Update last activity timestamp manually
  Future<void> recordActivity() async {
    await _secureStorage.updateLastActivity();
  }
}
