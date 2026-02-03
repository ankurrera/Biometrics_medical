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
    final showRegistrationWarning = _regNumberController.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: showRegistrationWarning 
              ? AppColors.warning.withOpacity(0.5)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.doctor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.medical_information_outlined,
                  color: AppColors.doctor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doctor / Issuer Information',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'All fields required',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Registration warning
          if (showRegistrationWarning)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Medical registration number is required for valid prescriptions',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Doctor Name *
          TextFormField(
            controller: _doctorNameController,
            decoration: const InputDecoration(
              labelText: 'Doctor Name *',
              hintText: 'Dr. Full Name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Doctor name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Specialization
          TextFormField(
            controller: _specializationController,
            decoration: const InputDecoration(
              labelText: 'Specialization',
              hintText: 'e.g., Cardiologist, General Physician',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Hospital/Clinic Name *
          TextFormField(
            controller: _hospitalController,
            decoration: const InputDecoration(
              labelText: 'Hospital / Clinic Name *',
              hintText: 'Name of medical facility',
              prefixIcon: Icon(Icons.local_hospital_outlined, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Hospital/Clinic name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Medical Registration Number *
          TextFormField(
            controller: _regNumberController,
            decoration: const InputDecoration(
              labelText: 'Medical Registration Number *',
              hintText: 'e.g., MCI Registration Number',
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Medical registration number is required';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Doctor Signature Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _signatureUploaded 
                  ? AppColors.success.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  _signatureUploaded 
                      ? Icons.check_circle_outline 
                      : Icons.draw_outlined,
                  color: _signatureUploaded 
                      ? AppColors.success 
                      : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _signatureUploaded 
                        ? 'Doctor signature uploaded'
                        : 'Doctor signature not uploaded',
                    style: TextStyle(
                      fontSize: 13,
                      color: _signatureUploaded 
                          ? AppColors.success 
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (!_signatureUploaded)
                  TextButton(
                    onPressed: () {
                      // Future: Implement signature upload
                      setState(() {
                        _signatureUploaded = true;
                        _notifyChange();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Signature upload - Feature coming soon'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Upload'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
