import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'services/app_lifecycle_service.dart';

class CareSync extends ConsumerStatefulWidget {
  const CareSync({super.key});

  @override
  ConsumerState<CareSync> createState() => _CareSyncState();
}

class _CareSyncState extends ConsumerState<CareSync> {
  @override
  void initState() {
    super.initState();
    AppLifecycleService.instance.initialize();
  }

  @override
  void dispose() {
    AppLifecycleService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CareSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Wrap the app to insert the Global Biometric Lock
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const _GlobalBiometricLock(),
          ],
        );
      },
    );
  }
}

/// Overlay widget that shows/hides based on stream events
class _GlobalBiometricLock extends StatefulWidget {
  const _GlobalBiometricLock();

  @override
  State<_GlobalBiometricLock> createState() => _GlobalBiometricLockState();
}

class _GlobalBiometricLockState extends State<_GlobalBiometricLock> {
  bool _isLocked = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AppLifecycleService.instance.authStatusStream.listen((locked) {
      if (mounted) {
        setState(() => _isLocked = locked);
        if (locked) _triggerAuth();
      }
    });
  }

  Future<void> _triggerAuth() async {
    // Wait for UI to render
    await Future.delayed(const Duration(milliseconds: 200));
    await AppLifecycleService.instance.authenticate();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) return const SizedBox.shrink();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Session Expired',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Please authenticate to continue'),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => AppLifecycleService.instance.authenticate(),
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}