import 'package:supabase_flutter/supabase_flutter.dart';
import 'biometric_service.dart';
import 'audit_service.dart';

/// Service for managing emergency "break glass" access to patient records
/// Only available to doctors and first responders
class EmergencyAccessService {
  EmergencyAccessService._();
  static final EmergencyAccessService instance = EmergencyAccessService._();

  final _supabase = Supabase.instance.client;
  final _biometric = BiometricService.instance;
  final _audit = AuditService.instance;

  // Emergency access timeout duration (15 minutes)
  static const _accessTimeoutMinutes = 15;

  /// Request emergency access to a patient's records
  /// Requires biometric authentication
  /// Returns the emergency access record ID if successful
  Future<String?> requestEmergencyAccess({
    required String patientId,
    required String reason,
    String? additionalNotes,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw EmergencyAccessException('User not authenticated');
    }

    // Get user role from profile
    final profile = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', currentUser.id)
        .single();

    final role = profile['role'] as String;

    // Only doctors and first responders can request emergency access
    if (role != 'doctor' && role != 'first_responder') {
      throw EmergencyAccessException(
        'Only doctors and first responders can request emergency access',
      );
    }

    // Require biometric authentication
    final isAvailable = await _biometric.isBiometricAvailable();
    
    if (!isAvailable) {
      throw EmergencyAccessException(
        'Biometric authentication is not available',
      );
    }

    final authenticated = await _biometric.authenticate(
      reason: 'Authenticate for emergency "break glass" access',
      biometricOnly: true,
    );

    if (!authenticated) {
      throw EmergencyAccessException('Biometric authentication failed');
    }

    // Create emergency access record
    final accessRecord = await _supabase
        .from('emergency_access')
        .insert({
          'requester_id': currentUser.id,
          'requester_role': role,
          'patient_id': patientId,
          'reason': reason,
          'additional_notes': additionalNotes,
          'granted_at': DateTime.now().toIso8601String(),
          'expires_at': DateTime.now()
              .add(const Duration(minutes: _accessTimeoutMinutes))
              .toIso8601String(),
          'biometric_verified': true,
          'status': 'active',
        })
        .select()
        .single();

    final accessId = accessRecord['id'] as String;

    // Log the emergency access in audit trail
    await _audit.logAction(
      action: AuditAction.emergencyAccessGranted,
      resourceType: 'patient',
      resourceId: patientId,
      metadata: {
        'access_id': accessId,
        'reason': reason,
        'expires_at': accessRecord['expires_at'],
        'biometric_verified': true,
      },
    );

    assert(() {
      print('[EMERGENCY] Emergency access granted: $accessId');
      return true;
    }());

    return accessId;
  }

  /// Check if user has active emergency access to a patient
  Future<bool> hasActiveAccess(String patientId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return false;

    try {
      final now = DateTime.now().toIso8601String();

      final result = await _supabase
          .from('emergency_access')
          .select('id')
          .eq('requester_id', currentUser.id)
          .eq('patient_id', patientId)
          .eq('status', 'active')
          .gt('expires_at', now)
          .maybeSingle();

      return result != null;
    } catch (e) {
      assert(() {
        print('[EMERGENCY] Error checking access: $e');
        return true;
      }());
      return false;
    }
  }

  /// Revoke emergency access manually
  Future<void> revokeAccess(String accessId) async {
    await _supabase
        .from('emergency_access')
        .update({
          'status': 'revoked',
          'revoked_at': DateTime.now().toIso8601String(),
        })
        .eq('id', accessId);

    // Log the revocation
    await _audit.logAction(
      action: AuditAction.emergencyAccessRevoked,
      resourceType: 'emergency_access',
      resourceId: accessId,
      metadata: {
        'revoked_at': DateTime.now().toIso8601String(),
      },
    );

    assert(() {
      print('[EMERGENCY] Emergency access revoked: $accessId');
      return true;
    }());
  }

  /// Auto-revoke expired emergency access records
  /// This should be called periodically (e.g., by a cron job or cloud function)
  Future<void> revokeExpiredAccess() async {
    final now = DateTime.now().toIso8601String();

    await _supabase
        .from('emergency_access')
        .update({
          'status': 'expired',
        })
        .eq('status', 'active')
        .lt('expires_at', now);

    assert(() {
      print('[EMERGENCY] Expired emergency access records revoked');
      return true;
    }());
  }

  /// Get active emergency access records for current user
  Future<List<EmergencyAccessRecord>> getActiveAccessRecords() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      final now = DateTime.now().toIso8601String();

      final results = await _supabase
          .from('emergency_access')
          .select('*, profiles!emergency_access_patient_id_fkey(full_name, email)')
          .eq('requester_id', currentUser.id)
          .eq('status', 'active')
          .gt('expires_at', now)
          .order('granted_at', ascending: false);

      return (results as List)
          .map((json) => EmergencyAccessRecord.fromJson(json))
          .toList();
    } catch (e) {
      assert(() {
        print('[EMERGENCY] Error fetching access records: $e');
        return true;
      }());
      return [];
    }
  }

  /// Get emergency access history for a patient (for notifications)
  Future<List<EmergencyAccessRecord>> getPatientAccessHistory(
    String patientId, {
    int limit = 10,
  }) async {
    try {
      final results = await _supabase
          .from('emergency_access')
          .select('*, profiles!emergency_access_requester_id_fkey(full_name, email, role)')
          .eq('patient_id', patientId)
          .order('granted_at', ascending: false)
          .limit(limit);

      return (results as List)
          .map((json) => EmergencyAccessRecord.fromJson(json))
          .toList();
    } catch (e) {
      assert(() {
        print('[EMERGENCY] Error fetching access history: $e');
        return true;
      }());
      return [];
    }
  }

  /// Hook for patient notification when emergency access is granted
  /// In production, this would send a push notification or email
  Future<void> notifyPatient(String patientId, String accessId) async {
    // TODO: Implement notification logic
    // This could be:
    // - Push notification via FCM
    // - Email notification
    // - SMS notification
    // - In-app notification

    assert(() {
      print('[EMERGENCY] Patient notification hook called for patient: $patientId');
      return true;
    }());

    // For now, just create an audit log entry
    await _audit.logAction(
      action: AuditAction.patientNotified,
      resourceType: 'patient',
      resourceId: patientId,
      metadata: {
        'notification_type': 'emergency_access',
        'access_id': accessId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}

/// Model for emergency access record
class EmergencyAccessRecord {
  final String id;
  final String requesterId;
  final String requesterRole;
  final String patientId;
  final String reason;
  final String? additionalNotes;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final bool biometricVerified;
  final String status;
  final Map<String, dynamic>? patientInfo;
  final Map<String, dynamic>? requesterInfo;

  EmergencyAccessRecord({
    required this.id,
    required this.requesterId,
    required this.requesterRole,
    required this.patientId,
    required this.reason,
    this.additionalNotes,
    required this.grantedAt,
    required this.expiresAt,
    this.revokedAt,
    required this.biometricVerified,
    required this.status,
    this.patientInfo,
    this.requesterInfo,
  });

  factory EmergencyAccessRecord.fromJson(Map<String, dynamic> json) {
    return EmergencyAccessRecord(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      requesterRole: json['requester_role'] as String,
      patientId: json['patient_id'] as String,
      reason: json['reason'] as String,
      additionalNotes: json['additional_notes'] as String?,
      grantedAt: DateTime.parse(json['granted_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      biometricVerified: json['biometric_verified'] as bool? ?? false,
      status: json['status'] as String,
      patientInfo: json['profiles'] as Map<String, dynamic>?,
      requesterInfo: json.containsKey('profiles')
          ? json['profiles'] as Map<String, dynamic>?
          : null,
    );
  }

  Duration get remainingTime => expiresAt.difference(DateTime.now());
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => status == 'active' && !isExpired;
}

/// Custom exception for emergency access errors
class EmergencyAccessException implements Exception {
  final String message;
  EmergencyAccessException(this.message);

  @override
  String toString() => message;
}
