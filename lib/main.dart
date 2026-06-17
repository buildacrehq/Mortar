import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buildacre_crm/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lvbjwlbzgerrnbdxugil.supabase.co',
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
