import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/audit_service.dart';

class NewPrescriptionScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const NewPrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<NewPrescriptionScreen> createState() =>
      _NewPrescriptionScreenState();
}

class _NewPrescriptionScreenState
    extends ConsumerState<NewPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isPublic = false;
  bool _isLoading = false;

  final List<_MedicationEntry> _medications = [];

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    for (final med in _medications) {
      med.dispose();
    }
    super.dispose();
  }

  void _addMedication() {
    setState(() {
      _medications.add(_MedicationEntry());
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications[index].dispose();
      _medications.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one medication'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Require biometric authentication before submitting prescription
    final authenticated = await showBiometricAuthDialog(
      context: context,
      reason: 'Authenticate to sign and submit prescription',
      allowBiometricOnly: false,
    );

    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication required to submit prescription'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create prescription with biometric verification metadata
      await SupabaseService.instance.createPrescription(
        patientId: widget.patientId,
        diagnosis: _diagnosisController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        isPublic: _isPublic,
        items: _medications.map((med) => med.toJson()).toList(),
        // Add metadata for biometric verification
        metadata: {
          'biometric_verified': true,
          'signed_at': DateTime.now().toIso8601String(),
        },
      );

      // Log the action in audit trail
      await AuditService.instance.logAction(
        action: AuditAction.createPrescription,
        resourceType: 'prescription',
        metadata: {
          'patient_id': widget.patientId,
          'biometric_verified': true,
          'signed_at': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription created and signed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Prescription'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Patient info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.doctor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.doctor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.doctor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.doctor,
                          ),
                        ),
                        Text(
                          widget.patientName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Diagnosis
            const Text(
              'Diagnosis',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                hintText: 'Enter diagnosis',
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a diagnosis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Notes
            const Text(
              'Notes (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Additional notes',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            // Medications
            Row(
              children: [
                const Text(
                  'Medications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addMedication,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_medications.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 40,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No medications added',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_medications.length, (index) {
                return _buildMedicationCard(index);
              }),
            const SizedBox(height: 24),
            // Public toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                    color: _isPublic ? AppColors.warning : AppColors.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Make Public',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Visible to first responders via QR',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Prescription'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int index) {
    final med = _medications[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.pharmacist.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.pharmacist,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Medication',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeMedication(index),
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: med.nameController,
            decoration: const InputDecoration(
              labelText: 'Medicine Name',
              hintText: 'e.g., Paracetamol',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: med.dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    hintText: 'e.g., 500mg',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: med.frequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    hintText: 'e.g., Twice daily',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: med.durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    hintText: 'e.g., 7 days',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: med.quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'e.g., 14',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: med.instructionsController,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              hintText: 'e.g., Take after meals',
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationEntry {
  final nameController = TextEditingController();
  final dosageController = TextEditingController();
  final frequencyController = TextEditingController();
  final durationController = TextEditingController();
  final quantityController = TextEditingController();
  final instructionsController = TextEditingController();

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    quantityController.dispose();
    instructionsController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': nameController.text.trim(),
      'dosage': dosageController.text.trim(),
      'frequency': frequencyController.text.trim(),
      'duration': durationController.text.trim().isNotEmpty
          ? durationController.text.trim()
          : null,
      'quantity': quantityController.text.trim().isNotEmpty
          ? int.tryParse(quantityController.text.trim())
          : null,
      'instructions': instructionsController.text.trim().isNotEmpty
          ? instructionsController.text.trim()
          : null,
    };
  }
}

