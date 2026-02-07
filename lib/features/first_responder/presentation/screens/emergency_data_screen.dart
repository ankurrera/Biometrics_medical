// lib/features/first_responder/presentation/screens/emergency_data_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/supabase_service.dart';

final emergencyDataProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, qrCodeId) async {
  return await SupabaseService.instance.getEmergencyData(qrCodeId);
});

class EmergencyDataScreen extends ConsumerWidget {
  final String qrCodeId;
  const EmergencyDataScreen({super.key, required this.qrCodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyData = ref.watch(emergencyDataProvider(qrCodeId));

    return Scaffold(
      backgroundColor: AppColors.firstResponder,
      body: SafeArea(
        child: emergencyData.when(
          data: (data) {
            if (data == null) return _buildNotFound(context);
            return _buildEmergencyData(context, data); // FIXED: Method restored below
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => _buildError(context),
        ),
      ),
    );
  }

  Widget _buildEmergencyData(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patient'] as Map<String, dynamic>?;
    final conditions = data['conditions'] as List? ?? [];
    final medications = data['medications'] as List? ?? [];

    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('EMERGENCY MEDICAL DATA', style: TextStyle(color: Colors.white, fontSize: 16)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                _buildBloodTypeCard(patient?['full_name'] ?? 'Unknown', patient?['blood_type']),
                const SizedBox(height: 24),
                if (conditions.isNotEmpty) ...[
                  const Text('Medical Conditions & Allergies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...conditions.map((c) => _buildConditionCard(c)),
                ],
                const SizedBox(height: 24),
                if (medications.isNotEmpty) ...[
                  const Text('Current Medications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...medications.map((m) => _buildMedicationCard(context, m)),
                ],
                const SizedBox(height: 24),
                if (patient?['emergency_contact'] != null) ...[
                  const Text('Emergency Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildContactCard(patient!['emergency_contact']),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodTypeCard(String name, String? bloodType) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.firstResponder, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (bloodType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop, color: AppColors.firstResponder),
                  const Text(' BLOOD TYPE: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(bloodType, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.firstResponder)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConditionCard(Map<String, dynamic> condition) {
    final bool isAllergy = condition['type'] == 'allergy';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAllergy ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAllergy ? Colors.red.shade200 : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(isAllergy ? Icons.warning_rounded : Icons.info_rounded, color: isAllergy ? Colors.red : Colors.orange),
          const SizedBox(width: 12),
          Expanded(child: Text(condition['description'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context, Map<String, dynamic> medication) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.medication, color: AppColors.primary),
        title: Text(medication['medicine'] ?? 'Unknown'),
        subtitle: Text('${medication['dosage'] ?? ''} - ${medication['frequency'] ?? ''}'),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return Card(
      child: ListTile(
        title: Text(contact['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(contact['relationship'] ?? 'Contact'),
        trailing: CircleAvatar(
          backgroundColor: Colors.green,
          child: IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () async {
              final phone = contact['phone'];
              if (phone != null) await launchUrl(Uri.parse('tel:$phone'));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(child: Text('Error loading patient data', style: TextStyle(color: Colors.white)));
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(child: Text('Patient not found', style: TextStyle(color: Colors.white, fontSize: 18)));
  }
}