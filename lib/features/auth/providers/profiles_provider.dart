import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/main.dart';

enum CallingType { exotel, personal }

class TeamMember {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? city;
  final String? phone;
  final bool isActive;
  final List<ServiceType> serviceTypes;
  final CallingType callingType;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.city,
    this.phone,
    this.isActive = true,
    this.serviceTypes = const [],
    this.callingType = CallingType.exotel,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String get firstName => name.split(' ').first;

  bool get isTelecaller => role == UserRole.telecaller;
  bool get isManager => role == UserRole.manager || role == UserRole.admin;
}

TeamMember _fromMap(Map<String, dynamic> m) {
  final roleStr = m['role'] as String? ?? 'telecaller';
  final role = switch (roleStr) {
    'admin'   => UserRole.admin,
    'manager' => UserRole.manager,
    _         => UserRole.telecaller,
  };
  final rawServices = m['service_types'] as List<dynamic>? ?? [];
  final serviceTypes = rawServices
      .map((s) => ServiceType.values.firstWhere(
            (e) => e.name == s.toString(),
            orElse: () => ServiceType.construction,
          ))
      .toList();
  return TeamMember(
    id: m['id'] as String,
    name: m['name'] as String,
    email: m['email'] as String,
    role: role,
    city: m['city'] as String?,
    phone: m['phone'] as String?,
    isActive: m['is_active'] as bool? ?? true,
    serviceTypes: serviceTypes,
    callingType: (m['calling_type'] as String?) == 'personal'
        ? CallingType.personal
        : CallingType.exotel,
  );
}

class ProfilesNotifier extends StateNotifier<List<TeamMember>> {
  ProfilesNotifier() : super([]) {
    _load();
    _subscribeRealtime();
  }

  Future<void> _load() async {
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .order('name');
      if (mounted) {
        state = (data as List)
            .map((m) => _fromMap(m as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  void _subscribeRealtime() {
    supabase
        .channel('profiles_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> refresh() => _load();

  Future<void> updateCallingType(String id, CallingType type) async {
    try {
      await supabase.from('profiles')
          .update({'calling_type': type.name}).eq('id', id);
      await _load();
    } catch (_) {}
  }

  Future<void> updateServiceTypes(String id, List<ServiceType> types) async {
    try {
      await supabase.from('profiles').update({
        'service_types': types.map((t) => t.name).toList(),
      }).eq('id', id);
      await _load();
    } catch (_) {}
  }
}

final profilesProvider = StateNotifierProvider<ProfilesNotifier, List<TeamMember>>(
  (ref) => ProfilesNotifier(),
);

// Only telecallers — used in assignment screen
final telecallersProvider = Provider<List<TeamMember>>((ref) {
  return ref.watch(profilesProvider).where((p) => p.isTelecaller).toList();
});

// Lookup by ID
final memberByIdProvider = Provider.family<TeamMember?, String>((ref, id) {
  try {
    return ref.watch(profilesProvider).firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
});
