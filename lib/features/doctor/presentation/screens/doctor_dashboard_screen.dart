import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/presentation/widgets/dashboard_header.dart';

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
      backgroundColor: const Color(0xFFF8FAFC), // Professional Slate-50 background
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(doctorTodayStatsProvider);
            ref.invalidate(doctorTotalStatsProvider);
          },
          color: AppColors.doctor,
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
                    greeting: 'Good Morning,',
                    name: 'Dr. ${profile.valueOrNull?.fullName.split(' ').first ?? 'Williams'}',
                    subtitle: 'Here is your daily summary',
                    roleColor: AppColors.doctor,
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Overview / Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B), // Slate-500
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildProfessionalStatCard(
                          context,
                          label: 'Today\'s Rx',
                          value: todayStats.valueOrNull?.toString() ?? '0',
                          icon: Icons.edit_calendar_rounded,
                          iconColor: AppColors.doctor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildProfessionalStatCard(
                          context,
                          label: 'Total Rx',
                          value: totalStats.valueOrNull?.toString() ?? '0',
                          icon: Icons.folder_open_rounded,
                          iconColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120, // Reduced height for cleaner look
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildCleanQuickAction(
                        context,
                        title: 'Find\nPatient',
                        icon: Icons.person_search_rounded,
                        color: AppColors.primary,
                        onTap: () => context.push(RouteNames.doctorPatientLookup),
                      ),
                      const SizedBox(width: 12),
                      _buildCleanQuickAction(
                        context,
                        title: 'Write\nRx',
                        icon: Icons.add_circle_outline_rounded,
                        color: AppColors.doctor,
                        onTap: () => context.push(RouteNames.doctorPatientLookup),
                      ),
                      // Removed "Scan QR" button as requested
                      const SizedBox(width: 12),
                      _buildCleanQuickAction(
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

                // 4. Recent Activity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push(RouteNames.doctorHistory),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'View all',
                            style: TextStyle(
                              color: AppColors.doctor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_outlined,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No recent prescriptions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Prescriptions you create will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Clean Wireframe Quick Action Style
  Widget _buildCleanQuickAction(
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 100,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF334155), // Slate-700
                  fontSize: 13,
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

  /// Professional Stats Card
  Widget _buildProfessionalStatCard(
      BuildContext context, {
        required String label,
        required String value,
        required IconData icon,
        required Color iconColor,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B), // Slate-800
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B), // Slate-500
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}