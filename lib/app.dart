import 'package:flutter/material.dart';
import 'package:buildacre_crm/core/router/app_router.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';

class BuildacreCrmApp extends StatelessWidget {
  const BuildacreCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Buildacre CRM',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
