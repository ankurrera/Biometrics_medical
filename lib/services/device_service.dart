import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

/// Service for managing registered devices
class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  final _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  static const String _deviceIdKey = 'caresync_device_id';

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE IDENTIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Get or create unique device ID
  Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await _storage.write(key: _deviceIdKey, value: deviceId);
      developer.log('[DEVICE] Created new device ID: $deviceId');
    }
    return deviceId;
  }

  /// Get device ID (returns null if not set)
  Future<String?> getDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }

  /// Get device information (simplified without device_info_plus)
  Future<DeviceInfo> getDeviceInfo() async {
    final deviceId = await getOrCreateDeviceId();

    String deviceName;
    String platform;
    String deviceModel;
    String osVersion;

    if (Platform.isIOS) {
      deviceName = 'iPhone';
      platform = 'ios';
      deviceModel = 'iPhone';
      osVersion = 'iOS';
      developer.log('[DEVICE] iOS Device detected');
    } else if (Platform.isAndroid) {
      deviceName = 'Android Device';
      platform = 'android';
      deviceModel = 'Android';
      osVersion = 'Android';
      developer.log('[DEVICE] Android Device detected');
    } else {
      deviceName = 'Web Browser';
      platform = 'web';
      deviceModel = 'Web';
      osVersion = 'Unknown';
      developer.log('[DEVICE] Web Browser detected');
    }

    return DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      deviceModel: deviceModel,
      osVersion: osVersion,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE REGISTRATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Register current device for the logged-in user
  Future<RegisteredDevice> registerDevice({
    required bool biometricEnabled,
    String? tokenFingerprint,
    bool trusted = true,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw DeviceException('User not authenticated');
      }

      final deviceInfo = await getDeviceInfo();

      // Ensure device name is never null or empty
      final deviceName = deviceInfo.deviceName.trim().isEmpty
          ? 'Unknown Device'
          : deviceInfo.deviceName;

      developer.log('[DEVICE] Registering device: $deviceName for user: $userId');
      developer.log('[DEVICE] Device ID: ${deviceInfo.deviceId}');
      developer.log('[DEVICE] Platform: ${deviceInfo.platform}');
      developer.log('[DEVICE] Biometric Enabled: $biometricEnabled');

      final data = {
        'user_id': userId,
        'device_id': deviceInfo.deviceId,
        'device_name': deviceName,
        'platform': deviceInfo.platform,
        'device_model': deviceInfo.deviceModel,
        'os_version': deviceInfo.osVersion,
        'biometric_enabled': biometricEnabled,
        'trusted': trusted,
        'registered_at': DateTime.now().toIso8601String(),
        'last_used_at': DateTime.now().toIso8601String(),
        'revoked': false,
      };

      if (tokenFingerprint != null) {
        data['token_fingerprint'] = tokenFingerprint;
      }

      developer.log('[DEVICE] Inserting/updating device in database...');
      developer.log('[DEVICE] Data to insert: $data');

      final response = await _supabase
          .from('registered_devices')
          .upsert(data)
          .select()
          .single();

      developer.log('[DEVICE] Device registered successfully');

      return RegisteredDevice.fromJson(response);
    } on PostgrestException catch (e) {
      developer.log('[DEVICE] PostgrestException: ${e.message}, code: ${e.code}, details: ${e.details}', error: e);
      throw DeviceException('Failed to register device: ${e.message}');
    } catch (e) {
      developer.log('[DEVICE] Error registering device: $e', error: e);
      throw DeviceException('Failed to register device: $e');
    }
  }

  /// Check if current device is registered
  Future<bool> isDeviceRegistered() async {
    try {
      final deviceId = await getDeviceId();
      if (deviceId == null) return false;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('registered_devices')
          .select()
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .eq('revoked', false)
          .maybeSingle();

      return response != null;
    } catch (e) {
      developer.log('[DEVICE] Error checking if device registered: $e');
      return false;
    }
  }

  /// Get current device registration
  Future<RegisteredDevice?> getCurrentDevice() async {
    try {
      final deviceId = await getDeviceId();
      if (deviceId == null) return null;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('registered_devices')
          .select()
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .eq('revoked', false)
          .maybeSingle();

      if (response == null) return null;

      return RegisteredDevice.fromJson(response);
    } on PostgrestException catch (e) {
      developer.log('[DEVICE] Error getting current device: ${e.message}', error: e);
      throw DeviceException('Failed to get current device: ${e.message}');
    } catch (e) {
      developer.log('[DEVICE] Error getting current device: $e', error: e);
      throw DeviceException('Failed to get current device: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  /// Get all registered devices for current user
  Future<List<RegisteredDevice>> getUserDevices() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw DeviceException('User not authenticated');
      }

      final response = await _supabase
          .from('registered_devices')
          .select()
          .eq('user_id', userId)
          .eq('revoked', false)
          .order('last_used_at', ascending: false);

      return (response as List)
          .map((json) => RegisteredDevice.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DeviceException('Failed to get user devices: ${e.message}');
    } catch (e) {
      throw DeviceException('Failed to get user devices: $e');
    }
  }

  /// Update device last used timestamp
  Future<void> updateDeviceLastUsed() async {
    try {
      final deviceId = await getDeviceId();
      if (deviceId == null) return;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('registered_devices')
          .update({'last_used_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('device_id', deviceId);
    } catch (e) {
      developer.log('[DEVICE] Failed to update device last used: $e');
    }
  }

  /// Revoke (disable) a device
  Future<void> revokeDevice(String deviceId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw DeviceException('User not authenticated');
      }

      await _supabase.from('registered_devices').update({
        'revoked': true,
        'revoked_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId).eq('device_id', deviceId);

      developer.log('[DEVICE] Device revoked: $deviceId');
    } on PostgrestException catch (e) {
      throw DeviceException('Failed to revoke device: ${e.message}');
    } catch (e) {
      throw DeviceException('Failed to revoke device: $e');
    }
  }

  /// Delete a device (permanent removal)
  Future<void> deleteDevice(String deviceId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw DeviceException('User not authenticated');
      }

      await _supabase
          .from('registered_devices')
          .delete()
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      developer.log('[DEVICE] Device deleted: $deviceId');
    } on PostgrestException catch (e) {
      throw DeviceException('Failed to delete device: ${e.message}');
    } catch (e) {
      throw DeviceException('Failed to delete device: $e');
    }
  }

  /// Update biometric status for current device
  Future<void> updateBiometricStatus(bool enabled) async {
    try {
      final deviceId = await getDeviceId();
      if (deviceId == null) {
        throw DeviceException('Device not registered');
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw DeviceException('User not authenticated');
      }

      await _supabase
          .from('registered_devices')
          .update({'biometric_enabled': enabled})
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      developer.log('[DEVICE] Biometric status updated: $enabled');
    } on PostgrestException catch (e) {
      throw DeviceException('Failed to update biometric status: ${e.message}');
    } catch (e) {
      throw DeviceException('Failed to update biometric status: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String deviceModel;
  final String osVersion;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
  });
}

class RegisteredDevice {
  final String id;
  final String userId;
  final String deviceId;
  final String deviceName;
  final String? platform;
  final String? deviceModel;
  final String? osVersion;
  final bool biometricEnabled;
  final bool trusted;
  final String? tokenFingerprint;
  final DateTime registeredAt;
  final DateTime lastUsedAt;
  final bool revoked;
  final DateTime? revokedAt;

  RegisteredDevice({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    this.platform,
    this.deviceModel,
    this.osVersion,
    required this.biometricEnabled,
    required this.trusted,
    this.tokenFingerprint,
    required this.registeredAt,
    required this.lastUsedAt,
    required this.revoked,
    this.revokedAt,
  });

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) {
    return RegisteredDevice(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      platform: json['platform'] as String?,
      deviceModel: json['device_model'] as String?,
      osVersion: json['os_version'] as String?,
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      trusted: json['trusted'] as bool? ?? true,
      tokenFingerprint: json['token_fingerprint'] as String?,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
      revoked: json['revoked'] as bool? ?? false,
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'device_model': deviceModel,
      'os_version': osVersion,
      'biometric_enabled': biometricEnabled,
      'trusted': trusted,
      'token_fingerprint': tokenFingerprint,
      'registered_at': registeredAt.toIso8601String(),
      'last_used_at': lastUsedAt.toIso8601String(),
      'revoked': revoked,
      'revoked_at': revokedAt?.toIso8601String(),
    };
  }

  Future<bool> isCurrentDeviceAsync() async {
    try {
      final storage = const FlutterSecureStorage();
      final currentDeviceId = await storage.read(key: 'caresync_device_id');
      return currentDeviceId == deviceId;
    } catch (e) {
      return false;
    }
  }

  String get platformIcon {
    switch (platform) {
      case 'ios':
        return '📱';
      case 'android':
        return '🤖';
      case 'web':
        return '🌐';
      default:
        return '💻';
    }
  }

  String get lastUsedString {
    final now = DateTime.now();
    final difference = now.difference(lastUsedAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return 'More than a month ago';
    }
  }
}

class DeviceException implements Exception {
  final String message;
  DeviceException(this.message);

  @override
  String toString() => message;
}