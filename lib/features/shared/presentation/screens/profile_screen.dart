import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart'; // Import for KYCStatus enum
import '../../../auth/providers/auth_provider.dart';
import '../widgets/profile_stats_card.dart';
import '../widgets/floating_bottom_nav.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch both Profile and KYC providers
    final profileAsync = ref.watch(currentProfileProvider);
    final kycAsync = ref.watch(kycStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Stack(
        children: [
          // Background Decorative Circle
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          SafeArea(
            bottom: false,
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (profile) {
                // 2. Calculate KYC Status correctly using the AsyncValue
                final kycData = kycAsync.valueOrNull;
                final isVerified = kycData?.status == KYCStatus.verified;

                // Calculate percentage: 60% base + 40% if verified
                final kycPercent = isVerified ? 1.0 : 0.6;
                final kycPercentText = (kycPercent * 100).toInt();

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
                  child: Column(
                    children: [
                      // ─── 1. Header ───────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const BackButton(color: AppColors.textPrimary),
                          Text(
                            'Profile',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // Optional: Add logic to edit profile
                            },
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Avatar & Badge
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              image: profile?.avatarUrl != null
                                  ? DecorationImage(
                                image: NetworkImage(profile!.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: profile?.avatarUrl == null
                                ? const Icon(Icons.person_rounded, size: 48, color: AppColors.textLight)
                                : null,
                          ),
                          // Verified Badge
                          if (isVerified)
                            Positioned(
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Text(
                                  'Verified',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile?.fullName ?? 'Patient Name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?.email ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ─── 2. Identity Verification Card ───────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => context.push(RouteNames.kycVerification),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Identity Verification',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$kycPercentText%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: kycPercent,
                                  backgroundColor: AppColors.backgroundLight,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isVerified
                                    ? 'Your identity is fully verified.'
                                    : 'Complete your KYC to unlock all features.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ─── 3. Information Management Cards ───────────────
                      Row(
                        children: [
                          // "Manage Devices" converted to Card
                          ProfileStatsCard(
                            title: 'Active\nDevices',
                            value: '2', // You can replace this with real count later
                            subtitle: 'Manage access',
                            icon: Icons.devices_rounded,
                            accentColor: const Color(0xFF38BDF8), // Sky Blue
                            showOnlineIndicator: true,
                            onTap: () => context.push(RouteNames.deviceManagement),
                          ),
                          // "Family/Dependents"
                          ProfileStatsCard(
                            title: 'Family\nMembers',
                            value: '0',
                            subtitle: 'Dependents',
                            icon: Icons.people_alt_rounded,
                            accentColor: const Color(0xFFA855F7), // Purple
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ─── 4. Settings Section ─────────────────────────────
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSettingsGroup([
                        _buildSettingsTile(
                          icon: Icons.fingerprint_rounded,
                          title: 'Biometric Login',
                          isToggle: true,
                          toggleValue: true,
                          onToggle: (val) {
                            // Implement toggle logic here if needed
                          },
                        ),
                        _buildSettingsTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'Change Password',
                          onTap: () {
                            // Add change password navigation
                          },
                        ),
                        _buildSettingsTile(
                          icon: Icons.logout_rounded,
                          title: 'Sign Out',
                          isDestructive: true,
                          // 3. Fixed Provider Name: authNotifierProvider
                          onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),

          // ─── 5. Floating Navigation ──────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingBottomNav(
              currentIndex: 3, // Profile index
              onTap: (index) {
                if (index == 0) context.go(RouteNames.patientDashboard);
                // Handle other indices
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    bool isToggle = false,
    bool toggleValue = false,
    ValueChanged<bool>? onToggle,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDestructive ? AppColors.error.withOpacity(0.1) : AppColors.backgroundLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDestructive ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDestructive ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          trailing: isToggle
              ? Switch.adaptive(
            value: toggleValue,
            activeColor: AppColors.primary,
            onChanged: onToggle,
          )
              : const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
        ),
        if (!isDestructive && !isToggle) // Separator
          Divider(height: 1, indent: 64, color: AppColors.border.withOpacity(0.5)),
      ],
    );
  }
}