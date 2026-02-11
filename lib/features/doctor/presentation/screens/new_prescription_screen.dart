import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/audit_service.dart';
// Import auth/profile provider to get Doctor's name
import '../../../shared/models/user_profile.dart';
import '../../../auth/providers/auth_provider.dart';

// Imports for parity
import '../../../patient/models/prescription_input_models.dart';

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

class _NewPrescriptionScreenState extends ConsumerState<NewPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isPublic = false;
  bool _isLoading = false;

  // Metadata Fields
  DateTime _prescriptionDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  PrescriptionType _prescriptionType = PrescriptionType.newPrescription;

  // Safety Flags
  bool? _allergiesMentioned;
  bool? _pregnancyBreastfeeding;
  bool? _chronicConditionLinked;

  final List<_MedicationEntry> _medications = [];

  // Mock Data for Autocomplete
  final List<String> _commonDiagnoses = [
    'Viral Fever', 'Hypertension', 'Type 2 Diabetes', 'Acute Bronchitis', 'Migraine', 'Gastritis'
  ];

  final List<String> _commonMedicines = [
    'Paracetamol 500mg', 'Amoxicillin 500mg', 'Metformin 500mg', 'Cetirizine 10mg',
    'Ibuprofen 400mg', 'Omeprazole 20mg', 'Azithromycin 500mg'
  ];

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

  Future<void> _selectDate(BuildContext context, bool isValidUntil) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isValidUntil ? _validUntil : _prescriptionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.doctor, // Doctor branding color
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
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

  Future<void> _submit(UserProfile? doctorProfile) async {
    if (!_formKey.currentState!.validate()) return;

    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one medication'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Biometric Guard
    final authenticated = await showBiometricAuthDialog(
      context: context,
      reason: 'Verify identity to sign prescription',
      allowBiometricOnly: false,
    );

    if (!authenticated) return;

    setState(() => _isLoading = true);

    try {
      // 1. Prepare Doctor Details Metadata
      final doctorDetails = {
        'doctor_name': doctorProfile?.fullName ?? 'Dr. Unknown',
        'hospital_clinic_name': doctorProfile?.hospitalName ?? 'Private Practice',
        'specialization': doctorProfile?.specialization ?? '',
        'medical_registration_number': doctorProfile?.medicalRegNumber ?? '',
        'signature_uploaded': true, // Digital signature verified by biometric
      };

      // 2. Prepare Complete Metadata
      final metadata = {
        'biometric_verified': true,
        'signed_at': DateTime.now().toIso8601String(),
        'prescription_date': _prescriptionDate.toIso8601String(),
        'valid_until': _validUntil.toIso8601String(),
        'type': _prescriptionType.name,
        'doctor_details': doctorDetails,
        'safety_flags': {
          'allergies_mentioned': _allergiesMentioned,
          'pregnancy_breastfeeding': _pregnancyBreastfeeding,
          'chronic_condition_linked': _chronicConditionLinked,
        },
      };

      await SupabaseService.instance.createPrescription(
        patientId: widget.patientId,
        diagnosis: _diagnosisController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        isPublic: _isPublic,
        items: _medications.map((med) => med.toJson()).toList(),
        metadata: metadata,
      );

      await AuditService.instance.logAction(
        action: AuditAction.createPrescription,
        resourceType: 'prescription',
        metadata: {
          'patient_id': widget.patientId,
          'doctor_name': doctorProfile?.fullName,
          'biometric_verified': true,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription Signed & Issued Successfully'),
            backgroundColor: AppColors.doctor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch current user profile to get Doctor data for background submission
    final currentUserAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (doctorProfile) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.doctor,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  // FIX: Increased left padding from 16 to 60 to avoid overlap with back arrow
                  titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
                  title: const Text(
                    'New Prescription',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          AppColors.doctor,
                          AppColors.doctor.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            Icons.medication_rounded,
                            size: 150,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Patient Card
                    _buildPatientCard(),
                    const SizedBox(height: 24),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Diagnosis
                          _buildSectionTitle('Clinical Diagnosis', Icons.healing_rounded),
                          const SizedBox(height: 8),
                          _buildDiagnosisField(),
                          const SizedBox(height: 24),

                          // 2. Medications
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('Rx Medications', Icons.local_pharmacy_rounded),
                              FilledButton.icon(
                                onPressed: _addMedication,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Drug'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.doctor,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_medications.isEmpty)
                            _buildEmptyState()
                          else
                            ...List.generate(_medications.length, (index) => _buildMedicationCard(index)),

                          const SizedBox(height: 24),

                          // 3. Details
                          _buildExpansionSection(
                            title: 'Prescription Details & Validity',
                            icon: Icons.calendar_today_rounded,
                            children: [_buildMetadataSection()],
                          ),
                          const SizedBox(height: 16),

                          // 4. Safety
                          _buildExpansionSection(
                            title: 'Safety Checks & Alerts',
                            icon: Icons.verified_user_rounded,
                            children: [_buildSafetyFlags()],
                          ),
                          const SizedBox(height: 16),

                          // 5. Notes
                          _buildExpansionSection(
                            title: 'Notes & Instructions',
                            icon: Icons.note_alt_rounded,
                            children: [
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  hintText: 'Add clinical notes, patient instructions...',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 6. Privacy
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: SwitchListTile.adaptive(
                              title: const Text('Emergency Access', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Allow first responders to view via QR'),
                              value: _isPublic,
                              onChanged: (v) => setState(() => _isPublic = v),
                              secondary: Icon(
                                _isPublic ? Icons.lock_open_rounded : Icons.lock_rounded,
                                color: _isPublic ? AppColors.warning : Colors.grey,
                              ),
                              activeColor: AppColors.doctor,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading
            ? null
            : () {
          // Read the profile data again for submission
          ref.read(currentProfileProvider).whenData((profile) {
            _submit(profile);
          });
        },
        backgroundColor: AppColors.doctor,
        icon: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.fingerprint_rounded),
        label: Text(_isLoading ? 'Signing...' : 'Sign & Issue'),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.doctor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.doctor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.doctor.withOpacity(0.1),
            child: Text(
              widget.patientName.isNotEmpty ? widget.patientName[0].toUpperCase() : 'P',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.doctor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRESCRIBING FOR',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.patientName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'ID: ${widget.patientId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisField() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') return const Iterable<String>.empty();
        return _commonDiagnoses.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        _diagnosisController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        controller.addListener(() {
          _diagnosisController.text = controller.text;
        });
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: InputDecoration(
            hintText: 'e.g. Viral Fever',
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          validator: (value) => value == null || value.isEmpty ? 'Diagnosis required' : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No medications added yet',
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
          TextButton(
            onPressed: _addMedication,
            child: const Text('Add First Medication'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: AppColors.doctor),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Column(
      children: [
        const Divider(),
        Row(
          children: [
            Expanded(
              child: _buildDateTile('Prescribed', _prescriptionDate, () => _selectDate(context, false)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateTile('Valid Until', _validUntil, () => _selectDate(context, true)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<PrescriptionType>(
          value: _prescriptionType,
          decoration: const InputDecoration(
            labelText: 'Prescription Type',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: PrescriptionType.values.map((t) => DropdownMenuItem(
            value: t,
            child: Text(t.displayName),
          )).toList(),
          onChanged: (v) => setState(() => _prescriptionType = v!),
        ),
      ],
    );
  }

  Widget _buildDateTile(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.edit_calendar, size: 16, color: AppColors.doctor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyFlags() {
    return Column(
      children: [
        _buildSafetyCheckTile('Checked for Allergies?', _allergiesMentioned, (v) => setState(() => _allergiesMentioned = v)),
        const Divider(height: 1),
        _buildSafetyCheckTile('Pregnancy / Lactation?', _pregnancyBreastfeeding, (v) => setState(() => _pregnancyBreastfeeding = v)),
        const Divider(height: 1),
        _buildSafetyCheckTile('Chronic Condition Check?', _chronicConditionLinked, (v) => setState(() => _chronicConditionLinked = v)),
      ],
    );
  }

  Widget _buildSafetyCheckTile(String title, bool? value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          ToggleButtons(
            constraints: const BoxConstraints(minWidth: 45, minHeight: 32),
            isSelected: [value == true, value == false, value == null],
            onPressed: (index) {
              if (index == 0) onChanged(true);
              if (index == 1) onChanged(false);
              if (index == 2) onChanged(null);
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: AppColors.doctor,
            children: const [
              Text('Yes', style: TextStyle(fontSize: 12)),
              Text('No', style: TextStyle(fontSize: 12)),
              Text('N/A', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(int index) {
    final med = _medications[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.doctor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.doctor),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Drug #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeMedication(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') return const Iterable<String>.empty();
                    return _commonMedicines.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (String selection) {
                    med.nameController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onComplete) {
                    controller.addListener(() => med.nameController.text = controller.text);
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Name',
                        hintText: 'Search generic or brand name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildChip(med, '1-0-0', 'frequency'),
                      const SizedBox(width: 8),
                      _buildChip(med, '1-0-1', 'frequency'),
                      const SizedBox(width: 8),
                      _buildChip(med, '1-1-1', 'frequency'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.frequencyController,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          hintText: 'e.g. BD',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: med.dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Dosage',
                          hintText: 'e.g. 500mg',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: med.durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                          hintText: 'e.g. 5 days',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: med.quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: med.instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Special Instructions',
                    hintText: 'e.g. After food',
                    border: UnderlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(_MedicationEntry med, String label, String field) {
    return ActionChip(
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () {
        if (field == 'frequency') {
          med.frequencyController.text = label;
        }
      },
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