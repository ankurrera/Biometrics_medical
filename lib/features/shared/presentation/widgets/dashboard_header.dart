import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../screens/notifications_screen.dart';

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
        // Profile Avatar
        GestureDetector(
          onTap: onProfileTap ?? () => context.push(RouteNames.profile),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: roleColor.withValues(alpha: 0.3),
                width: 2,
              ),
              image: profile.valueOrNull?.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(profile.valueOrNull!.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: profile.valueOrNull?.avatarUrl == null
                ? Icon(
                    Icons.person_rounded,
                    color: roleColor,
                    size: 28,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 14),
        // Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Notification button with badge
        Stack(
          children: [
            IconButton(
              onPressed: onNotificationTap ?? () => context.push(RouteNames.notifications),
              icon: const Icon(Icons.notifications_outlined),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // Sign out button
        IconButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(authNotifierProvider.notifier).signOut();
              // Invalidate all providers on sign out
              ref.invalidate(currentProfileProvider);
              if (context.mounted) {
                context.go(RouteNames.roleSelection);
              }
            }
          },
          icon: const Icon(Icons.logout_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
        ),
      ],
    );
  }
}

