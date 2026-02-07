import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/presentation/widgets/dashboard_header.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cleaner Header
              DashboardHeader(
                greeting: 'Good Morning,',
                name: profile.valueOrNull?.fullName.split(' ').first ?? 'Patient',
                subtitle: 'How are you feeling today?',
                roleColor: AppColors.patient,
              ),
              const SizedBox(height: 32),

              // 2. "Glass" Style Emergency Banner
              // Dribbble designs often use gradients + absolute positioning for illustrations
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative Circle
                    Positioned(
                      top: -20,
                      right: -20,
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
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Medical ID',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Emergency\nQR Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap to view details',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    // Tap Area
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(32),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: () => context.push(RouteNames.patientQrCode),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 3. Modern Grid Actions
              const Text(
                'Services',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1, // Slightly wider cards
                children: [
                  _buildModernActionCard(
                    context,
                    title: 'My\nPrescriptions',
                    icon: Icons.medication_outlined,
                    color: const Color(0xFF38BDF8), // Sky Blue
                    onTap: () => context.push(RouteNames.patientPrescriptions),
                  ),
                  _buildModernActionCard(
                    context,
                    title: 'Medical\nHistory',
                    icon: Icons.history_rounded,
                    color: const Color(0xFFA855F7), // Purple
                    onTap: () => context.push(RouteNames.patientMedicalHistory),
                  ),
                  _buildModernActionCard(
                    context,
                    title: 'Add\nNew',
                    icon: Icons.add_circle_outline_rounded,
                    color: const Color(0xFFFB923C), // Orange
                    onTap: () => context.push(RouteNames.patientNewPrescription),
                  ),
                  _buildModernActionCard(
                    context,
                    title: 'Privacy\nSettings',
                    icon: Icons.shield_outlined,
                    color: const Color(0xFF22C55E), // Green
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

  // A local widget helper for the "Dribbble-style" square cards
  Widget _buildModernActionCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}