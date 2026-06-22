import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:buildacre_crm/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (silently skips if google-services.json not added yet)
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase not configured yet — FCM notifications disabled until setup
  }

  await Supabase.initialize(
    url: 'https://lvbjwlbzgerrnbdxugil.supabase.co',
    publishableKey: 'sb_publishable_HpJ671wFG1aD3mAfybdaFw_K6eC8vN4',
  );

  runApp(
    const ProviderScope(
      child: BuildacreCrmApp(),
    ),
  );
}

// Global Supabase client shortcut
final supabase = Supabase.instance.client;
