import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for logging audit trails
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────
  // AUDIT LOGGING
  // ─────────────────────────────────────────────────────────────────

  /// Log an action to the audit trail
  Future<void> logAction({
    required AuditAction action,
    String? resourceType,
    String? resourceId,
    String? deviceId,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('audit_log').insert({
        'user_id': userId,
        'action': action.name,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'device_id': deviceId,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'metadata': metadata,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - audit logging should not break the main flow
      // In production, use proper logging framework
      // ignore: avoid_print
      assert(() {
        print('Failed to log audit action: $e');
        return true;
      }());
    }
  }

  /// Log user login
  Future<void> logLogin({
    required String deviceId,
    String? ipAddress,
    bool biometric = false,
  }) async {
    await logAction(
      action: biometric ? AuditAction.biometricLogin : AuditAction.login,
      deviceId: deviceId,
      ipAddress: ipAddress,
      metadata: {
        'biometric': biometric,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log user logout
  Future<void> logLogout({
    required String deviceId,
  }) async {
    await logAction(
      action: AuditAction.logout,
      deviceId: deviceId,
    );
  }

  /// Log KYC upload
  Future<void> logKYCUpload({
    required String documentType,
  }) async {
    await logAction(
      action: AuditAction.kycUpload,
      resourceType: 'kyc_document',
      metadata: {
        'document_type': documentType,
      },
    );
  }

  /// Log medical record access
  Future<void> logMedicalRecordAccess({
    required String recordId,
    required String deviceId,
  }) async {
    await logAction(
      action: AuditAction.viewMedicalRecord,
      resourceType: 'medical_record',
      resourceId: recordId,
      deviceId: deviceId,
    );
  }

  /// Log prescription view
  Future<void> logPrescriptionView({
    required String prescriptionId,
    required String deviceId,
  }) async {
    await logAction(
      action: AuditAction.viewPrescription,
      resourceType: 'prescription',
      resourceId: prescriptionId,
      deviceId: deviceId,
    );
  }

  /// Log device registration
  Future<void> logDeviceRegistration({
    required String deviceId,
    required String deviceName,
  }) async {
    await logAction(
      action: AuditAction.deviceRegistered,
      deviceId: deviceId,
      metadata: {
        'device_name': deviceName,
      },
    );
  }

  /// Log device revocation
  Future<void> logDeviceRevocation({
    required String deviceId,
  }) async {
    await logAction(
      action: AuditAction.deviceRevoked,
      deviceId: deviceId,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // AUDIT RETRIEVAL
  // ─────────────────────────────────────────────────────────────────

  /// Get audit logs for current user
  Future<List<AuditLog>> getUserAuditLogs({
    int limit = 50,
    AuditAction? actionFilter,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Build base query
      final baseQuery = _supabase.from('audit_log').select().eq('user_id', userId);

      // Build the complete query chain based on whether we have a filter
      final response = actionFilter != null
          ? await baseQuery
          .eq('action', actionFilter.name)
          .order('timestamp', ascending: false)
          .limit(limit)
          : await baseQuery
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => AuditLog.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw AuditException('Failed to get audit logs: ${e.message}');
    } catch (e) {
      throw AuditException('Failed to get audit logs: $e');
    }
  }

  /// Get recent login history
  Future<List<AuditLog>> getLoginHistory({int limit = 10}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('audit_log')
          .select()
          .eq('user_id', userId)
          .inFilter('action', ['login', 'biometric_login'])
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => AuditLog.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────

enum AuditAction {
  login,
  biometricLogin,
  logout,
  signUp,
  kycUpload,
  kycVerified,
  viewMedicalRecord,
  viewPrescription,
  createPrescription,
  updatePrescription,
  deviceRegistered,
  deviceRevoked,
  twoFactorSent,
  twoFactorVerified,
  passwordChanged,
  profileUpdated,
  emergencyAccessGranted,
  emergencyAccessRevoked,
  patientNotified;

  static AuditAction fromString(String action) {
    return AuditAction.values.firstWhere(
          (e) => e.name == action,
      orElse: () => AuditAction.login,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────

class AuditLog {
  final String id;
  final String? userId;
  final AuditAction action;
  final String? resourceType;
  final String? resourceId;
  final String? deviceId;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    this.userId,
    required this.action,
    this.resourceType,
    this.resourceId,
    this.deviceId,
    this.ipAddress,
    this.userAgent,
    this.metadata,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      action: AuditAction.fromString(json['action'] as String),
      resourceType: json['resource_type'] as String?,
      resourceId: json['resource_id'] as String?,
      deviceId: json['device_id'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'action': action.name,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'device_id': deviceId,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get actionDisplay {
    switch (action) {
      case AuditAction.login:
        return 'Logged in';
      case AuditAction.biometricLogin:
        return 'Logged in (Biometric)';
      case AuditAction.logout:
        return 'Logged out';
      case AuditAction.signUp:
        return 'Signed up';
      case AuditAction.kycUpload:
        return 'Uploaded KYC document';
      case AuditAction.kycVerified:
        return 'KYC verified';
      case AuditAction.viewMedicalRecord:
        return 'Viewed medical record';
      case AuditAction.viewPrescription:
        return 'Viewed prescription';
      case AuditAction.createPrescription:
        return 'Created prescription';
      case AuditAction.updatePrescription:
        return 'Updated prescription';
      case AuditAction.deviceRegistered:
        return 'Registered device';
      case AuditAction.deviceRevoked:
        return 'Revoked device';
      case AuditAction.twoFactorSent:
        return '2FA code sent';
      case AuditAction.twoFactorVerified:
        return '2FA verified';
      case AuditAction.passwordChanged:
        return 'Changed password';
      case AuditAction.profileUpdated:
        return 'Updated profile';
      case AuditAction.emergencyAccessGranted:
        return 'Emergency access granted';
      case AuditAction.emergencyAccessRevoked:
        return 'Emergency access revoked';
      case AuditAction.patientNotified:
        return 'Patient notified';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }
}

/// Custom exception for audit errors
class AuditException implements Exception {
  final String message;
  AuditException(this.message);

  @override
  String toString() => message;
}