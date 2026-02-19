import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // Ensure intl package is in pubspec.yaml

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  final String role;

  const SignUpScreen({super.key, required this.role});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Patient Specific Controllers & State
  final _weightController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  final _dobController = TextEditingController(); // To show text in field

  // Doctor Specific Controllers
  final _hospitalController = TextEditingController();
  final _specializationController = TextEditingController();
  final _medRegController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _dobController.dispose();
    _hospitalController.dispose();
    _specializationController.dispose();
    _medRegController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Color get _roleColor {
    switch (widget.role) {
      case 'doctor':
        return AppColors.doctor;
      case 'pharmacist':
        return AppColors.pharmacist;
      case 'first_responder':
        return AppColors.firstResponder;
      default:
        return AppColors.patient;
    }
  }

  String get _roleTitle {
    switch (widget.role) {
      case 'doctor':
        return 'Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      case 'first_responder':
        return 'First Responder';
      default:
        return 'Patient';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: widget.role,
        // Pass doctor fields if role is doctor
        hospitalName: widget.role == 'doctor' ? _hospitalController.text.trim() : null,
        specialization: widget.role == 'doctor' ? _specializationController.text.trim() : null,
        medicalRegNumber: widget.role == 'doctor' ? _medRegController.text.trim() : null,
        // Pass patient fields if role is patient
        gender: widget.role == 'patient' ? _selectedGender : null,
        dateOfBirth: widget.role == 'patient' ? _selectedDateOfBirth : null,
        weight: widget.role == 'patient' && _weightController.text.isNotEmpty
            ? double.tryParse(_weightController.text)
            : null,
      );

      if (mounted) {
        if (widget.role == 'patient') {
          context.go(RouteNames.kycVerification);
        } else {
          context.go(RouteNames.biometricEnrollment);
        }
      }
    } catch (e) {
      if (mounted) {
        final originalError = e.toString();
        String errorMessage = originalError;
        bool showSignInAction = false;

        if (originalError.contains('over_email_send_rate_limit')) {
          errorMessage = '⏱️ Too many sign-up attempts. Please wait a minute and try again.';
        } else if (originalError.contains('User already registered') || originalError.contains('already registered')) {
          errorMessage = '📧 This email is already registered. Try signing in instead.';
          showSignInAction = true;
        } else if (originalError.contains('Invalid email') || originalError.contains('invalid email')) {
          errorMessage = '📧 Please enter a valid email address.';
        } else if (originalError.contains('Password') && originalError.contains('weak')) {
          errorMessage = '🔒 Password is too weak. Use at least 8 characters with letters and numbers.';
        } else if (originalError.contains('Email not confirmed')) {
          errorMessage = '📬 Please check your email and verify your account before signing in.';
        } else if (originalError.contains('Network') || originalError.contains('network')) {
          errorMessage = '📡 Network error. Please check your connection and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: showSignInAction
                ? SnackBarAction(
              label: 'Sign In',
              textColor: Colors.white,
              onPressed: () => context.pop(),
            )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.role == 'doctor';
    final isPatient = widget.role == 'patient';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 32),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _roleColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _roleTitle,
                    style: TextStyle(
                      color: _roleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isDoctor
                      ? 'Enter your professional details to register'
                      : 'Fill in your details to get started',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // Common Fields
                AuthTextField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter your phone number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // PATIENT SPECIFIC FIELDS
                if (isPatient) ...[
                  const Divider(height: 32),
                  const Text(
                    'Personal Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.people_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    value: _selectedGender,
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) => setState(() => _selectedGender = val),
                    validator: (val) => val == null ? 'Please select gender' : null,
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth Picker
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: AuthTextField(
                        controller: _dobController,
                        label: 'Date of Birth',
                        hint: 'YYYY-MM-DD',
                        prefixIcon: Icons.calendar_today_outlined,
                        validator: (value) => value!.isEmpty ? 'Please enter date of birth' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Weight Input
                  AuthTextField(
                    controller: _weightController,
                    label: 'Weight (kg)',
                    hint: 'e.g. 70.5',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.monitor_weight_outlined,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (double.tryParse(value) == null) {
                          return 'Invalid weight';
                        }
                      }
                      return null;
                    },
                  ),
                  const Divider(height: 32),
                ],

                // DOCTOR SPECIFIC FIELDS
                if (isDoctor) ...[
                  const Divider(height: 32),
                  const Text(
                    'Professional Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _hospitalController,
                    label: 'Hospital / Clinic Name',
                    hint: 'Where do you practice?',
                    prefixIcon: Icons.local_hospital_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value!.isEmpty ? 'Required for doctors' : null,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _specializationController,
                    label: 'Specialization',
                    hint: 'e.g. Cardiologist, General Physician',
                    prefixIcon: Icons.school_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value!.isEmpty ? 'Required for doctors' : null,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _medRegController,
                    label: 'Medical Registration No. (Optional)',
                    hint: 'Registration ID',
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const Divider(height: 32),
                ],

                // Password Fields
                AuthTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please create a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Confirm your password',
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() =>
                      _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Sign up button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 24),
                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}