import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling Two-Factor Authentication (2FA)
class TwoFactorService {
  TwoFactorService._();
  static final TwoFactorService instance = TwoFactorService._();

  final _supabase = Supabase.instance.client;
  static const int _codeLength = 6;
  static const int _codeExpiryMinutes = 10;
  static const int _maxAttempts = 3;

  // ─────────────────────────────────────────────────────────────────────────
  // CODE GENERATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Generate a random 6-digit code
  String _generateCode() {
    final random = Random.secure();
    final code = random.nextInt(1000000).toString().padLeft(_codeLength, '0');
    return code;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMAIL OTP
  // ─────────────────────────────────────────────────────────────────────────

  /// Send 2FA code via email
  Future<void> sendEmailCode({
    required String userId,
    required String email,
  }) async {
    try {
      final code = _generateCode();
      final expiresAt = DateTime.now().add(
        Duration(minutes: _codeExpiryMinutes),
      );

      // Store code in database
      await _supabase.from('two_factor_codes').insert({
        'user_id': userId,
        'code': code,
        'code_type': 'email',
        'expires_at': expiresAt.toIso8601String(),
        'verified': false,
        'attempts': 0,
      });

      // Send email using Supabase Edge Function or external service
      // For now, we'll use a placeholder
      // In production, you would integrate with SendGrid, AWS SES, etc.
      await _sendEmailViaService(email, code);
    } on PostgrestException catch (e) {
      throw TwoFactorException('Failed to send email code: ${e.message}');
    } catch (e) {
      throw TwoFactorException('Failed to send email code: $e');
    }
  }

  /// Send email via external service (placeholder)
  Future<void> _sendEmailViaService(String email, String code) async {
    // TODO: Implement actual email sending
    // Options:
    // 1. Supabase Edge Function with Resend/SendGrid
    // 2. Firebase Cloud Functions
    // 3. AWS SES
    // 4. Direct SMTP
    
    // For development, log the code (REMOVE IN PRODUCTION)
    // ignore: avoid_print
    assert(() {
      print('📧 2FA Code for $email: $code');
      return true;
    }());
    
    // In production, call your email service:
    // await _supabase.functions.invoke('send-2fa-email', body: {
    //   'email': email,
    //   'code': code,
    // });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMS OTP
  // ─────────────────────────────────────────────────────────────────────────

  /// Send 2FA code via SMS
  Future<void> sendSMSCode({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      final code = _generateCode();
      final expiresAt = DateTime.now().add(
        Duration(minutes: _codeExpiryMinutes),
      );

      // Store code in database
      await _supabase.from('two_factor_codes').insert({
        'user_id': userId,
        'code': code,
        'code_type': 'sms',
        'expires_at': expiresAt.toIso8601String(),
        'verified': false,
        'attempts': 0,
      });

      // Send SMS using external service
      await _sendSMSViaService(phoneNumber, code);
    } on PostgrestException catch (e) {
      throw TwoFactorException('Failed to send SMS code: ${e.message}');
    } catch (e) {
      throw TwoFactorException('Failed to send SMS code: $e');
    }
  }

  /// Send SMS via external service (placeholder)
  Future<void> _sendSMSViaService(String phoneNumber, String code) async {
    // TODO: Implement actual SMS sending
    // Options:
    // 1. Twilio
    // 2. AWS SNS
    // 3. Firebase Cloud Messaging
    // 4. Vonage (Nexmo)
    
    // For development, log the code (REMOVE IN PRODUCTION)
    // ignore: avoid_print
    assert(() {
      print('📱 2FA Code for $phoneNumber: $code');
      return true;
    }());
    
    // In production, call your SMS service:
    // await _supabase.functions.invoke('send-2fa-sms', body: {
    //   'phone': phoneNumber,
    //   'code': code,
    // });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CODE VERIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Verify 2FA code
  Future<bool> verifyCode({
    required String userId,
    required String code,
    required TwoFactorCodeType codeType,
  }) async {
    try {
      // Get the most recent unverified code for this user
      final response = await _supabase
          .from('two_factor_codes')
          .select()
          .eq('user_id', userId)
          .eq('code_type', codeType.name)
          .eq('verified', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        throw TwoFactorException('No verification code found');
      }

      final codeData = response;
      final storedCode = codeData['code'] as String;
      final expiresAt = DateTime.parse(codeData['expires_at'] as String);
      final attempts = codeData['attempts'] as int;
      final codeId = codeData['id'] as String;

      // Check if code has expired
      if (DateTime.now().isAfter(expiresAt)) {
        throw TwoFactorException('Verification code has expired');
      }

      // Check if max attempts exceeded
      if (attempts >= _maxAttempts) {
        throw TwoFactorException('Maximum verification attempts exceeded');
      }

      // Verify code
      if (code == storedCode) {
        // Mark as verified
        await _supabase.from('two_factor_codes').update({
          'verified': true,
          'verified_at': DateTime.now().toIso8601String(),
        }).eq('id', codeId);

        return true;
      } else {
        // Increment attempts
        await _supabase.from('two_factor_codes').update({
          'attempts': attempts + 1,
        }).eq('id', codeId);

        throw TwoFactorException(
          'Invalid verification code (${_maxAttempts - attempts - 1} attempts remaining)',
        );
      }
    } on PostgrestException catch (e) {
      throw TwoFactorException('Failed to verify code: ${e.message}');
    } on TwoFactorException {
      rethrow;
    } catch (e) {
      throw TwoFactorException('Failed to verify code: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTHENTICATOR APP (TOTP)
  // ─────────────────────────────────────────────────────────────────────────

  // Note: For authenticator app support, you would need to:
  // 1. Generate a secret key for the user
  // 2. Generate a QR code with the secret
  // 3. Verify TOTP codes using the secret
  // 
  // This requires additional dependencies like:
  // - otp (for TOTP generation/verification)
  // - qr_flutter (for QR code generation)
  //
  // Implementation would be similar to Google Authenticator

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITY METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /// Clean up expired codes
  Future<void> cleanupExpiredCodes() async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      await _supabase
          .from('two_factor_codes')
          .delete()
          .lt('expires_at', oneHourAgo.toIso8601String());
    } catch (e) {
      // Silently fail - this is a cleanup operation
      // In production, use proper logging framework
      // ignore: avoid_print
      assert(() {
        print('Failed to cleanup expired codes: $e');
        return true;
      }());
    }
  }

  /// Check if user has an active unverified code
  Future<bool> hasActiveCode({
    required String userId,
    required TwoFactorCodeType codeType,
  }) async {
    try {
      final response = await _supabase
          .from('two_factor_codes')
          .select()
          .eq('user_id', userId)
          .eq('code_type', codeType.name)
          .eq('verified', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Resend code (same as sending new code)
  Future<void> resendCode({
    required String userId,
    required TwoFactorCodeType codeType,
    String? email,
    String? phoneNumber,
  }) async {
    switch (codeType) {
      case TwoFactorCodeType.email:
        if (email == null) {
          throw TwoFactorException('Email is required');
        }
        await sendEmailCode(userId: userId, email: email);
        break;
      case TwoFactorCodeType.sms:
        if (phoneNumber == null) {
          throw TwoFactorException('Phone number is required');
        }
        await sendSMSCode(userId: userId, phoneNumber: phoneNumber);
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────

enum TwoFactorCodeType {
  email,
  sms;

  static TwoFactorCodeType fromString(String type) {
    return TwoFactorCodeType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => TwoFactorCodeType.email,
    );
  }
}

/// Custom exception for 2FA errors
class TwoFactorException implements Exception {
  final String message;
  TwoFactorException(this.message);

  @override
  String toString() => message;
}
