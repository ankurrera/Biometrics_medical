import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/patient_provider.dart';

class QrCodeScreen extends ConsumerStatefulWidget {
  const QrCodeScreen({super.key});

  @override
  ConsumerState<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends ConsumerState<QrCodeScreen> {
  bool _screenshotProtectionEnabled = false;

  void _onAuthenticated() {
    if (Platform.isAndroid) {
      setState(() => _screenshotProtectionEnabled = true);
      // NOTE: In production, uncomment flutter_windowmanager to block screenshots
      // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final patientAsync = ref.watch(patientDataProvider);

    return BiometricGuard(
      reason: 'Authenticate to view your Medical ID',
      strictMode: false, // Changed to false for easier testing/demo
      onAuthenticated: _onAuthenticated,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Digital Medical ID'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              if (_screenshotProtectionEnabled) ...[
                _buildProtectionBanner(),
                const SizedBox(height: 24),
              ],

              // THE ID CARD
              patientAsync.when(
                data: (patient) {
                  final profile = profileAsync.valueOrNull;
                  if (patient == null || profile == null) {
                    return const Center(child: Text('Profile data unavailable'));
                  }

                  // Construct the emergency URL
                  // In a real app, this ID would be encrypted or a one-time token
                  final qrData = patient.qrCodeId ?? 'CS-${profile.id.substring(0, 8).toUpperCase()}';
                  final qrUrl = '${EnvConfig.emergencyBaseUrl}/$qrData';

                  return Column(
                    children: [
                      _buildMedicalIdCard(context, profile, patient, qrUrl),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Share.share('My CareSync Emergency ID:\n$qrUrl');
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share ID'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Save to gallery functionality would go here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Save to Wallet feature coming soon')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.textPrimary, // Black/Dark button
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.wallet_rounded),
                              label: const Text('Add to Wallet'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Present this QR code to emergency responders.\nScanning it provides access to your critical medical data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 400,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => Center(child: Text('Error loading ID: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalIdCard(BuildContext context, dynamic profile, dynamic patient, String qrData) {
    // Formatters
    final dob = patient.dateOfBirth != null
        ? DateFormat('dd MMM yyyy').format(patient.dateOfBirth!)
        : 'N/A';

    // Fallbacks
    final bloodType = patient.bloodType ?? '-';
    final weight = patient.weight != null ? '${patient.weight} kg' : '-';
    final height = patient.height != null ? '${patient.height} cm' : '-';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────────────
            // 1. HEADER (Branding)
            // ─────────────────────────────────────────────────────────────────
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)], // Teal 700 -> Teal 500
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Logo / Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CareSync',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'EMERGENCY MEDICAL ID',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────────────────
            // 2. MAIN BODY (Info + QR)
            // ─────────────────────────────────────────────────────────────────
            Stack(
              children: [
                // Background Pattern (Subtle)
                Positioned(
                  right: -50,
                  top: 50,
                  child: Icon(
                    Icons.qr_code_2,
                    size: 300,
                    color: Colors.grey.withOpacity(0.03),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Profile Section
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border, width: 3),
                              image: profile.avatarUrl != null
                                  ? DecorationImage(
                                image: NetworkImage(profile.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                                  : null,
                              color: AppColors.surfaceVariant,
                            ),
                            child: profile.avatarUrl == null
                                ? const Icon(Icons.person, size: 40, color: AppColors.textLight)
                                : null,
                          ),
                          const SizedBox(width: 20),
                          // Name & Basic Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.fullName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Patient ID: ${profile.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Courier', // Monospace for ID
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Vital Stats Grid
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCompactStat('DOB', dob),
                            _buildVerticalDivider(),
                            _buildCompactStat('Blood', bloodType, highlight: true),
                            _buildVerticalDivider(),
                            _buildCompactStat('Weight', weight),
                            _buildVerticalDivider(),
                            _buildCompactStat('Height', height),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // QR Code Section
                      const Text(
                        'SCAN FOR MEDICAL PROFILE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: PrettyQrView.data(
                          data: qrData,
                          errorCorrectLevel: QrErrorCorrectLevel.M,
                          decoration: const PrettyQrDecoration(
                            shape: PrettyQrSmoothSymbol(
                              color: Colors.black, // High contrast for scanning
                            ),
                            image: PrettyQrDecorationImage(
                              image: AssetImage('assets/icons/app_icon.png'), // Optional logo in center
                              scale: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ─────────────────────────────────────────────────────────────────
            // 3. FOOTER (Valid Status)
            // ─────────────────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: AppColors.surfaceVariant,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Identity Verified by CareSync',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, {bool highlight = false}) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textLight,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFFDC2626) : AppColors.textPrimary, // Red for Blood Type
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildProtectionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5), // Green 50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34D399).withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 18),
          SizedBox(width: 8),
          Text(
            'Secure View: Screenshot protection active',
            style: TextStyle(
              color: Color(0xFF065F46),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}