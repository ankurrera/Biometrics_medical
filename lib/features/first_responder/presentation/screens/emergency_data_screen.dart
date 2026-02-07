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

/// Displays emergency medical data for a patient.
/// Accepts either:
/// - [emergencyData]: Embedded data parsed directly from the QR code (no network needed)
/// - [qrCodeId]: A QR code ID to fetch data from the server (legacy flow)
class EmergencyDataScreen extends ConsumerWidget {
  final String? qrCodeId;
  final Map<String, dynamic>? emergencyData;

  const EmergencyDataScreen({super.key, this.qrCodeId, this.emergencyData})
      : assert(qrCodeId != null || emergencyData != null,
            'Either qrCodeId or emergencyData must be provided');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If we have embedded data from the QR code, use it directly
    if (emergencyData != null) {
      return Scaffold(
        backgroundColor: AppColors.firstResponder,
        body: SafeArea(
          child: _buildEmergencyView(context, emergencyData!),
        ),
      );
    }

    // Otherwise, fetch from server using qrCodeId
    final serverData = ref.watch(emergencyDataProvider(qrCodeId!));

    return Scaffold(
      backgroundColor: AppColors.firstResponder,
      body: SafeArea(
        child: serverData.when(
          data: (data) {
            if (data == null) return _buildNotFound(context);
            return _buildEmergencyView(context, _normalizeServerData(data));
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => _buildError(context),
        ),
      ),
    );
  }

  /// Normalize server-fetched data into the same format as embedded QR data.
  Map<String, dynamic> _normalizeServerData(Map<String, dynamic> data) {
    final patient = data['patient'] as Map<String, dynamic>? ?? {};
    final conditions = data['conditions'] as List? ?? [];
    final medications = data['medications'] as List? ?? [];

    final allergies = <Map<String, dynamic>>[];
    final chronicDiseases = <Map<String, dynamic>>[];

    for (final c in conditions) {
      final entry = {
        'description': c['description'],
        'severity': c['severity'],
      };
      if (c['type'] == 'allergy') {
        allergies.add(entry);
      } else {
        chronicDiseases.add(entry);
      }
    }

    return {
      'name': patient['full_name'] ?? 'Unknown',
      'blood_type': patient['blood_type'],
      'allergies': allergies,
      'chronic_diseases': chronicDiseases,
      'medications': medications,
      'emergency_contact': patient['emergency_contact'],
    };
  }

  Widget _buildEmergencyView(BuildContext context, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Unknown';
    final bloodType = data['blood_type'] as String?;
    final allergies = List<Map<String, dynamic>>.from(data['allergies'] ?? []);
    final chronicDiseases = List<Map<String, dynamic>>.from(data['chronic_diseases'] ?? []);
    final medications = List<Map<String, dynamic>>.from(data['medications'] ?? []);
    final emergencyContact = data['emergency_contact'] as Map<String, dynamic>?;

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
                // Blood Group (highlighted)
                _buildBloodTypeCard(name, bloodType),
                const SizedBox(height: 24),

                // Allergies (red alert)
                _buildSectionHeader(
                  icon: Icons.warning_rounded,
                  title: 'Allergies',
                  color: Colors.red,
                  badgeCount: allergies.length,
                ),
                const SizedBox(height: 12),
                if (allergies.isEmpty)
                  _buildEmptyCard('No known allergies')
                else
                  ...allergies.map((a) => _buildAllergyCard(a)),
                const SizedBox(height: 24),

                // Chronic Diseases
                _buildSectionHeader(
                  icon: Icons.monitor_heart_rounded,
                  title: 'Chronic Diseases',
                  color: Colors.orange,
                  badgeCount: chronicDiseases.length,
                ),
                const SizedBox(height: 12),
                if (chronicDiseases.isEmpty)
                  _buildEmptyCard('No chronic diseases listed')
                else
                  ...chronicDiseases.map((c) => _buildChronicCard(c)),
                const SizedBox(height: 24),

                // Current Medications
                _buildSectionHeader(
                  icon: Icons.medication_rounded,
                  title: 'Current Medications',
                  color: AppColors.primary,
                  badgeCount: medications.length,
                ),
                const SizedBox(height: 12),
                if (medications.isEmpty)
                  _buildEmptyCard('No current medications')
                else
                  ...medications.map((m) => _buildMedicationCard(m)),
                const SizedBox(height: 24),

                // Emergency Contacts (tap to call)
                _buildSectionHeader(
                  icon: Icons.phone_in_talk_rounded,
                  title: 'Emergency Contacts',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                if (emergencyContact == null)
                  _buildEmptyCard('No emergency contact listed')
                else
                  _buildContactCard(emergencyContact),
                const SizedBox(height: 24),
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
      decoration: BoxDecoration(
        color: AppColors.firstResponder,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (bloodType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop, color: AppColors.firstResponder, size: 28),
                  const SizedBox(width: 8),
                  const Text('BLOOD TYPE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.firstResponder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bloodType,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Blood type not set', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    int? badgeCount,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        if (badgeCount != null && badgeCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text('$badgeCount', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _buildAllergyCard(Map<String, dynamic> allergy) {
    final severity = allergy['severity'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
            child: Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allergy['description'] ?? 'Unknown allergy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red.shade900),
                ),
                if (severity != null)
                  Text(severity.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade400, letterSpacing: 0.5)),
              ],
            ),
          ),
          if (severity != null)
            _buildSeverityBadge(severity),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical':
        color = Colors.red.shade700;
        break;
      case 'severe':
        color = Colors.deepOrange;
        break;
      case 'moderate':
        color = Colors.orange;
        break;
      case 'mild':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(severity.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildChronicCard(Map<String, dynamic> condition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_heart_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              condition['description'] ?? 'Unknown condition',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.medication_rounded, color: AppColors.primary),
        ),
        title: Text(medication['medicine'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${medication['dosage'] ?? ''} • ${medication['frequency'] ?? ''}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final phone = contact['phone'] as String?;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.person, color: Colors.green.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      if (contact['relationship'] != null)
                        Text(contact['relationship'], style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            if (phone != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await launchUrl(Uri.parse('tel:$phone'));
                  },
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: Text('Call $phone', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('Error loading patient data', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('Patient not found', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}