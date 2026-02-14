import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/presentation/widgets/dashboard_header.dart';

// Provider for today's count
final doctorTodayStatsProvider = FutureProvider<int>((ref) async {
  return await SupabaseService.instance.getTodaysPrescriptionCount();
});

// Provider for total count
final doctorTotalStatsProvider = FutureProvider<int>((ref) async {
  return await SupabaseService.instance.getTotalPrescriptionCount();
});

// Provider for recent activity (last 3 days)
final recentActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await SupabaseService.instance.getDoctorRecentPrescriptions();
});

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final todayStats = ref.watch(doctorTodayStatsProvider);
    final totalStats = ref.watch(doctorTotalStatsProvider);
    final recentActivity = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────────────
            // TOP SECTION: Header & Stats
            // ─────────────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  DashboardHeader(
                    greeting: 'Welcome back,',
                    name: 'Dr. ${profile.valueOrNull?.fullName.split(' ').first ?? 'Williams'}',
                    subtitle: 'Here is your daily overview',
                    roleColor: AppColors.doctor,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGradientStatCard(
                          label: 'Today\'s Rx',
                          // DIRECTLY DISPLAYING TODAY'S STATS FROM PROVIDER
                          value: todayStats.valueOrNull?.toString() ?? '0',
                          icon: Icons.edit_calendar_rounded,
                          primaryColor: AppColors.doctor,
                          secondaryColor: const Color(0xFFA78BFA),
                          trend: 'Today',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGradientStatCard(
                          label: 'Total Patients',
                          value: totalStats.valueOrNull?.toString() ?? '0',
                          icon: Icons.people_alt_rounded,
                          primaryColor: AppColors.primary,
                          secondaryColor: const Color(0xFF2DD4BF),
                          trend: 'All Time',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────────────────
            // BOTTOM SECTION: Actions & Activity
            // ─────────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Quick Actions'),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 140, // Increased slightly for the new clean layout
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        _buildGradientFeatureCard(
                          context,
                          title: 'Find Patient',
                          subtitle: 'Search records',
                          icon: Icons.person_search_rounded,
                          primaryColor: AppColors.primary,
                          secondaryColor: const Color(0xFF2DD4BF), // Teal Accent
                          onTap: () => context.push(RouteNames.doctorPatientLookup),
                        ),
                        const SizedBox(width: 16),
                        _buildGradientFeatureCard(
                          context,
                          title: 'New Rx',
                          subtitle: 'Create Script',
                          icon: Icons.add_circle_outline_rounded,
                          primaryColor: AppColors.doctor,
                          secondaryColor: const Color(0xFFA78BFA), // Purple Accent
                          onTap: () => context.push(RouteNames.doctorPatientLookup),
                        ),
                        const SizedBox(width: 16),
                        _buildGradientFeatureCard(
                          context,
                          title: 'History',
                          subtitle: 'View Logs',
                          icon: Icons.history_rounded,
                          primaryColor: AppColors.secondary,
                          secondaryColor: const Color(0xFFFFD700), // Gold Accent
                          onTap: () => context.push(RouteNames.doctorHistory),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Recent Activity (3 Days)'),
                      TextButton(
                        onPressed: () => context.push(RouteNames.doctorHistory),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // RECENT ACTIVITY LIST (Dynamic)
                  recentActivity.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Error: $err'),
                    data: (data) {
                      if (data.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      return Column(
                        children: data.map((rx) {
                          // Extract patient name safely
                          final patient = rx['patient'] as Map<String, dynamic>?;
                          final profiles = patient?['profiles'] as Map<String, dynamic>?;
                          final patientName = profiles?['full_name'] as String? ?? 'Unknown Patient';
                          final diagnosis = rx['diagnosis'] as String? ?? 'No diagnosis';
                          final date = DateTime.parse(rx['created_at']);
                          final formattedDate = DateFormat('MMM d, h:mm a').format(date);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.doctor.withOpacity(0.1),
                                child: Text(
                                  patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppColors.doctor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                patientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    diagnosis,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                              onTap: () {
                                // Navigate to prescription details if needed
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.backgroundLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_add,
              size: 32,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prescriptions created in the last 3 days will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [AppColors.doctor, Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.doctor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push(RouteNames.doctorPatientLookup),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Create New Prescription',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }

  /// Stat Card with Gradient Decoration Shape
  Widget _buildGradientStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color primaryColor,
    required Color secondaryColor,
    required String trend,
  }) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.15),
                    secondaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: primaryColor, size: 20),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trend,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Feature Card with "Clean Shape" Gradient Decoration
  Widget _buildGradientFeatureCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color primaryColor,
        required Color secondaryColor,
        required VoidCallback onTap,
      }) {
    return Container(
      width: 130, // Fixed width for consistency
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Decorative Gradient Shape (Top Right)
              Positioned(
                right: -15,
                top: -15,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.15),
                        secondaryColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon Container
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),

                    // Text Content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
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
    );
  }
}