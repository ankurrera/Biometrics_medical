import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/two_factor_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import 'two_factor_verification_screen.dart';

class SignInScreen extends ConsumerStatefulWidget {
  final String role;

  const SignInScreen({super.key, required this.role});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isBiometricLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  IconData get _roleIcon {
    switch (widget.role) {
      case 'doctor':
        return Icons.medical_services_rounded;
      case 'pharmacist':
        return Icons.local_pharmacy_rounded;
      case 'first_responder':
        return Icons.emergency_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authNotifierProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        // Refresh profile to get actual role from database
        ref.invalidate(currentProfileProvider);
        final profile = await ref.read(currentProfileProvider.future);
        
        if (profile == null) {
          throw Exception('Could not load profile');
        }

        // Validate role matches
        if (profile.role != widget.role) {
          // Sign out first
          await ref.read(authNotifierProvider.notifier).signOut();
          
          if (mounted) {
            // Show a dialog with the correct role info
            await _showRoleMismatchDialog(profile.role);
          }
          return;
        }

        // Handle different requirements based on sign-in result
        if (result.requiresTwoFactor && mounted) {
          // New device - require 2FA
          await _show2FADialog(result);
        } else if (result.requiresKyc && mounted) {
          // KYC not verified - redirect to KYC
          context.go(RouteNames.kycVerification);
        } else if (result.requiresBiometric && mounted) {
          // Biometric enrollment required - MANDATORY per spec
          // Use addPostFrameCallback to ensure navigation completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go(RouteNames.biometricEnrollment, extra: true);
            }
          });
        } else if (mounted) {
          // All requirements met - navigate to dashboard
          _navigateToDashboard(profile.role);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithBiometric() async {
    setState(() => _isBiometricLoading = true);

    try {
      // Attempt biometric authentication
      final success = await ref.read(authNotifierProvider.notifier).signInWithBiometric();

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Biometric authentication failed or session expired. Please sign in with your credentials.'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (mounted) {
        // Refresh profile to get user data
        ref.invalidate(currentProfileProvider);
        final profile = await ref.read(currentProfileProvider.future);

        if (profile == null) {
          throw Exception('Could not load profile');
        }

        // Validate role matches
        if (profile.role != widget.role) {
          // Sign out first
          await ref.read(authNotifierProvider.notifier).signOut();

          if (mounted) {
            // Show a dialog with the correct role info
            await _showRoleMismatchDialog(profile.role);
          }
          return;
        }

        // Navigate to dashboard
        _navigateToDashboard(profile.role);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Biometric authentication failed. Please try again or sign in with your credentials.';
        
        // Handle specific error cases
        final errorStr = e.toString();
        if (errorStr.contains('session expired') || errorStr.contains('timed out')) {
          errorMessage = 'Session expired. Please sign in with your credentials.';
        } else if (errorStr.contains('canceled')) {
          errorMessage = 'Authentication canceled. Please try again or sign in with your credentials.';
        } else if (errorStr.contains('not enrolled')) {
          errorMessage = 'No biometrics enrolled. Please set up biometric authentication in your device settings.';
        } else if (errorStr.contains('not available')) {
          errorMessage = 'Biometric authentication is not available on this device.';
        } else if (errorStr.contains('locked')) {
          errorMessage = 'Too many failed attempts. Please try again later or sign in with your credentials.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  Future<void> _show2FADialog(SignInResult result) async {
    // Show dialog to choose 2FA method
    final method = await showDialog<TwoFactorCodeType>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Two-Factor Authentication'),
        content: const Text(
          'This is a new device. Please verify your identity using a verification code.',
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, TwoFactorCodeType.email),
            icon: const Icon(Icons.email),
            label: const Text('Email Code'),
          ),
          // SMS option can be added here if phone number is available
        ],
      ),
    );

    if (method != null && mounted) {
      // Navigate to 2FA verification screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TwoFactorVerificationScreen(
            userId: result.user!.id,
            email: result.email ?? _emailController.text.trim(),
            codeType: method,
            onVerified: () async {
              // After 2FA is verified, get profile and complete setup
              final profile = await ref.read(currentProfileProvider.future);
              if (profile != null && mounted) {
                await _complete2FASetup(profile.role);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _complete2FASetup(String userRole) async {
    if (!mounted) return;

    // Ask if user wants to enable biometric
    final enableBiometric = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: const Text(
          'Would you like to enable biometric login (fingerprint/Face ID) for quick access on this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (mounted) {
      // Complete 2FA and register device
      await ref.read(authNotifierProvider.notifier).completeTwoFactor(
            registerDevice: true,
            enableBiometric: enableBiometric ?? false,
          );

      if (mounted) {
        _navigateToDashboard(userRole);
      }
    }
  }

  Future<void> _showRoleMismatchDialog(String actualRole) async {
    final actualRoleTitle = _formatRole(actualRole);
    final actualRoleColor = _getRoleColor(actualRole);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            const Expanded(child: Text('Wrong Role Selected')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This account is registered as:',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: actualRoleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: actualRoleColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getRoleIcon(actualRole), color: actualRoleColor),
                  const SizedBox(width: 12),
                  Text(
                    actualRoleTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: actualRoleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You selected "$_roleTitle" but your account is registered as "$actualRoleTitle". '
              'Please go back and select the correct role.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Go back to role selection
              context.go(RouteNames.roleSelection);
            },
            child: const Text('Go to Role Selection'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
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

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'doctor':
        return Icons.medical_services_rounded;
      case 'pharmacist':
        return Icons.local_pharmacy_rounded;
      case 'first_responder':
        return Icons.emergency_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'doctor':
        return 'Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      case 'first_responder':
        return 'First Responder';
      case 'patient':
      default:
        return 'Patient';
    }
  }

  void _navigateToDashboard(String role) {
    switch (role) {
      case 'doctor':
        context.go(RouteNames.doctorDashboard);
        break;
      case 'pharmacist':
        context.go(RouteNames.pharmacistDashboard);
        break;
      case 'first_responder':
        context.go(RouteNames.firstResponderDashboard);
        break;
      default:
        context.go(RouteNames.patientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Back button
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 32),
                // Role indicator - more prominent
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _roleColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _roleColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                  ),
                        child: Icon(
                          _roleIcon,
                          color: _roleColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Signing in as',
                              style: TextStyle(
                                fontSize: 12,
                                color: _roleColor.withOpacity(0.8),
                              ),
                            ),
                            Text(
                    _roleTitle,
                    style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                      color: _roleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(RouteNames.roleSelection),
                        style: TextButton.styleFrom(
                          foregroundColor: _roleColor,
                        ),
                        child: const Text('Change'),
                    ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your $_roleTitle account credentials',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 40),
                // Email field
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
                // Password field
                AuthTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
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
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 24),
                // Sign in button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 24),
                // Biometric login section
                Consumer(
                  builder: (context, ref, child) {
                    final biometricAvailable = ref.watch(biometricAvailableProvider);
                    final biometricEnabled = ref.watch(biometricEnabledProvider);
                    final biometricTypeName = ref.watch(biometricTypeNameProvider);

                    // Only show if both conditions are met
                    final shouldShow = (biometricAvailable.valueOrNull ?? false) &&
                                       (biometricEnabled.valueOrNull ?? false);

                    if (!shouldShow) return const SizedBox.shrink();

                    final typeName = biometricTypeName.valueOrNull ?? 'Biometric';
                    final isFaceId = typeName.toLowerCase().contains('face');

                    return Column(
                      children: [
                        // Divider with "OR"
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Biometric button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (_isBiometricLoading || _isLoading) ? null : _signInWithBiometric,
                            icon: _isBiometricLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isFaceId ? Icons.face_rounded : Icons.fingerprint_rounded,
                                    size: 24,
                                  ),
                            label: Text('Sign in with $typeName'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: _roleColor.withOpacity(0.5),
                                width: 2,
                              ),
                              foregroundColor: _roleColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.push(RouteNames.signUp, extra: widget.role);
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

