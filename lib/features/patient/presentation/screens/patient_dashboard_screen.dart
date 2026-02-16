import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family/providers/family_provider.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch active profile (supports switching between self and family members)
    final profile = ref.watch(activeContextProfileProvider);
    final todayDate = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────────
              // 1. HEADER (Clean & Professional)
              // ─────────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todayDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hi, ${profile.valueOrNull?.fullName.split(' ').first ?? 'Patient'}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  // Profile Avatar / Settings Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      // FIX: Changed from patientPrivacy to profile
                      onTap: () => context.push(RouteNames.profile),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_outline_rounded,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ─────────────────────────────────────────────────────────────────
              // 2. MEDICAL ID CARD (Premium Look)
              // ─────────────────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push(RouteNames.patientQrCode),
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Background Decorations
                        Positioned(
                          right: -40,
                          top: -40,
                          child: CircleAvatar(
                            radius: 80,
                            backgroundColor: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        Positioned(
                          left: -20,
                          bottom: -20,
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white.withOpacity(0.05),
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.qr_code_2_rounded,
                                        color: Colors.white, size: 24),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'ID CARD',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Emergency Access',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to generate QR for responders',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ─────────────────────────────────────────────────────────────────
              // 3. FEATURED (Horizontal Scroll)
              // ─────────────────────────────────────────────────────────────────
              _buildSectionTitle(context, 'Find Care'),
              const SizedBox(height: 16),

              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  children: [
                    _buildFeatureCard(
                      context,
                      title: 'Top\nDoctors',
                      icon: Icons.star_rate_rounded,
                      color: const Color(0xFF059669), // Emerald
                      isHighlighted: true,
                      onTap: () {},
                    ),
                    const SizedBox(width: 16),
                    _buildFeatureCard(
                      context,
                      title: 'Specialist\nConsult',
                      icon: Icons.medical_services_rounded,
                      color: const Color(0xFF0284C7), // Sky
                      isHighlighted: false,
                      onTap: () {},
                    ),
                    const SizedBox(width: 16),
                    _buildFeatureCard(
                      context,
                      title: 'Urgent\nCare',
                      icon: Icons.emergency_rounded,
                      color: const Color(0xFFDC2626), // Red
                      isHighlighted: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ─────────────────────────────────────────────────────────────────
              // 4. QUICK ACTIONS GRID
              // ─────────────────────────────────────────────────────────────────
              _buildSectionTitle(context, 'Manage Health'),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0, // Square tiles for modern look
                children: [
                  _buildActionTile(
                    context,
                    title: 'My Rx',
                    subtitle: 'Active scripts',
                    icon: Icons.medication_liquid_rounded,
                    color: Colors.blue.shade600,
                    onTap: () => context.push(RouteNames.patientPrescriptions),
                  ),
                  _buildActionTile(
                    context,
                    title: 'History',
                    subtitle: 'Medical records',
                    icon: Icons.history_edu_rounded,
                    color: Colors.purple.shade600,
                    onTap: () => context.push(RouteNames.patientMedicalHistory),
                  ),
                  _buildActionTile(
                    context,
                    title: 'New Rx',
                    subtitle: 'Upload prescription',
                    icon: Icons.add_a_photo_rounded,
                    color: Colors.orange.shade600,
                    onTap: () => context.push(RouteNames.patientNewPrescription),
                  ),
                  _buildActionTile(
                    context,
                    title: 'Privacy',
                    subtitle: 'Data controls',
                    icon: Icons.shield_rounded,
                    color: Colors.teal.shade600,
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
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
        bool isHighlighted = false,
      }) {
    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: isHighlighted ? color : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? null
            : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? color.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? Colors.white.withOpacity(0.2)
                        : color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isHighlighted ? Colors.white : color,
                    size: 20,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: isHighlighted ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (!isHighlighted)
                      Icon(Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.textLight
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

  Widget _buildActionTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
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