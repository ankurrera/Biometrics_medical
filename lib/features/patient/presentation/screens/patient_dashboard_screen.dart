import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../family/providers/family_provider.dart';
import '../widgets/family_member_list.dart'; // NEW
import '../widgets/daily_medication_schedule.dart'; // NEW
import '../widgets/vitals_summary_card.dart'; // NEW

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch active profile (supports switching between self and family members)
    final profile = ref.watch(activeContextProfileProvider);
    final todayDate = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.softBackground, // Soft UI Background
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // Tighter vertical padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────────
              // 1. HEADER (Clean & Professional)
              // ─────────────────────────────────────────────────────────────────
              // ─────────────────────────────────────────────────────────────────
              // 1. HEADER (Soft UI Pill Style)
              // ─────────────────────────────────────────────────────────────────
              Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => context.push(RouteNames.profile),
                    child: Container(
                      padding: const EdgeInsets.all(2), // White Ring
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.softPrimary.withValues(alpha: 0.2),
                        child: Text(
                          profile.valueOrNull?.fullName.substring(0, 1).toUpperCase() ?? 'P',
                          style: const TextStyle(
                            color: AppColors.softPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Greeting Pill
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowSoft.withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Hi, ${profile.valueOrNull?.fullName.split(' ').first ?? 'Patient'}',
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowSoft.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: AppColors.textMain),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────────────────
              // 2. MEDICAL ID CARD (Premium Look) - NOW ON TOP
              // ─────────────────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.softPrimaryLight,
                      AppColors.softPrimary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28), // Sleeker roundness
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softPrimary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push(RouteNames.patientQrCode),
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        // Background Decorations (Subtle geometry)
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Icon chip
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.qr_code_2_rounded,
                                        color: Colors.white, size: 26),
                                  ),
                                  // Label chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: const Text(
                                      'EMERGENCY ID',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Emergency Access',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.touch_app_rounded, 
                                      size: 14, color: Colors.white.withValues(alpha: 0.7)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tap to generate secure QR',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
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
              ),
              const SizedBox(height: 28),
              
              // NEW: Family Profiles
              const FamilyMemberList(),
              
              // NEW: Daily Meds (Below ID Card as requested)
              const DailyMedicationSchedule(),
              
              // NEW: Vitals Section
              const VitalsSummaryCard(),
              const SizedBox(height: 28),

              // ─────────────────────────────────────────────────────────────────
              // 4. QUICK ACTIONS GRID
              // ─────────────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildSectionTitle(context, 'Manage Health'),
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildActionTile(
                    context,
                    title: 'My Rx',
                    subtitle: 'Prescriptions',
                    icon: Icons.medication_liquid_rounded,
                    color: Colors.blueAccent,
                    bgColor: AppColors.softBlue,
                    onTap: () => context.push(RouteNames.patientPrescriptions),
                  ),
                  _buildActionTile(
                    context,
                    title: 'History',
                    subtitle: 'Records',
                    icon: Icons.history_edu_rounded,
                    color: Colors.purpleAccent,
                    bgColor: AppColors.softPurple,
                    onTap: () => context.push(RouteNames.patientMedicalHistory),
                  ),
                  _buildActionTile(
                    context,
                    title: 'New Rx',
                    subtitle: 'Upload',
                    icon: Icons.add_a_photo_rounded,
                    color: Colors.orangeAccent,
                    bgColor: AppColors.softYellow,
                    onTap: () => context.push(RouteNames.patientNewPrescription),
                  ),
                  _buildActionTile(
                    context,
                    title: 'Privacy',
                    subtitle: 'Controls',
                    icon: Icons.shield_rounded,
                    color: Colors.green,
                    bgColor: const Color(0xFFDCFCE7), // Soft Green
                    onTap: () => context.push(RouteNames.patientPrivacy),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }


  Widget _buildActionTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Color bgColor,
        required VoidCallback onTap,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        // border: Border.all(color: Colors.white), // Optional: Inner white border
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1), // Colored shadow hint
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}