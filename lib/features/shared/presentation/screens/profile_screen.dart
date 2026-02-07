import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family/presentation/screens/family_members_screen.dart';
import '../../../family/providers/family_provider.dart';
import '../widgets/profile_stats_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(activeContextProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final activeId = ref.watch(activeProfileIdProvider);
    final isUsingFamilyAccount = authUser != null && activeId != authUser.id;

    final kycAsync = ref.watch(kycStatusProvider);
    final biometricEnabledAsync = ref.watch(biometricEnabledProvider);
    final familyMembersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
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
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: SafeArea(
                bottom: false,
                child: profileAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading profile: $err')),
                  data: (profile) {
                    if (profile == null) return const Center(child: Text("Profile not found"));

                    final isVerified = kycAsync.valueOrNull?.status == KYCStatus.verified;
                    final kycPercentText = isVerified ? '100' : '60';

                    return Column(
                      children: [
                        if (isUsingFamilyAccount)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Viewing Family Profile',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        profile.fullName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => ref.read(familyControllerProvider.notifier).switchAccount(null),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                  ),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Exit'),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const BackButton(color: AppColors.textPrimary),
                            Text(
                              'Profile',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (!isUsingFamilyAccount)
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.settings_outlined),
                                color: AppColors.textPrimary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 30),
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
                                image: profile.avatarUrl != null
                                    ? DecorationImage(
                                  image: NetworkImage(profile.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: profile.avatarUrl == null
                                  ? const Icon(Icons.person_rounded, size: 48, color: AppColors.textLight)
                                  : null,
                            ),
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
                          profile.fullName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AbsorbPointer(
                          absorbing: isUsingFamilyAccount,
                          child: Opacity(
                            opacity: isUsingFamilyAccount ? 0.7 : 1.0,
                            child: Container(
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
                                        value: isVerified ? 1.0 : 0.6,
                                        backgroundColor: AppColors.backgroundLight,
                                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isVerified
                                          ? 'Identity is fully verified.'
                                          : 'Complete KYC to unlock all features.',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            ProfileStatsCard(
                              title: 'Active\nDevices',
                              value: '2',
                              subtitle: 'Manage access',
                              icon: Icons.devices_rounded,
                              accentColor: const Color(0xFF38BDF8),
                              showOnlineIndicator: true,
                              onTap: isUsingFamilyAccount
                                  ? () {}
                                  : () => context.push(RouteNames.deviceManagement),
                            ),
                            ProfileStatsCard(
                              title: 'Family\nMembers',
                              value: familyMembersAsync.valueOrNull?.length.toString() ?? '0',
                              subtitle: 'Dependents',
                              icon: Icons.people_alt_rounded,
                              accentColor: const Color(0xFFA855F7),
                              onTap: isUsingFamilyAccount
                                  ? () {}
                                  : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FamilyMembersScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        if (!isUsingFamilyAccount)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                ),
                                icon: const Icon(Icons.swap_horiz_rounded),
                                label: const Text('Switch Account'),
                                onPressed: () {
                                  _showAccountSwitcher(context, ref, familyMembersAsync);
                                },
                              ),
                            ),
                          ),
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
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border.withOpacity(0.5)),
                          ),
                          child: Column(
                            children: [
                              if (!isUsingFamilyAccount)
                                _buildSettingsTile(
                                  icon: Icons.people_outline_rounded,
                                  title: 'Family & Dependents',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
                                  ),
                                ),
                              if (!isUsingFamilyAccount)
                                _buildSettingsTile(
                                  icon: Icons.fingerprint_rounded,
                                  title: 'Biometric Login',
                                  isToggle: true,
                                  toggleValue: biometricEnabledAsync.valueOrNull ?? false,
                                  onToggle: (val) async {
                                    try {
                                      await ref.read(authNotifierProvider.notifier).toggleBiometric(val);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to update: ${e.toString()}'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              if (!isUsingFamilyAccount)
                                _buildSettingsTile(
                                  icon: Icons.lock_outline_rounded,
                                  title: 'Change Password',
                                  onTap: () {},
                                ),
                              _buildSettingsTile(
                                icon: Icons.logout_rounded,
                                title: isUsingFamilyAccount ? 'Exit Family View' : 'Sign Out',
                                isDestructive: true,
                                onTap: () {
                                  if (isUsingFamilyAccount) {
                                    ref.read(familyControllerProvider.notifier).switchAccount(null);
                                  } else {
                                    ref.read(authNotifierProvider.notifier).signOut();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountSwitcher(BuildContext context, WidgetRef ref, AsyncValue<List<dynamic>> membersAsync) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                const Text(
                  'Switch Account',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Text("No linked family accounts yet."),
                      ],
                    ),
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: members.map((member) => ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: member.profile.avatarUrl != null
                          ? NetworkImage(member.profile.avatarUrl!)
                          : null,
                      child: member.profile.avatarUrl == null
                          ? Text(member.profile.fullName[0].toUpperCase())
                          : null,
                    ),
                    label: Text(member.profile.fullName),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      ref.read(familyControllerProvider.notifier).switchAccount(member.profile.id);
                      Navigator.pop(context);
                    },
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_,__) => const Text("Error loading accounts"),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add New Family Member'),
              ),
            ),
          ],
        ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
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
        if (!isDestructive)
          Divider(height: 1, indent: 70, color: AppColors.border.withOpacity(0.3)),
      ],
    );
  }
}