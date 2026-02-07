import 'dart:async';
import 'package:flutter/material.dart';
import 'secure_storage_service.dart';
import 'biometric_service.dart';

/// Service for tracking app lifecycle and managing biometric re-authentication
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService._();
  static final AppLifecycleService instance = AppLifecycleService._();

  final _secureStorage = SecureStorageService.instance;
  final _biometric = BiometricService.instance;

  // Stream to notify UI when lock is required
  final _authStatusController = StreamController<bool>.broadcast();
  Stream<bool> get authStatusStream => _authStatusController.stream;

  bool _isAuthenticating = false;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStatusController.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    } else if (state == AppLifecycleState.paused) {
      _handleAppPause();
    }
  }

  Future<void> _handleAppResume() async {
    final biometricEnabled = await _secureStorage.isBiometricEnabled();
    if (!biometricEnabled) {
      await _secureStorage.updateLastActivity();
      return;
    }

    final hasTimedOut = await _secureStorage.hasSessionTimedOut();
    if (hasTimedOut && !_isAuthenticating) {
      // Broadcast lock event
      _authStatusController.add(true);
    } else {
      await _secureStorage.updateLastActivity();
    }
  }

  Future<void> _handleAppPause() async {
    await _secureStorage.updateLastActivity();
  }

  /// Trigger authentication flow
  Future<bool> authenticate() async {
    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    try {
      final authenticated = await _biometric.authenticate(
        reason: 'Session timed out. Please authenticate.',
        biometricOnly: true,
      );

      if (authenticated) {
        await _secureStorage.updateLastActivity();
        _authStatusController.add(false); // Notify unlock
      }

      _isAuthenticating = false;
      return authenticated;
    } catch (e) {
      _isAuthenticating = false;
      return false;
    }
  }
}