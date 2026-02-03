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
    // Initialize app lifecycle service for biometric re-authentication
    AppLifecycleService.instance.initialize();
  }

  @override
  void dispose() {
    // Clean up lifecycle service
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
    );
  }
}

