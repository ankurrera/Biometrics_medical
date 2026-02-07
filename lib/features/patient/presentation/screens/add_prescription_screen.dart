import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family/providers/family_provider.dart';
import '../../models/prescription_input_models.dart';
import '../../providers/patient_provider.dart';
import '../widgets/doctor_info_card_widget.dart';
import '../widgets/medication_card_widget.dart';
import '../widgets/prescription_upload_widget.dart';
import '../../../../services/supabase_service.dart';

class AddPrescriptionScreen extends ConsumerStatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  ConsumerState<AddPrescriptionScreen> createState() =>
      _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends ConsumerState<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Metadata
  DateTime _prescriptionDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  PrescriptionType _prescriptionType = PrescriptionType.newPrescription;

  // Doctor Details
  DoctorDetails _doctorDetails = const DoctorDetails(
    doctorName: '',
    hospitalClinicName: '',
    medicalRegistrationNumber: '',
  );

  // Upload
  PrescriptionUpload _prescriptionUpload = const PrescriptionUpload();

  // Notes
  final _diagnosisController = TextEditingController();
  final _doctorNotesController = TextEditingController();
  final _patientNotesController = TextEditingController();

  // Medications
  final List<MedicationDetails> _medications = [];

  // Flags
  bool? _allergiesMentioned;
  bool? _pregnancyBreastfeeding;
  bool? _chronicConditionLinked;
  bool _declarationAccepted = false;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _doctorNotesController.dispose();
    _patientNotesController.dispose();
    super.dispose();
  }

  void _addMedication() {
    setState(() {
      _medications.add(
        MedicationDetails(
          medicineName: '',
          dosage: '',
          frequency: '',
          duration: '',
          quantity: 0,
        ),
      );
    });
  }

  void _removeMedication(int index) {
    setState(() => _medications.removeAt(index));
  }

  void _updateMedication(int index, MedicationDetails details) {
    setState(() => _medications[index] = details);
  }

  Future<void> _selectDate(BuildContext context, bool isValidUntil) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isValidUntil ? _validUntil : _prescriptionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isValidUntil) {
          _validUntil = picked;
        } else {
          _prescriptionDate = picked;
          if (_validUntil.isBefore(_prescriptionDate)) {
            _validUntil = _prescriptionDate.add(const Duration(days: 30));
          }
        }
      });
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;
    if (_validUntil.isBefore(_prescriptionDate)) {
      _showError('Valid Until date must be after Prescription Date');
      return false;
    }
    if (!_doctorDetails.isValid) {
      _showError('Please complete all doctor information fields');
      return false;
    }
    if (_medications.isEmpty) {
      _showError('Please add at least one medication');
      return false;
    }
    if (!_prescriptionUpload.hasFile) {
      _showError('Please upload a prescription file');
      return false;
    }
    if (!_declarationAccepted) {
      _showError('Please accept the declaration to proceed');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Get the ACTIVE Patient Data (Family member or Self)
      final patient = await ref.read(patientDataProvider.future);

      if (patient == null) {
        throw Exception(
            'Patient profile not found. Please ensure the family member has a profile created.');
      }

      // 2. Prepare Data
      final prescriptionInput = CompletePrescriptionInput(
        metadata: PrescriptionMetadata(
          prescriptionDate: _prescriptionDate,
          validUntil: _validUntil,
          type: _prescriptionType,
        ),
        doctorDetails: _doctorDetails,
        diagnosis: _diagnosisController.text.trim(),
        doctorNotes: _doctorNotesController.text.trim().isNotEmpty
            ? _doctorNotesController.text.trim()
            : null,
        patientNotes: _patientNotesController.text.trim().isNotEmpty
            ? _patientNotesController.text.trim()
            : null,
        medications: _medications,
        safetyFlags: SafetyFlags(
          allergiesMentioned: _allergiesMentioned,
          pregnancyBreastfeeding: _pregnancyBreastfeeding,
          chronicConditionLinked: _chronicConditionLinked,
        ),
        upload: _prescriptionUpload,
        declarationAccepted: _declarationAccepted,
      );

      // 3. Submit to Supabase
      // Note: This relies on RLS policies in 'supabase/family_policies.sql'
      await SupabaseService.instance.createPrescription(
        patientId: patient.id,
        diagnosis: prescriptionInput.diagnosis,
        notes: prescriptionInput.patientNotes,
        isPublic: false,
        patientEntered: true,
        items: prescriptionInput.medications.map((m) => m.toJson()).toList(),
        metadata: prescriptionInput.toJson(),
      );

      // 4. Success
      ref.invalidate(patientPrescriptionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        // More descriptive error handling
        String errorMsg = e.toString();
        if (errorMsg.contains('policy') || errorMsg.contains('permission')) {
          errorMsg = 'Permission denied. Please ensure Database Policies are updated.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${errorMsg.replaceAll("Exception:", "").trim()}'),
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
    // Watch active context so UI updates for family members
    final profile = ref.watch(activeContextProfileProvider);
    final patient = ref.watch(patientDataProvider);

    return Scaffold(
      body: patient.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading patient data: $e')),
        data: (_) => Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Add Prescription'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                floating: true,
                snap: true,
              ),

              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildInfoBanner(),
                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionHeader('Prescription Details'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMetadataSection(),
                    const SizedBox(height: AppSpacing.lg),

                    // Updates to show active family member info
                    _buildSectionHeader('Patient Information'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildPatientCard(profile),
                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionHeader('Doctor / Issuer Details'),
                    const SizedBox(height: AppSpacing.sm),
                    DoctorInfoCardWidget(
                      onChanged: (details) => setState(() => _doctorDetails = details),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionHeader('Prescription Upload'),
                    const SizedBox(height: AppSpacing.sm),
                    PrescriptionUploadWidget(
                      onChanged: (upload) => setState(() => _prescriptionUpload = upload),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionHeader('Diagnosis & Notes'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildDiagnosisSection(),
                    const SizedBox(height: AppSpacing.lg),

                    _buildSectionHeader('Medications'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMedicationsHeader(),
                    const SizedBox(height: AppSpacing.md),
                  ]),
                ),
              ),

              // Medication List (Fixed scroll issues)
              _medications.isEmpty
                  ? SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverToBoxAdapter(
                  child: _buildEmptyMedicationsState(),
                ),
              )
                  : SliverPadding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding.left),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return MedicationCardWidget(
                        key: ValueKey(_medications[index].id),
                        index: index,
                        initialData: _medications[index],
                        onChanged: (details) =>
                            _updateMedication(index, details),
                        onRemove: () => _removeMedication(index),
                      );
                    },
                    childCount: _medications.length,
                  ),
                ),
              ),

              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader('Safety Information'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildSafetyFlags(),
                    const SizedBox(height: AppSpacing.lg),

                    _buildDeclaration(),
                    const SizedBox(height: AppSpacing.md),
                    _buildSubmitButton(),
                    const SizedBox(height: AppSpacing.xl),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Widget Helpers: _buildInfoBanner, _buildSectionHeader, etc. remain the same)
  // Re-include the same helper methods as before to ensure full file validity.

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This prescription will be marked as patient-entered input. Ensure all information is accurate.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: AppColors.primary),
            title: const Text('Prescription Date *'),
            subtitle:
            Text(DateFormat('MMM dd, yyyy').format(_prescriptionDate)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _selectDate(context, false),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
            const Icon(Icons.event_available, color: AppColors.primary),
            title: const Text('Valid Until *'),
            subtitle: Text(DateFormat('MMM dd, yyyy').format(_validUntil)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _selectDate(context, true),
            ),
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Prescription Type *',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<PrescriptionType>(
            segments: PrescriptionType.values.map((type) {
              return ButtonSegment<PrescriptionType>(
                value: type,
                label: Text(type.displayName),
              );
            }).toList(),
            selected: {_prescriptionType},
            onSelectionChanged: (Set<PrescriptionType> newSelection) {
              setState(() => _prescriptionType = newSelection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(AsyncValue<dynamic> profile) {
    return profile.when(
      data: (p) => p != null
          ? Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.patient.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.patient.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.patient.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: AppColors.patient, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.fullName.isNotEmpty ? p.fullName : 'Patient',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.patient,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Patient',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDiagnosisSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _diagnosisController,
            decoration: const InputDecoration(
                labelText: 'Diagnosis *',
                hintText: 'Enter diagnosis or condition',
                prefixIcon: Icon(Icons.healing_outlined, size: 20)),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return 'Diagnosis is required';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _doctorNotesController,
            decoration: const InputDecoration(
                labelText: 'Doctor Notes',
                hintText: "Doctor's notes or instructions"),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _patientNotesController,
            decoration: const InputDecoration(
                labelText: 'Patient Notes (Optional)',
                hintText: 'Your notes or observations'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('At least one medication required',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addMedication,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Medication'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pharmacist,
                foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMedicationsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: AppSpacing.sm),
          Text('No medications added',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildSafetyFlags() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSafetyOption(
              'Allergies mentioned in prescription?',
              _allergiesMentioned,
                  (val) => setState(() => _allergiesMentioned = val)),
          const Divider(),
          _buildSafetyOption(
              'Pregnancy / Breastfeeding considerations?',
              _pregnancyBreastfeeding,
                  (val) => setState(() => _pregnancyBreastfeeding = val)),
          const Divider(),
          _buildSafetyOption(
              'Linked to chronic condition?',
              _chronicConditionLinked,
                  (val) => setState(() => _chronicConditionLinked = val)),
        ],
      ),
    );
  }

  Widget _buildSafetyOption(
      String title, bool? value, Function(bool?) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<bool?>(
                value: true, groupValue: value, onChanged: onChanged),
            const Text('Yes', style: TextStyle(fontSize: 13)),
            Radio<bool?>(
                value: false, groupValue: value, onChanged: onChanged),
            const Text('No', style: TextStyle(fontSize: 13)),
            Radio<bool?>(
                value: null, groupValue: value, onChanged: onChanged),
            const Text('Unknown', style: TextStyle(fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildDeclaration() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _declarationAccepted
            ? AppColors.success.withOpacity(0.08)
            : AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: _declarationAccepted
                ? AppColors.success.withOpacity(0.3)
                : AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _declarationAccepted,
            onChanged: (val) => setState(() => _declarationAccepted = val!),
            activeColor: AppColors.success,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: () => setState(
                        () => _declarationAccepted = !_declarationAccepted),
                child: const Text(
                  'I confirm this prescription is genuine and issued by a licensed medical practitioner.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _declarationAccepted &&
        _prescriptionUpload.hasFile &&
        _medications.isNotEmpty &&
        !_isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white),
        child: _isLoading
            ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : const Text('Submit Prescription',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}