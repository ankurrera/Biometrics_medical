import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../providers/auth_provider.dart';

class BiometricEnrollmentScreen extends ConsumerStatefulWidget {
  final bool isMandatory;
  
  const BiometricEnrollmentScreen({
    super.key,
    this.isMandatory = false,
  });

  @override
  ConsumerState<BiometricEnrollmentScreen> createState() =>
      _BiometricEnrollmentScreenState();
}

class _BiometricEnrollmentScreenState
    extends ConsumerState<BiometricEnrollmentScreen> {
  bool _isLoading = false;
  bool _isEnrolling = false;

  @override
  void initState() {
    super.initState();
    // Trigger biometric setup at the right lifecycle moment
    if (widget.isMandatory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndEnrollBiometric();
      });
    }
  }

  Future<void> _checkAndEnrollBiometric() async {
    print('[BIO] Auto-triggering biometric setup (mandatory)');
    await _enrollBiometric();
  }

  Future<void> _enrollBiometric() async {
    setState(() {
      _isLoading = true;
      _isEnrolling = true;
    });

    try {
      print('[BIO] Starting enrollment');
      
      // KYC check - use robust method
      if (!widget.isMandatory) {
        print('[BIO] Checking KYC status (optional enrollment)');
        final session = ref.read(authStateProvider).valueOrNull;
        if (session == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session expired. Please sign in again.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        
        final kycService = KYCService.instance;
        final kycVerified = await kycService.isKYCVerified(session.id);
        print('[BIO] KYC verified = $kycVerified');
        
        if (!kycVerified) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('KYC verification required before enabling biometric login'),
                backgroundColor: AppColors.warning,
              ),
            );
            context.push(RouteNames.kycVerification);
          }
          return;
        }
      }

      print('[BIO] Calling enrollBiometric()');
      await ref.read(authNotifierProvider.notifier).enrollBiometric();

      print('[BIO] Enrollment successful');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login enabled successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _navigateToDashboard();
      }
    } catch (e) {
      print('[BIO] Enrollment failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_extractErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEnrolling = false;
        });
      }
    }
  }

  void _skipBiometric() {
    _navigateToDashboard();
  }

  /// Extract user-friendly error message from exception
  String _extractErrorMessage(Object error) {
    String errorMessage = error.toString();
    
    // Remove common exception prefixes
    final prefixes = ['Exception: ', 'AuthException: ', 'BiometricException: '];
    for (final prefix in prefixes) {
      if (errorMessage.startsWith(prefix)) {
        return errorMessage.substring(prefix.length);
      }
    }
    
    return errorMessage;
  }

  void _navigateToDashboard() {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    switch (profile?.role) {
      case 'doctor':
        context.go(RouteNames.doctorDashboard);
        break;
      case 'pharmacist':
        context.go(RouteNames.pharmacistDashboard);
        break;
      case 'first_responder':
        context.go(RouteNames.firstResponderDashboard);
        break;
      case 'patient':
      default:
        context.go(RouteNames.patientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricAvailable = ref.watch(biometricAvailableProvider);
    final biometricTypeName = ref.watch(biometricTypeNameProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              const Spacer(),
              // Icon animation container
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isEnrolling ? 160 : 140,
                height: _isEnrolling ? 160 : 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primaryLight.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: biometricTypeName.when(
                    data: (typeName) => Icon(
                      typeName == 'Face ID'
                          ? Icons.face_rounded
                          : Icons.fingerprint_rounded,
                      size: 72,
                      color: AppColors.primary,
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Icon(
                      Icons.fingerprint_rounded,
                      size: 72,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Title
              biometricTypeName.when(
                data: (typeName) => Text(
                  'Enable $typeName',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                loading: () => const Text(
                  'Enable Biometric Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                error: (_, __) => const Text(
                  'Enable Biometric Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use your biometrics for quick and secure sign-in on this device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Benefits list
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _buildBenefitRow(
                      Icons.bolt_rounded,
                      'Quick Access',
                      'Sign in instantly without typing',
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitRow(
                      Icons.security_rounded,
                      'Secure',
                      'Your biometric data never leaves the device',
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitRow(
                      Icons.devices_rounded,
                      'Device-Specific',
                      'Each device has its own secure enrollment',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Buttons
              biometricAvailable.when(
                data: (available) {
                  if (!available) {
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Biometric authentication is not available on this device.',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _skipBiometric,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _enrollBiometric,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : biometricTypeName.when(
                                  data: (typeName) => Text('Enable $typeName'),
                                  loading: () =>
                                      const Text('Enable Biometric'),
                                  error: (_, __) =>
                                      const Text('Enable Biometric'),
                                ),
                        ),
                      ),
                      // Only show skip button if not mandatory
                      if (!widget.isMandatory) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _isLoading ? null : _skipBiometric,
                            child: const Text('Skip for now'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _skipBiometric,
                    child: const Text('Continue'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

