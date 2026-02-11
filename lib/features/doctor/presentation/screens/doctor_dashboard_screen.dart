import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/presentation/widgets/dashboard_header.dart';
// Note: We are building custom modern cards here to match the reference image exactly,
// effectively replacing the generic QuickActionCard for this specific screen.

final doctorTodayStatsProvider = FutureProvider<int>((ref) async {
  return await SupabaseService.instance.getTodaysPrescriptionCount();
});

final doctorTotalStatsProvider = FutureProvider<int>((ref) async {
  return await SupabaseService.instance.getTotalPrescriptionCount();
});

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final todayStats = ref.watch(doctorTodayStatsProvider);
    final totalStats = ref.watch(doctorTotalStatsProvider);

    return Scaffold(
      // The reference uses a very light/clean background.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(doctorTodayStatsProvider);
            ref.invalidate(doctorTotalStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Section
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: DashboardHeader(
                    greeting: 'Welcome back,',
                    name: 'Dr. ${profile.valueOrNull?.fullName.split(' ').first ?? 'Williams'}',
                    subtitle: 'Manage your patients',
                    roleColor: AppColors.doctor,
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Quick Access Section (Solid Blocks like Reference)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text(
                    'Quick Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildModernQuickAction(
                        context,
                        title: 'Find\nPatient',
                        icon: Icons.person_search_rounded,
                        color: AppColors.primary,
                        onTap: () => context.push(RouteNames.doctorPatientLookup),
                      ),
                      const SizedBox(width: 16),
                      _buildModernQuickAction(
                        context,
                        title: 'New\nPrescription',
                        icon: Icons.add_circle_outline_rounded,
                        color: const Color(0xFF547DE5), // Reference Image Blue
                        onTap: () => context.push(RouteNames.doctorPatientLookup),
                      ),
                      const SizedBox(width: 16),
                      _buildModernQuickAction(
                        context,
                        title: 'Scan\nQR Code',
                        icon: Icons.qr_code_scanner_rounded,
                        color: AppColors.accent,
                        onTap: () => context.push(RouteNames.doctorPatientLookup),
                      ),
                      const SizedBox(width: 16),
                      _buildModernQuickAction(
                        context,
                        title: 'History\nLog',
                        icon: Icons.history_rounded,
                        color: AppColors.secondary,
                        onTap: () => context.push(RouteNames.doctorHistory),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Overview / Stats (Clean White Cards like Reference Screen 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModernStatCard(
                          context,
                          label: 'Today\'s Rx',
                          value: todayStats.valueOrNull?.toString() ?? '0',
                          icon: Icons.today_rounded,
                          iconColor: AppColors.doctor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildModernStatCard(
                          context,
                          label: 'Total Rx',
                          value: totalStats.valueOrNull?.toString() ?? '0',
                          icon: Icons.description_outlined,
                          iconColor: AppColors.pharmacist,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 4. Recent Activity (Styled List Container)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () {}, // Navigate to full history if needed
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Empty State adapted to look like a placeholder for the list
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 32,
                          color: AppColors.textLight.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No recent prescriptions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Prescriptions you create will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom padding for scroll
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Matches the "Requests" / "Patients" solid buttons in reference
  Widget _buildModernQuickAction(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: 140, // Fixed width for horizontal scrolling cards
          height: 140, // Square aspect ratio like reference
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Matches the clean white stats cards in reference (Screen 2)
  Widget _buildModernStatCard(
      BuildContext context, {
        required String label,
        required String value,
        required IconData icon,
        required Color iconColor,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}