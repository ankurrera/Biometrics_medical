import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/kyc_service.dart';
import '../models/patient_data.dart';
import '../models/prescription.dart';

/// Provider to check if KYC is verified
final isKycVerifiedProvider = FutureProvider<bool>((ref) async {
  final kyc = await ref.watch(kycStatusProvider.future);
  return kyc?.status == KYCStatus.verified;
});

/// Provider for current patient data - tied to auth state for proper invalidation
final patientDataProvider = FutureProvider<PatientData?>((ref) async {
  // Watch auth state to invalidate when user changes
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  
  final data = await SupabaseService.instance.getPatientData();
  if (data == null) return null;
  return PatientData.fromJson(data);
});

/// Provider for patient prescriptions
final patientPrescriptionsProvider =
    FutureProvider<List<Prescription>>((ref) async {
  final patientData = await ref.watch(patientDataProvider.future);
  if (patientData == null) return [];

  final data =
      await SupabaseService.instance.getPatientPrescriptions(patientData.id);
  return data.map((json) => Prescription.fromJson(json)).toList();
});

/// Provider for medical conditions - KYC verification required
final medicalConditionsProvider =
    FutureProvider<List<MedicalCondition>>((ref) async {
  // Check KYC status first
  final isKycVerified = await ref.watch(isKycVerifiedProvider.future);
  if (!isKycVerified) {
    throw KYCRequiredException('KYC verification required to access medical records');
  }

  final patientData = await ref.watch(patientDataProvider.future);
  if (patientData == null) return [];

  final response = await SupabaseService.instance.client
      .from('medical_conditions')
      .select()
      .eq('patient_id', patientData.id)
      .order('created_at', ascending: false);

  return (response as List)
      .map((json) => MedicalCondition.fromJson(json))
      .toList();
});

/// Notifier for managing patient data
class PatientNotifier extends StateNotifier<AsyncValue<PatientData?>> {
  PatientNotifier() : super(const AsyncValue.loading()) {
    _loadPatient();
  }

  final _supabase = SupabaseService.instance;

  Future<void> _loadPatient() async {
    try {
      final data = await _supabase.getPatientData();
      if (data == null) {
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.data(PatientData.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePatientData({
    String? bloodType,
    DateTime? dateOfBirth,
    Map<String, String>? emergencyContact,
  }) async {
    try {
      await _supabase.upsertPatientData({
        if (bloodType != null) 'blood_type': bloodType,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
        if (emergencyContact != null) 'emergency_contact': emergencyContact,
      });
      await _loadPatient();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addMedicalCondition({
    required String conditionType,
    required String description,
    String? severity,
    bool isPublic = true,
  }) async {
    try {
      final patientData = state.valueOrNull;
      if (patientData == null) return;

      await _supabase.client.from('medical_conditions').insert({
        'patient_id': patientData.id,
        'condition_type': conditionType,
        'description': description,
        'severity': severity,
        'is_public': isPublic,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleConditionVisibility(String conditionId, bool isPublic) async {
    try {
      await _supabase.client
          .from('medical_conditions')
          .update({'is_public': isPublic})
          .eq('id', conditionId);
    } catch (e) {
      rethrow;
    }
  }
}

final patientNotifierProvider =
    StateNotifierProvider<PatientNotifier, AsyncValue<PatientData?>>((ref) {
  return PatientNotifier();
});

