import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Service for securely storing sensitive data on the device
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _uuid = Uuid();

  // Storage keys
  static const String _deviceIdKey = 'caresync_device_id';
  static const String _userIdKey = 'caresync_user_id';
  static const String _biometricEnabledKey = 'caresync_biometric_enabled';
  static const String _refreshTokenKey = 'caresync_refresh_token';
  static const String _accessTokenKey = 'caresync_access_token';
  static const String _lastActivityKey = 'caresync_last_activity';

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE ID (Biometric Binding)
  // ─────────────────────────────────────────────────────────────────────────

  /// Get or create a unique device ID for biometric binding
  /// This ID is generated once per device and stored securely
  Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }

  /// Get the stored device ID (returns null if not set)
  Future<String?> getDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER SESSION
  // ─────────────────────────────────────────────────────────────────────────

  /// Store the current user ID for quick access
  Future<void> setUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  /// Get the stored user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  /// Store refresh token for session persistence
  Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Store access token for session persistence
  Future<void> setAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BIOMETRIC SETTINGS
  // ─────────────────────────────────────────────────────────────────────────

  /// Check if biometric login is enabled for this device
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  /// Enable or disable biometric login for this device
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION TIMEOUT
  // ─────────────────────────────────────────────────────────────────────────

  /// Update last activity timestamp
  Future<void> updateLastActivity() async {
    await _storage.write(
      key: _lastActivityKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Get last activity timestamp
  Future<DateTime?> getLastActivity() async {
    final value = await _storage.read(key: _lastActivityKey);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
  }

  /// Check if session has timed out (15 minutes of inactivity)
  Future<bool> hasSessionTimedOut() async {
    final lastActivity = await getLastActivity();
    if (lastActivity == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastActivity);
    return difference.inMinutes > 15; // 15 minutes timeout
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEAR DATA
  // ─────────────────────────────────────────────────────────────────────────

  /// Clear all stored data (on logout)
  Future<void> clearAll() async {
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _lastActivityKey);
    // Note: We don't delete deviceId - it persists across logins
  }

  /// Clear only session data (keeps device ID and biometric settings)
  Future<void> clearSession() async {
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _lastActivityKey);
  }
}

