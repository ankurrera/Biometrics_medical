import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../models/prescription_input_models.dart';

/// Widget for entering doctor/issuer details
class DoctorInfoCardWidget extends StatefulWidget {
  final Function(DoctorDetails) onChanged;
  final DoctorDetails? initialData;

  const DoctorInfoCardWidget({
    super.key,
    required this.onChanged,
    this.initialData,
  });

  @override
  State<DoctorInfoCardWidget> createState() => _DoctorInfoCardWidgetState();
}

class _DoctorInfoCardWidgetState extends State<DoctorInfoCardWidget> {
  late final TextEditingController _doctorNameController;
  late final TextEditingController _specializationController;
  late final TextEditingController _hospitalController;
  late final TextEditingController _regNumberController;
  bool _signatureUploaded = false;

  @override
  void initState() {
    super.initState();
    _doctorNameController = TextEditingController(
      text: widget.initialData?.doctorName,
    );
    _specializationController = TextEditingController(
      text: widget.initialData?.specialization,
    );
    _hospitalController = TextEditingController(
      text: widget.initialData?.hospitalClinicName,
    );
    _regNumberController = TextEditingController(
      text: widget.initialData?.medicalRegistrationNumber,
    );
    _signatureUploaded = widget.initialData?.signatureUploaded ?? false;

    // Add listeners
    _doctorNameController.addListener(_notifyChange);
    _specializationController.addListener(_notifyChange);
    _hospitalController.addListener(_notifyChange);
    _regNumberController.addListener(_notifyChange);
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final doctorDetails = DoctorDetails(
      doctorName: _doctorNameController.text,
      specialization: _specializationController.text.isNotEmpty 
          ? _specializationController.text 
          : null,
      hospitalClinicName: _hospitalController.text,
      medicalRegistrationNumber: _regNumberController.text,
      signatureUploaded: _signatureUploaded,
    );
    widget.onChanged(doctorDetails);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doctor Name *
        TextFormField(
          controller: _doctorNameController,
          decoration: _inputDecoration(
            'Dr. Full Name',
            'Doctor Name *',
            Icons.person_outline,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Doctor name is required';
            // Simple check for placeholders
            final lower = value.trim().toLowerCase();
            if (['test', 'placeholder', 'na', 'n/a'].contains(lower)) {
              return 'Enter a valid name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Specialization
        TextFormField(
          controller: _specializationController,
           decoration: _inputDecoration(
            'e.g. Cardiologist',
            'Specialization',
            Icons.work_outline,
          ),
        ),
        const SizedBox(height: 16),

        // Hospital/Clinic Name *
        TextFormField(
          controller: _hospitalController,
           decoration: _inputDecoration(
            'Hospital / Clinic Name',
            'Hospital / Clinic Name *',
            Icons.local_hospital_outlined,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Hospital name is required';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Medical Registration Number *
        TextFormField(
          controller: _regNumberController,
           decoration: _inputDecoration(
            'Registration Number',
            'Registration Number *',
            Icons.verified_outlined,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Registration number is required';
            return null;
          },
        ),
        
        // Optional: Signature status removed as it's not core for patient entry currently 
        // or can be kept simple if needed. 
        // For now, removing to clean up UI as requested "worst part".
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textMain.withValues(alpha: 0.5)),
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
        borderSide: BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      isDense: true,
    );
  }
}
