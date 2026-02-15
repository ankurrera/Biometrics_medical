import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family/providers/family_provider.dart';
import '../../../shared/presentation/widgets/dashboard_header.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch active profile
    final profile = ref.watch(activeContextProfileProvider);
    final todayDate = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 background
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────────
              // 1. HEADER
              // ─────────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todayDate.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hello, ${profile.valueOrNull?.fullName.split(' ').first ?? 'Patient'}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  // Profile Avatar / Settings Button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.person_outline_rounded, color: AppColors.textPrimary),
                      onPressed: () => context.push(RouteNames.patientPrivacy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ─────────────────────────────────────────────────────────────────
              // 2. EMERGENCY / ID CARD
              // ─────────────────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)], // Teal Gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative Curves
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Content
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push(RouteNames.patientQrCode),
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Medical ID Access',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Text(
                                'Tap to show QR Code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'For emergency responders',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ─────────────────────────────────────────────────────────────────
              // 3. SERVICES GRID
              // ─────────────────────────────────────────────────────────────────
              const Text(
                'Services',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  // CARD 1: My Prescriptions (Blue)
                  _buildPatientTile(
                    title: 'My Rx',
                    subtitle: 'View Active',
                    icon: Icons.medication_rounded,
                    themeColor: const Color(0xFF38BDF8),
                    onTap: () => context.push(RouteNames.patientPrescriptions),
                  ),

                  // CARD 2: Medical History (Purple)
                  _buildPatientTile(
                    title: 'History',
                    subtitle: 'Past Records',
                    icon: Icons.history_rounded,
                    themeColor: const Color(0xFFA855F7),
                    onTap: () => context.push(RouteNames.patientMedicalHistory),
                  ),

                  // CARD 3: Add New (Orange)
                  _buildPatientTile(
                    title: 'New Rx',
                    subtitle: 'Add Script',
                    icon: Icons.add_rounded,
                    themeColor: const Color(0xFFFB923C),
                    onTap: () => context.push(RouteNames.patientNewPrescription),
                  ),

                  // CARD 4: Settings (Teal)
                  _buildPatientTile(
                    title: 'Privacy',
                    subtitle: 'Manage Data',
                    icon: Icons.security_rounded,
                    themeColor: const Color(0xFF2DD4BF),
                    onTap: () => context.push(RouteNames.patientPrivacy),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ───────────────────────────────────────────────────────────────────────
  /// WIDGET: Patient Category Tile
  /// STYLE: "Tinted Watermark" (Distinct from Doctor's "White Gradient")
  /// ───────────────────────────────────────────────────────────────────────
  Widget _buildPatientTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        // DIFFERENCE 1: Tinted Background (instead of white)
        color: themeColor.withOpacity(0.04),
        // DIFFERENCE 2: Colored Border (instead of grey)
        border: Border.all(color: themeColor.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // DIFFERENCE 3: Large "Watermark" Icon in background
              Positioned(
                right: -15,
                bottom: -15,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    icon,
                    size: 80, // Massive watermark
                    color: themeColor.withOpacity(0.06),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon (Perfect Circle instead of Squircle)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle, // DIFFERENCE 4: Circle shape
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: themeColor,
                        size: 24,
                      ),
                    ),

                    // Text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}