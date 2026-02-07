// lib/features/patient/presentation/screens/qr_code_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Build a compact JSON payload from the emergency profile data.
  String _buildQrPayload(Map<String, dynamic> data) {
    final payload = {
      '_t': 'caresync_emergency',
      'name': data['name'],
      'blood_type': data['blood_type'],
      'allergies': data['allergies'],
      'chronic_diseases': data['chronic_diseases'],
      'medications': data['medications'],
      'emergency_contact': data['emergency_contact'],
    };
    return jsonEncode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final emergencyData = ref.watch(emergencyQrDataProvider);

    return BiometricGuard(
      reason: 'Authenticate to view your Medical QR Code',
      strictMode: true,
      onAuthenticated: _onAuthenticated,
      child: Scaffold(
        appBar: AppBar(title: const Text('Emergency QR Code')),
        body: emergencyData.when(
          data: (data) {
            if (data == null) return const Center(child: Text('No medical data found. Please complete your profile.'));

            final qrData = _buildQrPayload(data);

            return SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  if (_screenshotProtectionEnabled)
                    _buildProtectionBanner(),
                  const SizedBox(height: 20),
                  _buildQrCard(profile.valueOrNull?.fullName, qrData),
                  const SizedBox(height: 16),
                  _buildInfoBanner(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Share.share(
                        'My CareSync Emergency Medical QR data is encoded in the QR code. '
                        'Scan with the CareSync app to view details.',
                      ),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share QR Info'),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildQrCard(String? name, String data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        children: [
          Text(name ?? 'Patient', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Emergency Medical Card', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 200,
            child: PrettyQrView.data(
              data: data,
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSmoothSymbol(color: AppColors.primaryDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This QR contains your emergency medical data. '
              'First responders can scan it to see your blood group, allergies, medications, and emergency contacts.',
              style: TextStyle(color: AppColors.info, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: AppColors.success, size: 20),
          SizedBox(width: 12),
          Text('Screenshot protection enabled', style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }
}