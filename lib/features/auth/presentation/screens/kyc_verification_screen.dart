import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';

class KYCVerificationScreen extends ConsumerStatefulWidget {
  const KYCVerificationScreen({super.key});

  @override
  ConsumerState<KYCVerificationScreen> createState() =>
      _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends ConsumerState<KYCVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  DateTime? _dateOfBirth;
  File? _idDocument;
  File? _selfie;
  bool _isLoading = false;
  String? _idDocumentUrl;
  String? _selfieUrl;

  final _kycService = KYCService.instance;

  @override
  void initState() {
    super.initState();
    _checkExistingKYC();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingKYC() async {
    try {
      final kyc = await _kycService.getKYCStatus();
      if (kyc != null && mounted) {
        setState(() {
          _fullNameController.text = kyc.fullName;
          _dateOfBirth = kyc.dateOfBirth;
          _idDocumentUrl = kyc.idDocumentUrl;
          _selfieUrl = kyc.selfieUrl;
        });

        if (kyc.status == KYCStatus.verified) {
          _showKYCVerifiedDialog();
        } else if (kyc.status == KYCStatus.pending) {
          _showKYCPendingDialog();
        }
      }
    } catch (e) {
      // Ignore errors on init
    }
  }

  void _showKYCVerifiedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.success),
            SizedBox(width: 8),
            Text('KYC Verified'),
          ],
        ),
        content: const Text(
          'Your identity has been verified. You can now access all features.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.go(RouteNames.roleSelection);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showKYCPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pending, color: AppColors.warning),
            SizedBox(width: 8),
            Text('KYC Pending'),
          ],
        ),
        content: const Text(
          'Your KYC documents are under review. This usually takes 24-48 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.go(RouteNames.roleSelection);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickIdDocument() async {
    try {
      final image = await _kycService.pickImage();
      if (image != null && mounted) {
        setState(() {
          _idDocument = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _takeSelfie() async {
    try {
      final photo = await _kycService.takePhoto();
      if (photo != null && mounted) {
        setState(() {
          _selfie = File(photo.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(1900),
      lastDate: eighteenYearsAgo,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      setState(() {
        _dateOfBirth = date;
      });
    }
  }

  Future<void> _submitKYC() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_idDocument == null && _idDocumentUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your ID document'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selfie == null && _selfieUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a selfie'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload documents if new files were selected
      String idDocUrl = _idDocumentUrl ?? '';
      String selfieUrl = _selfieUrl ?? '';

      if (_idDocument != null) {
        idDocUrl = await _kycService.uploadDocument(
          file: _idDocument!,
          documentType: 'id_document',
        );
      }

      if (_selfie != null) {
        selfieUrl = await _kycService.uploadDocument(
          file: _selfie!,
          documentType: 'selfie',
        );
      }

      // Submit KYC
      await _kycService.submitKYC(
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        idDocumentUrl: idDocUrl,
        selfieUrl: selfieUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC documents submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // Show pending dialog
        _showKYCPendingDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit KYC: $e'),
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
        title: const Text('KYC Verification'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Why KYC?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'KYC (Know Your Customer) helps us verify your identity and keep your medical records secure. Your documents are encrypted and never shared.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Full Name
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'As shown on your ID',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Date of Birth
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dateOfBirth != null
                        ? DateFormat('MMM dd, yyyy').format(_dateOfBirth!)
                        : 'Select your date of birth',
                    style: TextStyle(
                      color: _dateOfBirth != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ID Document
              _buildDocumentSection(
                title: 'ID Document',
                subtitle: 'Upload a clear photo of your government-issued ID',
                icon: Icons.badge,
                file: _idDocument,
                existingUrl: _idDocumentUrl,
                onTap: _pickIdDocument,
              ),
              const SizedBox(height: AppSpacing.md),

              // Selfie
              _buildDocumentSection(
                title: 'Selfie',
                subtitle: 'Take a clear selfie holding your ID',
                icon: Icons.face,
                file: _selfie,
                existingUrl: _selfieUrl,
                onTap: _takeSelfie,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitKYC,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit for Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Skip Button
              TextButton(
                onPressed: () {
                  context.go(RouteNames.roleSelection);
                },
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required String subtitle,
    required IconData icon,
    File? file,
    String? existingUrl,
    required VoidCallback onTap,
  }) {
    final hasDocument = file != null || existingUrl != null;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: hasDocument ? AppColors.success : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: hasDocument
                        ? AppColors.success.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasDocument ? Icons.check_circle : icon,
                    color: hasDocument ? AppColors.success : Colors.grey,
                    size: 30,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasDocument ? 'Document uploaded ✓' : subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasDocument
                              ? AppColors.success
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasDocument ? Icons.edit : Icons.camera_alt,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
