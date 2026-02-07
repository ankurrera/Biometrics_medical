import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
// Ensure this import is present for the providers:
import '../screens/notifications_screen.dart';
// ... rest of the file

class DashboardHeader extends ConsumerWidget {
  final String greeting;
  final String name;
  final String subtitle;
  final Color roleColor;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  const DashboardHeader({
    super.key,
    required this.greeting,
    required this.name,
    required this.subtitle,
    required this.roleColor,
    this.onNotificationTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 26, // Larger font for impact
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        // Notification Button (Glass style)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              IconButton(
                onPressed: onNotificationTap ?? () => context.push(RouteNames.notifications),
                icon: const Icon(Icons.notifications_outlined, size: 26),
                color: AppColors.textPrimary,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Profile Picture
        GestureDetector(
          onTap: onProfileTap ?? () => context.push(RouteNames.profile),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16), // Rounded square (Modern trend)
              image: profile.valueOrNull?.avatarUrl != null
                  ? DecorationImage(
                image: NetworkImage(profile.valueOrNull!.avatarUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: profile.valueOrNull?.avatarUrl == null
                ? Icon(Icons.person_rounded, color: roleColor)
                : null,
          ),
        ),
      ],
    );
  }
}