import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buildacre_crm/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase.initializeApp() — add back when google-services.json is ready
  // See: lib/core/services/fcm_service.dart

  await Supabase.initialize(
    url: 'https://lvbjwlbzgerrnbdxugil.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'sb_publishable_HpJ671wFG1aD3mAfybdaFw_K6eC8vN4',
  );

  runApp(
    const ProviderScope(
      child: BuildacreCrmApp(),
    ),
  );
}

// Global Supabase client shortcut
final supabase = Supabase.instance.client;
