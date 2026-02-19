import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../features/shared/services/ocr_service.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../family/providers/family_provider.dart';
import '../../models/prescription_input_models.dart';
import '../../providers/patient_provider.dart';
import '../widgets/doctor_info_card_widget.dart';
import '../widgets/medication_card_widget.dart';
import '../widgets/prescription_upload_widget.dart';
import '../../../../services/supabase_service.dart';

/// Comprehensive Add Prescription screen for patient input
class AddPrescriptionScreen extends ConsumerStatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  ConsumerState<AddPrescriptionScreen> createState() =>
      _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends ConsumerState<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Prescription Metadata
  DateTime _prescriptionDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  PrescriptionType _prescriptionType = PrescriptionType.newPrescription;

  // Doctor Details
  DoctorDetails _doctorDetails = const DoctorDetails(
    doctorName: '',
    hospitalClinicName: '',
    medicalRegistrationNumber: '',
  );

  // Prescription Upload
  PrescriptionUpload _prescriptionUpload = const PrescriptionUpload();

  // Diagnosis & Notes
  final _diagnosisController = TextEditingController();
  final _doctorNotesController = TextEditingController();
  final _patientNotesController = TextEditingController();

  // Dynamic Data for Autocomplete
  List<String> _availableDiagnoses = [];

  // Medications
  final List<MedicationDetails> _medications = [];

  // Safety Flags
  bool? _allergiesMentioned;
  bool? _pregnancyBreastfeeding;
  bool? _chronicConditionLinked;

  // Declaration
  bool _declarationAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnoses();
  }

  Future<void> _loadDiagnoses() async {
    try {
      final response = await SupabaseService.instance.client
          .from('medical_diagnoses')
          .select('name')
          .order('name')
          .limit(1000);
      if (mounted) {
        setState(() {
          _availableDiagnoses = List<String>.from(response.map((e) => e['name'] as String));
        });
      }
    } catch (e) {
      debugPrint('Error loading diagnoses: $e');
    }
  }

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
    setState(() {
      _medications.removeAt(index);
    });
  }

  void _updateMedication(int index, MedicationDetails details) {
    setState(() {
      _medications[index] = details;
    });
  }

  Future<void> _showSourceSelectionSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: AppColors.primary),
                title: const Text('Upload PDF / File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image == null) return;
      
      _processFile(File(image.path));
    } catch (e) {
      debugPrint('Image Picker Error: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        _processFile(File(result.files.single.path!));
      }
    } catch (e) {
      debugPrint('File Picker Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Error picking file'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _processFile(File file) async {
      setState(() => _isLoading = true);

      try {
        // Process File (Image or PDF)
        final prescriptionData = await OcrService().processPrescriptionFile(file);
        
        setState(() {
          // 1. Doctor & Hospital Name
          if (prescriptionData.doctorName != null || prescriptionData.hospitalName != null) {
            _doctorDetails = _doctorDetails.copyWith(
                doctorName: prescriptionData.doctorName ?? _doctorDetails.doctorName,
                hospitalClinicName: prescriptionData.hospitalName ?? _doctorDetails.hospitalClinicName,
            );
          }
          
          // 2. Date
          if (prescriptionData.date != null) {
            _prescriptionDate = prescriptionData.date!;
             // Auto-adjust valid until if needed
            if (_validUntil.isBefore(_prescriptionDate)) {
               _validUntil = _prescriptionDate.add(const Duration(days: 30));
            }
          }

          // 3. Diagnosis
          if (prescriptionData.diagnosis != null) {
             _diagnosisController.text = prescriptionData.diagnosis!;
          }

          // 4. Medications
          if (prescriptionData.medications.isNotEmpty) {
            // Clear existing empty meds if any
            if (_medications.length == 1 && _medications.first.medicineName.isEmpty) {
                _medications.clear();
            }
            
            for (var med in prescriptionData.medications) {
              _medications.add(MedicationDetails(
                medicineName: med.name,
                dosage: med.dosage,
                frequency: med.frequency,
                duration: med.duration,
                quantity: med.quantity,
                instructions: med.instructions,
                // Attempt to infer type/timing from instructions if possible, else null
              ));
            }
          }
          
          // 5. Set the upload file
          _prescriptionUpload = PrescriptionUpload(
            filePath: file.path,
            fileName: file.path.split('/').last,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned: ${prescriptionData.medications.length} meds found.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }

      } catch (e) {
        debugPrint('OCR Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to scan prescription'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textMain,
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
          // Auto-adjust valid until if needed
          if (_validUntil.isBefore(_prescriptionDate)) {
            _validUntil = _prescriptionDate.add(const Duration(days: 30));
          }
        }
      });
    }
  }

  bool _validateForm() {
    // Form validation (Text fields)
    if (!_formKey.currentState!.validate()) {
      _showError('Please check the red fields in the form.');
      return false;
    }

    // Date validation
    if (_validUntil.isBefore(_prescriptionDate)) {
      _showError('Valid Until date must be after Prescription Date');
      return false;
    }

    // Doctor details validation
    if (!_doctorDetails.isValid) {
      _showError('Please complete all doctor information fields');
      return false;
    }

    // Medications validation
    if (_medications.isEmpty) {
      _showError('Please add at least one medication');
      return false;
    }

    if (!_medications.every((med) => med.isValid)) {
      _showError('Please complete all fields for every medication');
      return false;
    }

    // Upload validation
    // if (!_prescriptionUpload.hasFile) {
    //   _showError('Please upload a photo of the prescription');
    //   return false;
    // }

    // Declaration validation
    if (!_declarationAccepted) {
      _showError('Please accept the declaration checkbox at the bottom');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
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

      // 2. Prepare complete prescription input
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

      // 3. Store prescription with metadata
      // The patientId here comes from the active family member's patient record
      await SupabaseService.instance.createPrescription(
        patientId: patient.id,
        diagnosis: prescriptionInput.diagnosis,
        notes: prescriptionInput.patientNotes,
        isPublic: false,
        patientEntered: true,
        items: prescriptionInput.medications.map((m) => m.toJson()).toList(),
        metadata: prescriptionInput.toJson(),
      );

      // 4. Refresh cached data
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
        String errorMsg = e.toString().replaceAll("Exception:", "").trim();
        // Friendly error message for RLS issues
        if (errorMsg.contains('policy') || errorMsg.contains('permission')) {
          errorMsg = 'Permission denied. Please ask your administrator to run the Family SQL Policies.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REUSABLE DROPDOWN BUILDER (From Doctor Screen) ---
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
            width: width,
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

  Widget _buildStandardDropdownItem(String text) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }





  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeContextProfileProvider);
    final patient = ref.watch(patientDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Text('Add Prescription'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textMain),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.borderSoft, height: 1.0),
        ),
      ),
      body: patient.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HERO SCAN SECTION ---
                _buildHeroScanSection(),
                const SizedBox(height: 32),
                
                // --- FORM SECTION ---
                Text(
                  'Prescription Details',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Doctor Info
                _buildMedicalSection(
                  title: 'Doctor Information',
                  icon: Icons.medical_services_outlined,
                  child: DoctorInfoCardWidget(
                    onChanged: (details) {
                      setState(() => _doctorDetails = details);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Diagnosis & Date
                _buildMedicalSection(
                  title: 'Diagnosis & Date',
                  icon: Icons.calendar_today_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDiagnosisField(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(
                              context: context,
                              label: 'Prescribed On',
                              value: _prescriptionDate,
                              onTap: () => _selectDate(context, false),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDatePicker(
                              context: context,
                              label: 'Valid Until',
                              value: _validUntil,
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Medications
                _buildMedicalSection(
                  title: 'Medications',
                  icon: Icons.medication_outlined,
                  action: TextButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Drug'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_medications.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.medication_liquid_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              Text(
                                'No medications added yet',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(_medications.length, (index) => 
                           Padding(
                             padding: const EdgeInsets.only(bottom: 12.0),
                             child: MedicationCardWidget( // Assuming this widget is simplified as well or looks good enough
                                key: ValueKey(_medications[index].id),
                                index: index,
                                initialData: _medications[index],
                                onChanged: (details) => _updateMedication(index, details),
                                onRemove: () => _removeMedication(index),
                               ),
                           )
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Notes (Collapsible/Simple)
                 _buildMedicalSection(
                    title: 'Additional Notes',
                    icon: Icons.note_alt_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                           controller: _doctorNotesController,
                           decoration: _inputDecoration(
                             hint: "Doctor's instructions...",
                             label: 'Doctor Notes',
                           ),
                           maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                           controller: _patientNotesController,
                           decoration: _inputDecoration(
                             hint: "Personal notes...",
                             label: 'My Notes',
                           ),
                           maxLines: 2,
                        ),
                      ],
                    ),
                 ),
                 const SizedBox(height: 20),

                 // 5. Patient Context & Declaration
                 _buildMedicalSection(
                    title: 'Verification',
                    icon: Icons.verified_user_outlined,
                    child: Column(
                      children: [
                        _buildPatientProfileRow(profile),
                        const Divider(height: 24),
                        _buildDeclaration(),
                        const Divider(height: 24),
                        _buildSafetyFlags(),
                      ],
                    ),
                 ),

                 const SizedBox(height: 40),
                 
                 // Submit Button
                 SizedBox(
                   width: double.infinity,
                   height: 56,
                   child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Prescription', 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                            ),
                   ),
                 ),
                 const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MEDICAL PROFESSIONAL UI COMPONENTS ---

  Widget _buildMedicalSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Sharper corners
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Technical Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate 100
              border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSub),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.textSub,
                  ),
                ),
                const Spacer(),
                if (action != null) action,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  // --- PATIENT PROFILE ROW ---
  Widget _buildPatientProfileRow(AsyncValue<dynamic> profile) {
    return profile.when(
      data: (p) => p != null
          ? Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                    Text(
                      p.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain),
                    ),
                  ],
                ),
              ],
            )
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // --- UPDATE: Diagnosis with new style ---
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
            optionsViewBuilder: (context, onSelected, options) {
              return _customOptionsViewBuilder(
                context,
                onSelected,
                options,
                constraints.maxWidth,
                    (option) => _buildStandardDropdownItem(option),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              // Ensure our controller stays in sync if user types directly
              controller.addListener(() {
                 if (_diagnosisController.text != controller.text) {
                   _diagnosisController.text = controller.text;
                 }
              });
              // Initial value sync if coming from OCR
              if (_diagnosisController.text.isNotEmpty && controller.text.isEmpty) {
                controller.text = _diagnosisController.text;
              }
              
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: onEditingComplete,
                decoration: _inputDecoration(
                  hint: 'e.g. Viral Fever',
                  label: 'Diagnosis / Condition',
                ),
                validator: (value) => value == null || value.isEmpty ? 'Diagnosis required' : null,
              );
            },
          );
        }
    );
  }

  Widget _buildHeroScanSection() {
    final bool hasFile = _prescriptionUpload.hasFile;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: hasFile ? AppColors.success.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? AppColors.success.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.2),
          style: hasFile ? BorderStyle.solid : BorderStyle.solid, 
          width: 1.5, // Slightly thicker for technical feel
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showSourceSelectionSheet,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasFile ? AppColors.success.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasFile ? Icons.check_circle_outline : Icons.document_scanner_rounded,
                    size: 28,
                    color: hasFile ? AppColors.success : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasFile ? 'DIGITAL SCAN CAPTURED' : 'SCAN PRESCRIPTION',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: hasFile ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasFile ? (_prescriptionUpload.fileName ?? 'File attached') : 'Tap to initialize smart capture',
                         style: const TextStyle(
                           fontSize: 14,
                           fontWeight: FontWeight.w500,
                           color: AppColors.textMain,
                         ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UPDATED INPUT DECORATION ---
  InputDecoration _inputDecoration({required String hint, String? label, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSub),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Colors.white, // White background for crisp look
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6), // Sharper 6px radius
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5), // Precision focus
      ),
      suffixIcon: suffix,
      isDense: true,
    );
  }

  // --- DATE PICKER UPDATE ---
  Widget _buildDatePicker({
    required BuildContext context,
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), // Match input height
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderSoft),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textSub, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Row(
              children: [
                 const Icon(Icons.calendar_month, size: 14, color: AppColors.textMain),
                 const SizedBox(width: 8),
                 Text(
                   DateFormat('dd MMM yyyy').format(value),
                   style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textMain),
                 ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- SAFETY FLAGS UPDATE ---
  Widget _buildSafetyFlags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSafetyCheckTile('ALLERGIES DETECTED?', _allergiesMentioned, (v) => setState(() => _allergiesMentioned = v)),
        const Divider(height: 24, color: AppColors.borderSoft),
        _buildSafetyCheckTile('PREGNANCY / BREASTFEEDING?', _pregnancyBreastfeeding, (v) => setState(() => _pregnancyBreastfeeding = v)),
        const Divider(height: 24, color: AppColors.borderSoft),
        _buildSafetyCheckTile('CHRONIC CONDITION LINK?', _chronicConditionLinked, (v) => setState(() => _chronicConditionLinked = v)),
      ],
    );
  }

  Widget _buildSafetyCheckTile(String title, bool? value, Function(bool?) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain, letterSpacing: 0.5))),
        Row(
          mainAxisSize: MainAxisSize.min, // Fix row expansion
          children: [
             _buildRadioBtn(true, value, onChanged, 'YES'),
             const SizedBox(width: 8),
             _buildRadioBtn(false, value, onChanged, 'NO'),
          ],
        )
      ],
    );
  }

  Widget _buildRadioBtn(bool optionVal, bool? currentVal, Function(bool?) onChanged, String label) {
     final isSelected = currentVal == optionVal;
     return InkWell(
        onTap: () => onChanged(optionVal),
        borderRadius: BorderRadius.circular(4),
        child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
           decoration: BoxDecoration(
             color: isSelected 
                 ? (optionVal ? AppColors.error : AppColors.success)
                 : Colors.transparent,
             borderRadius: BorderRadius.circular(4),
             border: Border.all(
               color: isSelected 
                  ? (optionVal ? AppColors.error : AppColors.success)
                  : AppColors.borderSoft,
             ),
           ),
           child: Text(
             label,
             style: TextStyle(
               fontSize: 10,
               fontWeight: FontWeight.w700,
               color: isSelected ? Colors.white : AppColors.textSub,
             ),
           ),
        ),
     );
  }

  Widget _buildDeclaration() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _declarationAccepted,
              onChanged: (value) {
                setState(() => _declarationAccepted = value ?? false);
              },
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Sharp checkbox
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _declarationAccepted = !_declarationAccepted);
              },
              child: const Text(
                'I declare that this is a valid medical prescription.',
                style: TextStyle(fontSize: 12, color: AppColors.textMain, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}