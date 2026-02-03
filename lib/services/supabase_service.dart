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

  /// Sign up with email and password
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

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get current user's profile
  Future<Map<String, dynamic>?> getProfile() async {
    if (currentUserId == null) return null;

    final response = await client
        .from('profiles')
        .select()
        .eq('id', currentUserId!)
        .maybeSingle();

    return response;
  }

  /// Create or update user profile
  Future<void> upsertProfile(Map<String, dynamic> data) async {
    await client.from('profiles').upsert({
      'id': currentUserId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Register a new device for biometric auth
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

  /// Update device last used timestamp
  Future<void> updateDeviceLastUsed(String deviceId) async {
    await client
        .from('user_devices')
        .update({'last_used_at': DateTime.now().toIso8601String()})
        .eq('device_id', deviceId)
        .eq('user_id', currentUserId!);
  }

  /// Get all devices for current user
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    final response = await client
        .from('user_devices')
        .select()
        .eq('user_id', currentUserId!)
        .eq('is_active', true)
        .order('last_used_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Deactivate a device
  Future<void> deactivateDevice(String deviceId) async {
    await client
        .from('user_devices')
        .update({'is_active': false})
        .eq('device_id', deviceId)
        .eq('user_id', currentUserId!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get patient data for current user (auto-creates if doesn't exist)
  Future<Map<String, dynamic>?> getPatientData() async {
    if (currentUserId == null) return null;

    // Try to get existing patient record
    var response = await client
        .from('patients')
        .select()
        .eq('user_id', currentUserId!)
        .maybeSingle();

    // If no patient record exists, create one
    if (response == null) {
      try {
        response = await client
            .from('patients')
            .insert({'user_id': currentUserId})
            .select()
            .single();
      } catch (e) {
        // If insert fails (e.g., RLS), try to get again (might have been created)
        response = await client
            .from('patients')
            .select()
            .eq('user_id', currentUserId!)
            .maybeSingle();
      }
    }

    return response;
  }
  
  /// Ensure patient record exists for current user
  Future<String?> ensurePatientExists() async {
    final data = await getPatientData();
    return data?['id'] as String?;
  }

  /// Create or update patient data
  Future<void> upsertPatientData(Map<String, dynamic> data) async {
    await client.from('patients').upsert({
      'user_id': currentUserId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRESCRIPTION OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get prescriptions for a patient
  Future<List<Map<String, dynamic>>> getPatientPrescriptions(
      String patientId) async {
    final response = await client
        .from('prescriptions')
        .select('*, prescription_items(*), doctor:profiles!doctor_id(*)')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a new prescription
  Future<Map<String, dynamic>> createPrescription({
    required String patientId,
    required String diagnosis,
    String? notes,
    bool isPublic = false,
    bool patientEntered = false,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? metadata,
  }) async {
    // Create prescription
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

    // Add prescription items
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
  // DISPENSING OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Record a dispensing transaction
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

  // ─────────────────────────────────────────────────────────────────────────
  // EMERGENCY ACCESS (PUBLIC DATA)
  // ─────────────────────────────────────────────────────────────────────────

  /// Get public emergency data for a patient by QR code ID
  /// Returns formatted data for emergency display
  Future<Map<String, dynamic>?> getEmergencyData(String qrCodeId) async {
    // Get patient with profile and public conditions
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

    // Get public medical conditions
    final conditions = await client
        .from('medical_conditions')
        .select('condition_type, description, severity')
        .eq('patient_id', patientId)
        .eq('is_public', true);

    // Get active public prescription medications
    final prescriptions = await client
        .from('prescriptions')
        .select('prescription_items(medicine_name, dosage, frequency)')
        .eq('patient_id', patientId)
        .eq('is_public', true)
        .eq('status', 'active');

    // Flatten medications from all prescriptions
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

    // Return formatted data
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

  // ─────────────────────────────────────────────────────────────────────────
  // STATS HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get today's prescription count for a doctor
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

  /// Get total prescription count for a doctor
  Future<int> getTotalPrescriptionCount() async {
    if (currentUserId == null) return 0;
    
    final result = await client
        .from('prescriptions')
        .select('id')
        .eq('doctor_id', currentUserId!);
    
    return (result as List).length;
  }

  /// Get today's dispensing count for a pharmacist
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
}

