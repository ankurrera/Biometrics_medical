import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/providers/family_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family/data/family_service.dart'; // For FamilyMember type

class FamilyMemberList extends ConsumerWidget {
  const FamilyMemberList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyMembersAsync = ref.watch(familyMembersProvider);
    final activeId = ref.watch(activeProfileIdProvider);
    final userAsync = ref.watch(currentProfileProvider);

    return familyMembersAsync.when(
      data: (members) {
        // If no family members, simply hide the widget
        if (members.isEmpty) return const SizedBox.shrink();

        final currentUser = userAsync.valueOrNull;
        if (currentUser == null) return const SizedBox.shrink();

        // Build list: Me + Family Members
        final List<({String id, String name, bool isMe})> profiles = [
          (id: currentUser.id, name: 'Me', isMe: true),
          ...members.map((m) => (
            id: m.profile.id,
            name: m.profile.fullName.split(' ').first,
            isMe: false,
          )),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profiles',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  // Optional: "Manage" text button could go here
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100, // Slightly taller for better touch targets
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: profiles.length + 1, // +1 for "Add" button
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  if (index == profiles.length) {
                    return _buildAddButton(context);
                  }

                  final profile = profiles[index];
                  final isActive = profile.id == activeId;

                  return _buildProfileItem(
                    context: context,
                    ref: ref,
                    id: profile.id,
                    name: profile.name,
                    isActive: isActive,
                    isMe: profile.isMe, // Pass isMe to differentiate visual
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildProfileItem({
    required BuildContext context,
    required WidgetRef ref,
    required String id,
    required String name,
    required bool isActive,
    required bool isMe,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(activeProfileIdProvider.notifier).state = id;
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(3), // Space for the ring
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: CircleAvatar(
              radius: 28, // Good size
              backgroundColor: isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant, // Slightly darker than surfaceLight
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to Add Family Member screen
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3), // Match alignment
            child: Container(
              width: 56, // Match CircleAvatar diameter (28*2)
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceLight,
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                ), // Dashed effect simulated with a clean light border usually looks better in modern UI
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
