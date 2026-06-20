import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/router/app_router.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';

class BuildacreCrmApp extends ConsumerWidget {
  const BuildacreCrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch authProvider to trigger AuthNotifier initialization
    ref.watch(authProvider);
    final isAuthLoading = ref.watch(authLoadingProvider);

    // Show navy splash while restoring session — prevents login screen flash
    if (isAuthLoading) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          backgroundColor: AppColors.navy,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Construction CRM',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                SizedBox(height: 40),
                CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
