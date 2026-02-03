import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'biometric_service.dart';

/// Service for managing encryption keys and encrypting/decrypting medical data
/// Uses biometric authentication to unlock encryption keys
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _encryptionKeyKey = 'caresync_encryption_key';
  static const String _keyInitializedKey = 'caresync_encryption_key_initialized';

  final _biometric = BiometricService.instance;

  /// Check if encryption key has been initialized
  Future<bool> isKeyInitialized() async {
    final initialized = await _storage.read(key: _keyInitializedKey);
    return initialized == 'true';
  }

  /// Initialize encryption key (called once per user)
  /// This should be done during user setup after biometric enrollment
  Future<void> initializeEncryptionKey() async {
    // Generate a random encryption key
    final key = _generateRandomKey(32); // 256-bit key
    
    // Store the key securely
    await _storage.write(
      key: _encryptionKeyKey,
      value: base64Encode(key),
    );

    // Mark as initialized
    await _storage.write(
      key: _keyInitializedKey,
      value: 'true',
    );

    assert(() {
      print('[ENCRYPTION] Encryption key initialized');
      return true;
    }());
  }

  /// Get encryption key after biometric authentication
  /// Returns null if authentication fails or key not initialized
  Future<Uint8List?> getEncryptionKeyWithBiometric({
    String reason = 'Authenticate to access encrypted medical data',
  }) async {
    // Check if key is initialized
    final initialized = await isKeyInitialized();
    if (!initialized) {
      assert(() {
        print('[ENCRYPTION] Encryption key not initialized');
        return true;
      }());
      return null;
    }

    // Check if biometric is available
    final isAvailable = await _biometric.isBiometricAvailable();
    if (!isAvailable) {
      throw EncryptionException('Biometric authentication is not available');
    }

    // Require biometric authentication
    final authenticated = await _biometric.authenticate(
      reason: reason,
      biometricOnly: true,
    );

    if (!authenticated) {
      throw EncryptionException('Biometric authentication failed');
    }

    // Retrieve the encryption key
    final keyString = await _storage.read(key: _encryptionKeyKey);
    if (keyString == null) {
      throw EncryptionException('Encryption key not found');
    }

    return base64Decode(keyString);
  }

  /// Encrypt medical data using the encryption key
  /// Note: This is a simple XOR encryption for demonstration
  /// In production, use a proper encryption library like pointycastle
  Future<String> encryptData(String plaintext, Uint8List key) async {
    final plaintextBytes = utf8.encode(plaintext);
    final encryptedBytes = _xorEncrypt(plaintextBytes, key);
    return base64Encode(encryptedBytes);
  }

  /// Decrypt medical data using the encryption key
  /// Note: This is a simple XOR decryption for demonstration
  /// In production, use a proper encryption library like pointycastle
  Future<String> decryptData(String ciphertext, Uint8List key) async {
    final ciphertextBytes = base64Decode(ciphertext);
    final decryptedBytes = _xorEncrypt(ciphertextBytes, key);
    return utf8.decode(decryptedBytes);
  }

  /// Encrypt medical record in memory only
  /// Returns encrypted string or throws exception
  Future<String> encryptMedicalRecord({
    required String data,
    String biometricReason = 'Authenticate to encrypt medical data',
  }) async {
    final key = await getEncryptionKeyWithBiometric(
      reason: biometricReason,
    );

    if (key == null) {
      throw EncryptionException('Failed to retrieve encryption key');
    }

    return await encryptData(data, key);
  }

  /// Decrypt medical record in memory only
  /// Returns decrypted string or throws exception
  Future<String> decryptMedicalRecord({
    required String encryptedData,
    String biometricReason = 'Authenticate to decrypt medical data',
  }) async {
    final key = await getEncryptionKeyWithBiometric(
      reason: biometricReason,
    );

    if (key == null) {
      throw EncryptionException('Failed to retrieve encryption key');
    }

    return await decryptData(encryptedData, key);
  }

  /// Clear encryption key (on logout)
  Future<void> clearEncryptionKey() async {
    await _storage.delete(key: _encryptionKeyKey);
    await _storage.delete(key: _keyInitializedKey);

    assert(() {
      print('[ENCRYPTION] Encryption key cleared');
      return true;
    }());
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────────────────────────

  /// Generate random key of specified length
  Uint8List _generateRandomKey(int length) {
    // Use crypto-secure random generation
    final random = Random.secure();
    final key = Uint8List(length);
    
    for (int i = 0; i < length; i++) {
      key[i] = random.nextInt(256);
    }
    
    return key;
  }

  /// Simple XOR encryption/decryption
  /// Note: This is for demonstration only
  /// In production, use AES-256 or similar strong encryption
  Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// Hash data for integrity verification
  String hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}

/// Custom exception for encryption errors
class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);

  @override
  String toString() => message;
}
