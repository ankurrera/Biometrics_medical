import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

final patientSettingsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return null;
  
  final result = await supabase
      .from('patients')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  
  return result;
});

final publicPrescriptionsCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return 0;
  
  final patientResult = await supabase
      .from('patients')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();
  
  if (patientResult == null) return 0;
  
  final result = await supabase
      .from('prescriptions')
      .select('id')
      .eq('patient_id', patientResult['id'])
      .eq('is_public', true);
  
  return (result as List).length;
});

final publicConditionsCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return 0;
  
  final patientResult = await supabase
      .from('patients')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();
  
  if (patientResult == null) return 0;
  
  final result = await supabase
      .from('medical_conditions')
      .select('id')
      .eq('patient_id', patientResult['id'])
      .eq('is_public', true);
  
  return (result as List).length;
});

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientSettings = ref.watch(patientSettingsProvider);
    final publicPrescriptions = ref.watch(publicPrescriptionsCountProvider);
    final publicConditions = ref.watch(publicConditionsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: patientSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text('Error: $error'),
              TextButton(
                onPressed: () => ref.refresh(patientSettingsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (patient) {
          return SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Control what information is visible when your emergency QR code is scanned by first responders.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency Data Summary
                const Text(
                  'Emergency Data Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        icon: Icons.medical_information,
                        label: 'Public Conditions',
                        value: publicConditions.valueOrNull?.toString() ?? '-',
                        color: AppColors.patient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        icon: Icons.description,
                        label: 'Public Prescriptions',
                        value: publicPrescriptions.valueOrNull?.toString() ?? '-',
                        color: AppColors.doctor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Profile Information
                const Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                _buildSettingTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Full Name',
                  subtitle: 'Always visible to first responders',
                  isPublic: true,
                  locked: true,
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.bloodtype_outlined,
                  title: 'Blood Type',
                  subtitle: patient?['blood_type'] ?? 'Not set',
                  isPublic: true,
                  locked: true,
                  onEdit: () => _showBloodTypeDialog(context, ref, patient?['blood_type']),
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.emergency_outlined,
                  title: 'Emergency Contact',
                  subtitle: patient?['emergency_contact'] != null 
                      ? 'Set' 
                      : 'Not set',
                  isPublic: true,
                  locked: true,
                  onEdit: () => _showEmergencyContactDialog(context, ref, patient?['emergency_contact']),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.visibility_off, color: AppColors.warning),
                        title: const Text('Make All Conditions Private'),
                        subtitle: const Text('Hide all medical conditions from QR'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _makeAllConditionsPrivate(context, ref),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.visibility, color: AppColors.success),
                        title: const Text('Make All Conditions Public'),
                        subtitle: const Text('Show all medical conditions in QR'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _makeAllConditionsPublic(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Danger Zone
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.qr_code, color: AppColors.error),
                    title: const Text('Regenerate QR Code'),
                    subtitle: const Text('Old QR codes will stop working'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _regenerateQrCode(context, ref),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPublic,
    bool locked = false,
    VoidCallback? onEdit,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isPublic ? AppColors.success : AppColors.warning).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    locked ? Icons.lock : (isPublic ? Icons.public : Icons.lock),
                    size: 14,
                    color: isPublic ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPublic ? 'Public' : 'Private',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isPublic ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBloodTypeDialog(BuildContext context, WidgetRef ref, String? currentType) async {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    String? selectedType = currentType;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Blood Type'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bloodTypes.map((type) {
            return ChoiceChip(
              label: Text(type),
              selected: selectedType == type,
              onSelected: (selected) {
                selectedType = selected ? type : null;
                Navigator.pop(context, selectedType);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ).then((value) async {
      if (value != null) {
        await _updatePatientField(context, ref, 'blood_type', value);
      }
    });
  }

  Future<void> _showEmergencyContactDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? current) async {
    final nameController = TextEditingController(text: current?['name']);
    final phoneController = TextEditingController(text: current?['phone']);
    final relationshipController = TextEditingController(text: current?['relationship']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationshipController,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                hintText: 'e.g., Spouse, Parent',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final contact = {
                'name': nameController.text,
                'phone': phoneController.text,
                'relationship': relationshipController.text,
              };
              await _updatePatientField(context, ref, 'emergency_contact', contact);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePatientField(BuildContext context, WidgetRef ref, String field, dynamic value) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) return;
      
      await supabase
          .from('patients')
          .upsert({
            'user_id': userId,
            field: value,
          }, onConflict: 'user_id');
      
      ref.invalidate(patientSettingsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _makeAllConditionsPrivate(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make All Private'),
        content: const Text('This will hide all your medical conditions from first responders scanning your QR code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) return;
      
      final patientResult = await supabase
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (patientResult == null) return;
      
      await supabase
          .from('medical_conditions')
          .update({'is_public': false})
          .eq('patient_id', patientResult['id']);
      
      ref.invalidate(publicConditionsCountProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All conditions are now private')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _makeAllConditionsPublic(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make All Public'),
        content: const Text('This will make all your medical conditions visible to first responders scanning your QR code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) return;
      
      final patientResult = await supabase
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (patientResult == null) return;
      
      await supabase
          .from('medical_conditions')
          .update({'is_public': true})
          .eq('patient_id', patientResult['id']);
      
      ref.invalidate(publicConditionsCountProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All conditions are now public')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _regenerateQrCode(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate QR Code'),
        content: const Text(
          'This will create a new QR code and invalidate your old one. '
          'Any printed cards or stickers with the old QR code will stop working. '
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) return;
      
      // Generate new UUID for QR code
      final newQrCodeId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await supabase
          .from('patients')
          .update({'qr_code_id': newQrCodeId})
          .eq('user_id', userId);
      
      ref.invalidate(patientSettingsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code regenerated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

