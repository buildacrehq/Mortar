import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/main.dart';

/// True while the initial auth check + profile load is in progress.
/// Prevents login screen flash when user is already logged in.
final authLoadingProvider = StateProvider<bool>((ref) => true);

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
  AuthNotifier(this._ref) : super(null) {
    _init();
  }

  final Ref _ref;

  void _init() {
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        _loadProfile(session.user.id);
      } else {
        // No session — mark loading done so login screen shows immediately
        _ref.read(authLoadingProvider.notifier).state = false;
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
    } finally {
      // Always mark loading done after profile attempt
      if (mounted) _ref.read(authLoadingProvider.notifier).state = false;
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
  (ref) => AuthNotifier(ref),
);

final currentUserRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(authProvider)?.role ?? UserRole.telecaller;
});
