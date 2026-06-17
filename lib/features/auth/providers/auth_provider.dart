import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}

// Mock users — replace with real Supabase auth later
const _mockUsers = [
  AppUser(
    id: 'tc_1',
    name: 'Ravi Kumar',
    email: 'ravi@buildacre.in',
    role: UserRole.telecaller,
  ),
  AppUser(
    id: 'mgr_1',
    name: 'Harsha',
    email: 'harsha@buildacre.in',
    role: UserRole.manager,
  ),
  AppUser(
    id: 'adm_1',
    name: 'Admin',
    email: 'admin@buildacre.in',
    role: UserRole.admin,
  ),
];

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  // Returns true if login succeeded
  bool login(String email, String password) {
    // TODO: replace with real Supabase auth
    final user = _mockUsers.where((u) => u.email == email).firstOrNull;
    if (user != null && password.length >= 6) {
      state = user;
      return true;
    }
    // Default: any valid-looking login gets manager role for testing
    if (password.length >= 6) {
      state = _mockUsers[1]; // default to manager
      return true;
    }
    return false;
  }

  void logout() => state = null;
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
  (ref) => AuthNotifier(),
);

final currentUserRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(authProvider)?.role ?? UserRole.telecaller;
});
