import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/env_config.dart';

/// Service for handling KYC (Know Your Customer) verification via Didit
class KYCService {
  KYCService._();
  static final KYCService instance = KYCService._();

  final _supabase = Supabase.instance.client;

  /// Creates a Didit verification session.
  Future<String?> createDiditSession() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw KYCException('User not authenticated');
      }

      final requestBody = {
        'vendor_data': userId,
        'app_id': EnvConfig.diditAppId,
        'callback_url': 'https://caresync.app/verify-callback',
        'features': ['id_document', 'face_match', 'liveness'],
      };

      final response = await http.post(
        Uri.parse('https://verification.didit.me/v3/sessions/'),
        headers: {
          'x-api-key': EnvConfig.diditApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url'] as String;
      } else {
        final errorData = jsonDecode(response.body);
        throw KYCException('Didit API Error: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      throw KYCException('Failed to initialize verification: $e');
    }
  }

  /// Get KYC verification status for current user from Supabase
  Future<KYCVerification?> getKYCStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('kyc_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return KYCVerification.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has verified KYC
  Future<bool> isKYCVerified([String? userId]) async {
    try {
      final targetUserId = userId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) return false;

      final res = await _supabase
          .from('kyc_verifications')
          .select('kyc_status')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return false;

      return res['kyc_status']?.toString().toLowerCase() == 'verified';
    } catch (e) {
      return false;
    }
  }
}

// Models
enum KYCStatus {
  pending,
  verified,
  rejected,
  review;

  static KYCStatus fromString(String status) {
    return KYCStatus.values.firstWhere(
          (e) => e.name == status.toLowerCase(),
      orElse: () => KYCStatus.pending,
    );
  }
}

class KYCVerification {
  final String id;
  final String userId;
  final KYCStatus status;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  KYCVerification({
    required this.id,
    required this.userId,
    required this.status,
    this.rejectionReason,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KYCVerification.fromJson(Map<String, dynamic> json) {
    return KYCVerification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: KYCStatus.fromString(json['kyc_status'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class KYCException implements Exception {
  final String message;
  KYCException(this.message);
  @override
  String toString() => message;
}

// *** CRITICAL FIX: Adding this class fixes the "Undefined name" error in other files ***
class KYCRequiredException extends KYCException {
  KYCRequiredException([String? message])
      : super(message ?? 'KYC verification required to access this feature');
}