import 'dart:typed_data'; // Added for Uint8List
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton service for Supabase database operations
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  // ─────────────────────────────────────────────────────────────────────────
  // AUTH HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  User? get currentUser => auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    if (currentUserId == null) return null;
    final response = await client
        .from('profiles')
        .select()
        .eq('id', currentUserId!)
        .maybeSingle();
    return response;
  }

  Future<void> upsertProfile(Map<String, dynamic> data) async {
    await client.from('profiles').upsert({
      'id': currentUserId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  // ... inside SupabaseService class ...

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPatientData({String? userId}) async {
    final targetId = userId ?? currentUserId;
    if (targetId == null) return null;

    try {
      // FIX: Changed 'patient_data' to 'patients'
      var response = await client
          .from('patients')
          .select()
          .eq('user_id', targetId)
          .maybeSingle();

      if (response == null) {
        try {
          // FIX: Changed 'patient_data' to 'patients'
          response = await client
              .from('patients')
              .insert({'user_id': targetId})
              .select()
              .single();
        } catch (insertError) {
          // FIX: Changed 'patient_data' to 'patients'
          response = await client
              .from('patients')
              .select()
              .eq('user_id', targetId)
              .maybeSingle();
        }
      }

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<void> upsertPatientData(Map<String, dynamic> data, {String? userId}) async {
    final targetId = userId ?? currentUserId;
    if (targetId == null) return;

    // FIX: Changed 'patient_data' to 'patients'
    await client.from('patients').upsert({
      'user_id': targetId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STORAGE OPERATIONS (NEW)
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads a file to Supabase Storage and returns the Public URL
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    try {
      await client.storage.from(bucket).uploadBinary(
        path,
        fileBytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );

      final publicUrl = client.storage.from(bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Storage Upload Error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRESCRIPTION OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPatientPrescriptions(
      String patientId) async {
    final response = await client
        .from('prescriptions')
        .select('*, prescription_items(*), doctor:profiles!doctor_id(*)')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// NEW: Get prescriptions created by the current doctor in the last 3 days
  Future<List<Map<String, dynamic>>> getDoctorRecentPrescriptions() async {
    if (currentUserId == null) return [];

    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    // We join 'patients' to get the patient reference,
    // then nested join 'profiles' (via patient's user_id) to get the name.
    final response = await client
        .from('prescriptions')
        .select('''
          *,
          patient:patients!patient_id(
            user_id,
            profiles:profiles!user_id(full_name)
          )
        ''')
        .eq('doctor_id', currentUserId!)
        .gte('created_at', threeDaysAgo.toIso8601String())
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createPrescription({
    required String patientId,
    required String diagnosis,
    String? notes,
    bool isPublic = false,
    bool patientEntered = false,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? metadata,
  }) async {
    final prescription = await client
        .from('prescriptions')
        .insert({
      'patient_id': patientId,
      'doctor_id': patientEntered ? null : currentUserId,
      'diagnosis': diagnosis,
      'notes': notes,
      'is_public': isPublic,
      'patient_entered': patientEntered,
      'metadata': metadata,
    })
        .select()
        .single();

    final prescriptionId = prescription['id'];
    for (final item in items) {
      await client.from('prescription_items').insert({
        'prescription_id': prescriptionId,
        ...item,
      });
    }

    return prescription;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISPENSING & OTHER OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> recordDispensing({
    required String prescriptionId,
    required String patientId,
    String? notes,
  }) async {
    await client.from('dispensing_records').insert({
      'prescription_id': prescriptionId,
      'pharmacist_id': currentUserId,
      'patient_id': patientId,
      'dispensed_at': DateTime.now().toIso8601String(),
      'notes': notes,
    });
  }

  Future<Map<String, dynamic>?> getEmergencyData(String qrCodeId) async {
    final patientData = await client
        .from('patients')
        .select('''
          id,
          blood_type,
          emergency_contact,
          profiles!inner(full_name)
        ''')
        .eq('qr_code_id', qrCodeId)
        .maybeSingle();

    if (patientData == null) return null;

    final patientId = patientData['id'];
    final profile = patientData['profiles'] as Map<String, dynamic>?;

    final conditions = await client
        .from('medical_conditions')
        .select('condition_type, description, severity')
        .eq('patient_id', patientId)
        .eq('is_public', true);

    final prescriptions = await client
        .from('prescriptions')
        .select('prescription_items(medicine_name, dosage, frequency)')
        .eq('patient_id', patientId)
        .eq('is_public', true)
        .eq('status', 'active');

    final medications = <Map<String, dynamic>>[];
    for (final rx in prescriptions) {
      final items = rx['prescription_items'] as List? ?? [];
      for (final item in items) {
        medications.add({
          'medicine': item['medicine_name'],
          'dosage': item['dosage'],
          'frequency': item['frequency'],
        });
      }
    }

    return {
      'patient': {
        'full_name': profile?['full_name'],
        'blood_type': patientData['blood_type'],
        'emergency_contact': patientData['emergency_contact'],
      },
      'conditions': List<Map<String, dynamic>>.from(conditions).map((c) => {
        'type': c['condition_type'],
        'description': c['description'],
        'severity': c['severity'],
      }).toList(),
      'medications': medications,
    };
  }

  Future<int> getTodaysPrescriptionCount() async {
    if (currentUserId == null) return 0;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final result = await client
        .from('prescriptions')
        .select('id')
        .eq('doctor_id', currentUserId!)
        .gte('created_at', startOfDay.toIso8601String());
    return (result as List).length;
  }

  Future<int> getTotalPrescriptionCount() async {
    if (currentUserId == null) return 0;
    final result = await client
        .from('prescriptions')
        .select('id')
        .eq('doctor_id', currentUserId!);
    return (result as List).length;
  }


  Future<int> getTodaysDispensingCount() async {
    if (currentUserId == null) return 0;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final result = await client
        .from('dispensing_records')
        .select('id')
        .eq('pharmacist_id', currentUserId!)
        .gte('dispensed_at', startOfDay.toIso8601String());
    return (result as List).length;
  }

  Future<void> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    await client.from('user_devices').insert({
      'user_id': currentUserId,
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'enrolled_at': DateTime.now().toIso8601String(),
      'last_used_at': DateTime.now().toIso8601String(),
      'is_active': true,
    });
  }
}