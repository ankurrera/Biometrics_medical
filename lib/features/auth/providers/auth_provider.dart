import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/biometric_service.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/kyc_service.dart';
import '../../../services/device_service.dart';
import '../../../services/audit_service.dart';
import '../../../services/auth_controller.dart';
import '../../shared/models/user_profile.dart';

// ... Providers (authStateProvider, currentProfileProvider, etc.) remain unchanged ...
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.instance.authStateChanges.map((state) => state.session?.user);
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final profileData = await SupabaseService.instance.getProfile();
  if (profileData == null) return null;

  return UserProfile.fromJson(profileData);
});

final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  return await BiometricService.instance.isBiometricAvailable();
});

final biometricTypeNameProvider = FutureProvider<String>((ref) async {
  return await BiometricService.instance.getBiometricTypeName();
});

final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  return await SecureStorageService.instance.isBiometricEnabled();
});

final kycStatusProvider = FutureProvider<KYCVerification?>((ref) async {
  return await KYCService.instance.getKYCStatus();
});

/// Auth notifier for handling authentication operations
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;

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

  // ... toggleBiometric remains unchanged ...
  Future<void> toggleBiometric(bool enable) async {
    try {
      if (enable) {
        final authenticated = await _biometric.authenticate(
          reason: 'Authenticate to enable biometric login',
          biometricOnly: true,
        );
        if (!authenticated) {
          throw Exception('Biometric verification failed');
        }
      }
      await _storage.setBiometricEnabled(enable);
      ref.invalidate(biometricEnabledProvider);
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with Extended Patient & Doctor support
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
    // Doctor fields
    String? hospitalName,
    String? specialization,
    String? medicalRegNumber,
    // New Patient fields
    String? gender,
    DateTime? dateOfBirth,
    double? weight,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role,
        },
      );

      if (response.user == null) throw Exception('Failed to create account');

      // Create profile with all fields
      await _supabase.upsertProfile({
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'role': role,
        if (gender != null) 'gender': gender, // Add gender to profiles
        // Insert doctor specific fields if present
        if (hospitalName != null) 'hospital_clinic_name': hospitalName,
        if (specialization != null) 'specialization': specialization,
        if (medicalRegNumber != null) 'medical_registration_number': medicalRegNumber,
      });

      // Pass patient data to role record creation
      await _createRoleRecord(
        role,
        dateOfBirth: dateOfBirth,
        weight: weight,
      );

      await _storage.setUserId(response.user!.id);

      ref.invalidate(currentProfileProvider);

      state = AsyncValue.data(response.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // ... signIn, signInWithBiometric, completeTwoFactor, enrollBiometric, signOut remain unchanged ...
  Future<SignInResult> signIn({required String email, required String password}) async {
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

      ref.invalidate(biometricEnabledProvider);
      ref.invalidate(currentProfileProvider);

      final isDeviceRegistered = await _deviceService.isDeviceRegistered();
      if (!isDeviceRegistered) {
        state = AsyncValue.data(response.user);
        return SignInResult(user: response.user, requiresTwoFactor: true, requiresKyc: false, requiresBiometric: false, email: email);
      }

      final kycVerified = await _kycService.isKYCVerified(userId);
      if (!kycVerified) {
        state = AsyncValue.data(response.user);
        return SignInResult(user: response.user, requiresTwoFactor: false, requiresKyc: true, requiresBiometric: false);
      }

      await _deviceService.updateDeviceLastUsed();
      state = AsyncValue.data(response.user);

      return SignInResult(user: response.user, requiresTwoFactor: false, requiresKyc: false, requiresBiometric: false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<bool> signInWithBiometric() async {
    try {
      final isEnabled = await _storage.isBiometricEnabled();
      if (!isEnabled) return false;
      final authenticated = await _biometric.authenticate(reason: 'Authenticate to sign in', biometricOnly: true);
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

  Future<void> completeTwoFactor({required bool registerDevice, required bool enableBiometric}) async {
    try {
      if (registerDevice) {
        await _deviceService.registerDevice(biometricEnabled: enableBiometric);
        if (enableBiometric) {
          await _storage.setBiometricEnabled(true);
          ref.invalidate(biometricEnabledProvider);
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
      ref.invalidate(biometricEnabledProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.signOut();
    await _storage.clearSession();
    state = const AsyncValue.data(null);
  }

  Future<void> _createRoleRecord(
      String role, {
        DateTime? dateOfBirth,
        double? weight,
      }) async {
    switch (role) {
      case 'patient':
      // Add patient specific medical data here
        await _supabase.upsertPatientData({
          'qr_code_id': DateTime.now().millisecondsSinceEpoch.toString(),
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
          if (weight != null) 'weight': weight,
        });
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

// ... SignInResult and Provider definition remain unchanged ...
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

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});