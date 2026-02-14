import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/audit_service.dart';
import '../../../../services/pdf_service.dart';
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
  final _testController = TextEditingController();

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
  final List<String> _selectedTests = [];

  // DYNAMIC DATA
  List<String> _availableTests = [];
  List<String> _availableDiagnoses = [];
  List<Map<String, dynamic>> _availableMedicines = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _testController.dispose();
    for (final med in _medications) {
      med.dispose();
    }
    super.dispose();
  }

  /// Fetch all master data
  Future<void> _loadMasterData() async {
    await Future.wait([
      _fetchTableData('medical_tests', (data) => _availableTests = data),
      _fetchTableData('medical_diagnoses', (data) => _availableDiagnoses = data),
      _fetchMedicines(),
    ]);
  }

  Future<void> _fetchTableData(String tableName, Function(List<String>) onSuccess) async {
    try {
      final response = await SupabaseService.instance.client
          .from(tableName)
          .select('name')
          .order('name')
          .limit(1000);

      if (mounted) {
        setState(() {
          onSuccess(List<String>.from(response.map((e) => e['name'] as String)));
        });
      }
    } catch (e) {
      debugPrint('Error fetching $tableName: $e');
    }
  }

  Future<void> _fetchMedicines() async {
    try {
      final response = await SupabaseService.instance.client
          .from('medicines')
          .select('name, dosage, type')
          .limit(1000);

      if (mounted) {
        setState(() {
          _availableMedicines = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
    }
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

  void _addTest(String testName) {
    if (testName.trim().isEmpty) return;
    if (!_selectedTests.contains(testName)) {
      setState(() {
        _selectedTests.add(testName);
      });
    }
  }

  void _removeTest(String testName) {
    setState(() {
      _selectedTests.remove(testName);
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
              primary: AppColors.doctor,
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
      final medicationList = _medications.map((med) => med.toJson()).toList();

      String? pdfUrl;
      try {
        if (doctorProfile != null) {
          final pdfBytes = await PdfService.generatePrescription(
            doctor: doctorProfile,
            patientName: widget.patientName,
            patientId: widget.patientId,
            date: _prescriptionDate,
            diagnosis: _diagnosisController.text.trim(),
            notes: _notesController.text.trim(),
            medications: medicationList,
            tests: _selectedTests,
          );

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${widget.patientId}_$timestamp.pdf';

          pdfUrl = await SupabaseService.instance.uploadFile(
            bucket: 'prescriptions',
            path: fileName,
            fileBytes: pdfBytes,
            contentType: 'application/pdf',
          );
        }
      } catch (e) {
        debugPrint('PDF Generation Failed: $e');
      }

      final doctorDetails = {
        'doctor_name': doctorProfile?.fullName ?? 'Dr. Unknown',
        'hospital_clinic_name': doctorProfile?.hospitalName ?? 'Private Practice',
        'specialization': doctorProfile?.specialization ?? '',
        'medical_registration_number': doctorProfile?.medicalRegNumber ?? '',
        'signature_uploaded': true,
      };

      final metadata = {
        'biometric_verified': true,
        'signed_at': DateTime.now().toIso8601String(),
        'prescription_date': _prescriptionDate.toIso8601String(),
        'valid_until': _validUntil.toIso8601String(),
        'type': _prescriptionType.name,
        'recommended_tests': _selectedTests,
        'doctor_details': doctorDetails,
        'safety_flags': {
          'allergies_mentioned': _allergiesMentioned,
          'pregnancy_breastfeeding': _pregnancyBreastfeeding,
          'chronic_condition_linked': _chronicConditionLinked,
        },
        'pdf_url': pdfUrl,
      };

      await SupabaseService.instance.createPrescription(
        patientId: widget.patientId,
        diagnosis: _diagnosisController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        isPublic: _isPublic,
        items: medicationList,
        metadata: metadata,
      );

      await AuditService.instance.logAction(
        action: AuditAction.createPrescription,
        resourceType: 'prescription',
        metadata: {
          'patient_id': widget.patientId,
          'doctor_name': doctorProfile?.fullName,
          'biometric_verified': true,
          'pdf_generated': pdfUrl != null,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription Signed, PDF Generated & Issued'),
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

  // --- REUSABLE DROPDOWN BUILDER ---
  // Updated <T> to <T extends Object> to fix compilation error
  Widget _customOptionsViewBuilder<T extends Object>(
      BuildContext context,
      AutocompleteOnSelected<T> onSelected,
      Iterable<T> options,
      double width,
      Widget Function(T option) itemBuilder,
      ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: SizedBox(
            width: width, // FORCE width to match input field
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (BuildContext context, int index) {
                final T option = options.elementAt(index);
                return InkWell(
                  onTap: () => onSelected(option),
                  child: itemBuilder(option),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Helper for standard list item padding
  Widget _buildStandardDropdownItem(String text) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Write Prescription', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (doctorProfile) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientInfoBar(),
                    const SizedBox(height: 24),

                    Text('Clinical Diagnosis'.toUpperCase(), style: _headerStyle),
                    const SizedBox(height: 8),
                    _buildDiagnosisField(), // Uses reusable builder
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rx Medications'.toUpperCase(), style: _headerStyle),
                        TextButton.icon(
                          onPressed: _addMedication,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Drug'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.doctor,
                            backgroundColor: AppColors.doctor.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_medications.isEmpty)
                      _buildEmptyState()
                    else
                      ...List.generate(_medications.length, (index) => _buildMedicationCard(index)),

                    const SizedBox(height: 32),

                    _buildSectionHeader('Recommended Tests (Optional)'),
                    const SizedBox(height: 12),
                    _buildTestsSection(), // Uses reusable builder

                    const SizedBox(height: 32),

                    _buildSectionHeader('Prescription Details'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: _cardDecoration,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildMetadataSection(),
                          const Divider(height: 32),
                          _buildSafetyFlags(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('Clinical Notes'.toUpperCase(), style: _headerStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: _inputDecoration(hint: 'Add instructions, observations or warnings...'),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),

                    Container(
                      decoration: _cardDecoration,
                      child: SwitchListTile.adaptive(
                        title: const Text('Emergency Access', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        subtitle: const Text('Allow first responders to view via QR', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        activeColor: AppColors.doctor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              )
            ]
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: _isLoading
                ? null
                : () {
              ref.read(currentProfileProvider).whenData((profile) {
                _submit(profile);
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.doctor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Sign & Issue Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  // --- STYLES & DECORATIONS ---

  TextStyle get _headerStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade200),
  );

  InputDecoration _inputDecoration({required String hint, String? label, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.doctor, width: 1.5),
      ),
      suffixIcon: suffix,
      isDense: true,
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: _headerStyle);
  }

  Widget _buildTestsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LayoutBuilder to capture exact width
          LayoutBuilder(
              builder: (context, constraints) {
                return Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') return const Iterable<String>.empty();
                    return _availableTests.where((String option) {
                      final matchesQuery = option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      final isNotAlreadySelected = !_selectedTests.contains(option);
                      return matchesQuery && isNotAlreadySelected;
                    });
                  },
                  displayStringForOption: (option) => '', // Keep field clear after select
                  onSelected: (String selection) {
                    _addTest(selection);
                  },
                  // Reusable Custom Builder
                  optionsViewBuilder: (context, onSelected, options) {
                    return _customOptionsViewBuilder(
                      context,
                      onSelected,
                      options,
                      constraints.maxWidth,
                          (option) => _buildStandardDropdownItem(option), // Standard look
                    );
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: (value) {
                        _addTest(value);
                        controller.clear();
                        onEditingComplete();
                      },
                      decoration: _inputDecoration(
                        hint: 'Search or type test name...',
                        suffix: IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.doctor),
                          onPressed: () {
                            _addTest(controller.text);
                            controller.clear();
                          },
                        ),
                      ),
                    );
                  },
                );
              }
          ),
          if (_selectedTests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTests.map((test) {
                return Chip(
                  label: Text(test, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  backgroundColor: AppColors.doctor.withOpacity(0.05),
                  side: BorderSide(color: AppColors.doctor.withOpacity(0.2)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: AppColors.doctor),
                  onDeleted: () => _removeTest(test),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientInfoBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.doctor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                widget.patientName.isNotEmpty ? widget.patientName[0].toUpperCase() : 'P',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.doctor),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${widget.patientId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisField() {
    return LayoutBuilder(
        builder: (context, constraints) {
          return Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') return const Iterable<String>.empty();
              return _availableDiagnoses.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              _diagnosisController.text = selection;
            },
            // Reusable Custom Builder
            optionsViewBuilder: (context, onSelected, options) {
              return _customOptionsViewBuilder(
                context,
                onSelected,
                options,
                constraints.maxWidth,
                    (option) => _buildStandardDropdownItem(option), // Standard look
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              controller.addListener(() {
                _diagnosisController.text = controller.text;
              });
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: onEditingComplete,
                decoration: _inputDecoration(
                  hint: 'Search ICD-10 or common diagnosis...',
                  suffix: const Icon(Icons.search, color: Colors.grey, size: 20),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Diagnosis required' : null,
              );
            },
          );
        }
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Icon(Icons.medication_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'No medications added yet',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Row(
      children: [
        Expanded(
          child: _buildDateInput(
              'Prescription Date',
              _prescriptionDate,
                  () => _selectDate(context, false)
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDateInput(
            'Valid Until',
            _validUntil,
                () => _selectDate(context, true),
            isAlert: _validUntil.difference(_prescriptionDate).inDays < 7,
          ),
        ),
      ],
    );
  }

  Widget _buildDateInput(String label, DateTime date, VoidCallback onTap, {bool isAlert = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isAlert ? AppColors.warning.withOpacity(0.5) : Colors.grey.shade200
              ),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyFlags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Safety Checks", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _buildSafetyCheckTile('Allergies checked?', _allergiesMentioned, (v) => setState(() => _allergiesMentioned = v)),
        const SizedBox(height: 8),
        _buildSafetyCheckTile('Pregnancy/Lactation check?', _pregnancyBreastfeeding, (v) => setState(() => _pregnancyBreastfeeding = v)),
      ],
    );
  }

  Widget _buildSafetyCheckTile(String title, bool? value, Function(bool?) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 12),
        // Custom segmented control for professional look
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentBtn('Yes', value == true, () => onChanged(true)),
              Container(width: 1, color: Colors.grey.shade300),
              _buildSegmentBtn('No', value == false, () => onChanged(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentBtn(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.doctor : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int index) {
    final med = _medications[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.doctor.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text('Drug ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                const Spacer(),
                InkWell(
                  onTap: () => _removeMedication(index),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFF1F5F9)),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // MEDICINE SEARCH AUTOCOMPLETE (UPDATED)
                LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue val) {
                          if (val.text == '') return const Iterable<Map<String, dynamic>>.empty();
                          return _availableMedicines.where((med) {
                            final name = med['name'].toString().toLowerCase();
                            final search = val.text.toLowerCase();
                            return name.contains(search);
                          });
                        },
                        displayStringForOption: (med) => med['name'],
                        onSelected: (selection) {
                          med.nameController.text = selection['name'] ?? '';
                          med.dosageController.text = selection['dosage'] ?? '';
                          med.typeController.text = selection['type'] ?? '';
                        },
                        // Reusable Custom Builder with Custom Item
                        optionsViewBuilder: (context, onSelected, options) {
                          return _customOptionsViewBuilder(
                            context,
                            onSelected,
                            options,
                            constraints.maxWidth,
                                (option) {
                              // Custom item for medicine (with subtitle)
                              final name = option['name'];
                              final dosage = option['dosage'] ?? '';
                              final type = option['type'] ?? '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                    if(dosage.isNotEmpty || type.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text('$dosage • $type', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        fieldViewBuilder: (ctx, ctrl, focus, onComp) {
                          ctrl.addListener(() {
                            if (ctrl.text != med.nameController.text) {
                              med.nameController.text = ctrl.text;
                            }
                          });
                          return TextFormField(
                            controller: ctrl,
                            focusNode: focus,
                            decoration: _inputDecoration(
                                hint: 'Search Medicine (e.g. Paracetamol)',
                                label: 'Medicine Name'
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          );
                        },
                      );
                    }
                ),
                const SizedBox(height: 12),

                // Grid for Type, Dose, Freq
                Row(
                  children: [
                    // New Type Field
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.typeController,
                        decoration: _inputDecoration(hint: 'Tab/Inj', label: 'Type'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.dosageController,
                        decoration: _inputDecoration(hint: '500mg', label: 'Dose'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.frequencyController,
                        decoration: _inputDecoration(hint: 'BD', label: 'Freq'),
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
                        decoration: _inputDecoration(hint: '5 days', label: 'Duration'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: med.quantityController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: '10', label: 'Qty'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Quick chips for frequency
                SizedBox(
                  height: 28,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildMiniChip(med, '1-0-1'),
                      const SizedBox(width: 6),
                      _buildMiniChip(med, '1-1-1'),
                      const SizedBox(width: 6),
                      _buildMiniChip(med, 'Before Food'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(_MedicationEntry med, String label) {
    return InkWell(
      onTap: () {
        if (label.contains('-')) {
          med.frequencyController.text = label;
        } else {
          med.instructionsController.text = label;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ),
    );
  }
}

class _MedicationEntry {
  final nameController = TextEditingController();
  final typeController = TextEditingController(); // ADDED
  final dosageController = TextEditingController();
  final frequencyController = TextEditingController();
  final durationController = TextEditingController();
  final quantityController = TextEditingController();
  final instructionsController = TextEditingController();

  void dispose() {
    nameController.dispose();
    typeController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    quantityController.dispose();
    instructionsController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': nameController.text.trim(),
      'medicine_type': typeController.text.trim(), // Added to JSON
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