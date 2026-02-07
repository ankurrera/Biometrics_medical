import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/biometric_service.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/kyc_service.dart';
import '../../../services/two_factor_service.dart';
import '../../../services/device_service.dart';
import '../../../services/audit_service.dart';
import '../../../services/auth_controller.dart';
import '../../patient/providers/patient_provider.dart';
import '../../shared/models/user_profile.dart';

/// Provider for auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.instance.authStateChanges.map((state) => state.session?.user);
});

/// Provider for current user profile
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final profileData = await SupabaseService.instance.getProfile();
  if (profileData == null) return null;

  return UserProfile.fromJson(profileData);
});

/// Provider for biometric availability
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  return await BiometricService.instance.isBiometricAvailable();
});

/// Provider for biometric type name
final biometricTypeNameProvider = FutureProvider<String>((ref) async {
  return await BiometricService.instance.getBiometricTypeName();
});

/// Provider to check if biometric is enabled
/// This is the "Listener" that needs to be refreshed when toggle changes
final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  return await SecureStorageService.instance.isBiometricEnabled();
});

/// Provider for KYC status
final kycStatusProvider = FutureProvider<KYCVerification?>((ref) async {
  return await KYCService.instance.getKYCStatus();
});

/// Auth notifier for handling authentication operations
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref; // Add Ref to access other providers

  AuthNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final _supabase = SupabaseService.instance;
  final _biometric = BiometricService.instance;
  final _storage = SecureStorageService.instance;
  final _kycService = KYCService.instance;
  final _deviceService = DeviceService.instance;
  final _auditService = AuditService.instance;
  final _authController = AuthController.instance;

  void _init() {
    state = AsyncValue.data(_supabase.currentUser);
  }

  /// Toggle Biometric Login
  Future<void> toggleBiometric(bool enable) async {
    try {
      if (enable) {
        // Verify identity before enabling
        final authenticated = await _biometric.authenticate(
          reason: 'Authenticate to enable biometric login',
          biometricOnly: true,
        );
        if (!authenticated) {
          throw Exception('Biometric verification failed');
        }
      }

      // 1. Update Storage
      await _storage.setBiometricEnabled(enable);

      // 2. CRITICAL FIX: Force the UI provider to refresh immediately
      ref.invalidate(biometricEnabledProvider);

    } catch (e) {
      rethrow;
    }
  }

  /// Sign up
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone, 'role': role},
      );

      if (response.user == null) throw Exception('Failed to create account');

      await _supabase.upsertProfile({
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'role': role,
      });

      await _createRoleRecord(role);
      await _storage.setUserId(response.user!.id);
      state = AsyncValue.data(response.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign in
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.signIn(email: email, password: password);
      if (response.user == null) throw Exception('Invalid credentials');

      final userId = response.user!.id;
      if (response.session != null) {
        await _storage.setAccessToken(response.session!.accessToken);
        await _storage.setRefreshToken(response.session!.refreshToken ?? '');
      }
      await _storage.setUserId(userId);

      // Refresh biometric state on login
      ref.invalidate(biometricEnabledProvider);

      final isDeviceRegistered = await _deviceService.isDeviceRegistered();
      if (!isDeviceRegistered) {
        state = AsyncValue.data(response.user);
        return SignInResult(
            user: response.user,
            requiresTwoFactor: true,
            requiresKyc: false,
            requiresBiometric: false,
            email: email);
      }

      final kycVerified = await _kycService.isKYCVerified(userId);
      if (!kycVerified) {
        state = AsyncValue.data(response.user);
        return SignInResult(
            user: response.user,
            requiresTwoFactor: false,
            requiresKyc: true,
            requiresBiometric: false);
      }

      await _deviceService.updateDeviceLastUsed();
      state = AsyncValue.data(response.user);

      return SignInResult(
          user: response.user,
          requiresTwoFactor: false,
          requiresKyc: false,
          requiresBiometric: false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign in using Biometrics (Unlock Mode)
  Future<bool> signInWithBiometric() async {
    try {
      final isEnabled = await _storage.isBiometricEnabled();
      if (!isEnabled) return false;

      final authenticated = await _biometric.authenticate(
        reason: 'Authenticate to sign in',
        biometricOnly: true,
      );

      if (!authenticated) return false;

      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      try {
        final response = await _supabase.auth.recoverSession(refreshToken);
        if (response.session == null) return false;
      } catch (e) {
        return false;
      }

      final deviceId = await _storage.getDeviceId();
      if (deviceId != null) {
        await _deviceService.updateDeviceLastUsed();
        await _auditService.logLogin(deviceId: deviceId, biometric: true);
      }
      await _storage.updateLastActivity();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Complete Two-Factor
  Future<void> completeTwoFactor({
    required bool registerDevice,
    required bool enableBiometric,
  }) async {
    try {
      if (registerDevice) {
        await _deviceService.registerDevice(biometricEnabled: enableBiometric);
        if (enableBiometric) {
          await _storage.setBiometricEnabled(true);
          ref.invalidate(biometricEnabledProvider); // Refresh UI
        }
      }
      await _storage.updateLastActivity();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> enrollBiometric() async {
    try {
      await _authController.forceEnableBiometric();
      await _storage.setBiometricEnabled(true);
      ref.invalidate(biometricEnabledProvider); // Refresh UI
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.signOut();
    await _storage.clearSession();
    state = const AsyncValue.data(null);
  }

  Future<void> _createRoleRecord(String role) async {
    switch (role) {
      case 'patient':
        await _supabase.upsertPatientData({'qr_code_id': DateTime.now().millisecondsSinceEpoch.toString()});
        break;
      case 'doctor':
        await _supabase.client.from('doctors').upsert({'user_id': _supabase.currentUserId});
        break;
      case 'pharmacist':
        await _supabase.client.from('pharmacists').upsert({'user_id': _supabase.currentUserId});
        break;
      case 'first_responder':
        await _supabase.client.from('first_responders').upsert({'user_id': _supabase.currentUserId});
        break;
    }
  }
}

class SignInResult {
  final User? user;
  final bool requiresTwoFactor;
  final bool requiresKyc;
  final bool requiresBiometric;
  final String? email;

  SignInResult({
    this.user,
    required this.requiresTwoFactor,
    required this.requiresKyc,
    required this.requiresBiometric,
    this.email,
  });
}

// Updated Provider Definition to pass 'ref'
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});