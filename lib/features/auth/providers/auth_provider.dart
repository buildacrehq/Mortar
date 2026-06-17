import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/main.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? city;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.city,
  });
}

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null) {
    _init();
  }

  void _init() {
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        _loadProfile(session.user.id);
      }

      supabase.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final user = data.session?.user;
        if (event == AuthChangeEvent.signedIn && user != null) {
          _loadProfile(user.id);
        } else if (event == AuthChangeEvent.signedOut) {
          state = null;
        }
      });
    } catch (_) {
      // Silently ignore init errors (e.g. passkeys web SDK on Chrome)
    }
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final roleStr = data['role'] as String;
      final role = switch (roleStr) {
        'admin'      => UserRole.admin,
        'manager'    => UserRole.manager,
        _            => UserRole.telecaller,
      };

      state = AppUser(
        id: data['id'] as String,
        name: data['name'] as String,
        email: data['email'] as String,
        role: role,
        city: data['city'] as String?,
      );
    } catch (e) {
      state = null;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
  (ref) => AuthNotifier(),
);

final currentUserRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(authProvider)?.role ?? UserRole.telecaller;
});
