import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';
import 'package:buildacre_crm/features/settings/providers/team_settings_provider.dart';
import 'package:buildacre_crm/main.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final role = ref.watch(currentUserRoleProvider);
    final isManager = role == UserRole.manager || role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(context, user?.name ?? 'User', user?.email ?? '', role),
          const SizedBox(height: 16),
          if (!isManager) ...[
            _buildSection(context, 'My Stats', [
              _SettingsTile(
                icon: Icons.bar_chart_outlined,
                label: 'My Performance',
                subtitle: 'Calls, score, outcomes, recent logs',
                onTap: () => context.push('/my-performance'),
              ),
            ]),
            const SizedBox(height: 16),
          ],
          _buildSection(context, 'Account', [
            _SettingsTile(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeThumbColor: AppColors.navy,
              ),
              onTap: null,
            ),
          ]),
          if (isManager) ...[
            const SizedBox(height: 16),
            _buildAssignmentSection(context, ref),
            const SizedBox(height: 16),
            _buildTeamSection(context, ref),
            const SizedBox(height: 16),
            _buildSection(context, 'CRM', [
              _SettingsTile(
                icon: Icons.assignment_outlined,
                label: 'Pipeline Stages',
                subtitle: '7 stages configured',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.people_outline,
                label: 'Telecallers',
                subtitle: '10 active',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.chat_outlined,
                label: 'WhatsApp Templates',
                subtitle: '6 templates',
                onTap: () {},
              ),
            ]),
          ],
          if (isManager) ...[
            const SizedBox(height: 16),
            _buildSection(context, 'Integrations', [
              _SettingsTile(
                icon: Icons.phone_outlined,
                label: 'Exotel',
                subtitle: 'Virtual number · IVR · Recording',
                trailing: _StatusDot(connected: false),
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.facebook,
                label: 'Meta Ads API',
                subtitle: 'Facebook · Instagram leads',
                trailing: _StatusDot(connected: false),
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.storage_outlined,
                label: 'Supabase',
                subtitle: 'PostgreSQL database',
                trailing: _StatusDot(connected: false),
                onTap: () {},
              ),
            ]),
          ],
          const SizedBox(height: 16),
          _buildSection(context, 'About', [
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'Version',
              subtitle: '1.0.0 — Phase 1 MVP',
              onTap: null,
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, String name, String email, UserRole role) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final roleLabel = role == UserRole.admin ? 'Admin' : role == UserRole.manager ? 'Manager' : 'Telecaller';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.gold,
            child: Text(
              initial,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentSection(BuildContext context, WidgetRef ref) {
    final current = ref.watch(teamSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('LEAD ASSIGNMENT',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shuffle_outlined, size: 18, color: AppColors.navy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assignment Strategy',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('How new leads are distributed to telecallers',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AssignmentStrategy.values.map((s) {
                  final isSelected = current == s;
                  return GestureDetector(
                    onTap: () => ref
                        .read(teamSettingsProvider.notifier)
                        .setStrategy(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.navy : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.navy : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(s.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          )),
                    ),
                  );
                }).toList(),
              ),
              if (current != AssignmentStrategy.manual) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(current.description,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSection(BuildContext context, WidgetRef ref) {
    final members = ref.watch(telecallersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('TEAM AVAILABILITY',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: members.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No telecallers found.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : Column(
                  children: members.indexed.map((entry) {
                    final i = entry.$1;
                    final tc = entry.$2;
                    return Column(
                      children: [
                        if (i > 0)
                          const Divider(height: 1, indent: 60),
                        _TcAvailabilityTile(tc: tc),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: tiles.indexed.map((entry) {
              final i = entry.$1;
              final tile = entry.$2;
              return Column(
                children: [
                  tile,
                  if (i < tiles.length - 1)
                    const Divider(height: 1, indent: 48),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.navy),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: trailing ?? (onTap != null
          ? const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary)
          : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool connected;

  const _StatusDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? AppColors.stageWon : AppColors.stageLost,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          connected ? 'Live' : 'Setup',
          style: TextStyle(
            fontSize: 11,
            color: connected ? AppColors.stageWon : AppColors.stageLost,
          ),
        ),
      ],
    );
  }
}

class _TcAvailabilityTile extends ConsumerWidget {
  final TeamMember tc;
  const _TcAvailabilityTile({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: tc.isActive
                ? AppColors.navy.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.15),
            child: Text(tc.initials,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tc.isActive
                        ? AppColors.navy
                        : AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tc.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: tc.isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary)),
                if (tc.city != null && tc.city!.isNotEmpty)
                  Text(tc.city!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                // Service type chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ServiceType.values.map((s) {
                    final isSelected = tc.serviceTypes.contains(s);
                    return GestureDetector(
                      onTap: () {
                        final updated = isSelected
                            ? tc.serviceTypes.where((t) => t != s).toList()
                            : [...tc.serviceTypes, s];
                        ref
                            .read(profilesProvider.notifier)
                            .updateServiceTypes(tc.id, updated);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(s.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? AppColors.gold
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          _AbsentMenu(tc: tc),
        ],
      ),
    );
  }
}

class _AbsentMenu extends ConsumerWidget {
  final TeamMember tc;
  const _AbsentMenu({required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tc.isActive) {
      return TextButton(
        onPressed: () => _showAbsentSheet(context, ref),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: Colors.orangeAccent,
        ),
        child: const Text('Mark Absent', style: TextStyle(fontSize: 12)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('Absent',
              style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _setActive(ref),
          child: const Icon(Icons.check_circle_outline, color: AppColors.stageWon, size: 20),
        ),
      ],
    );
  }

  void _setActive(WidgetRef ref) async {
    try {
      await supabase.from('profiles').update({'is_active': true}).eq('id', tc.id);
      ref.read(profilesProvider.notifier).refresh();
    } catch (_) {}
  }

  void _showAbsentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Mark ${tc.firstName} as Absent',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Choose what happens to their leads:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            _AbsentOption(
              icon: Icons.pause_circle_outline,
              title: 'Pause — Back today / tomorrow',
              subtitle: 'New leads skip them. Existing leads stay with them.',
              color: Colors.orangeAccent,
              onTap: () async {
                Navigator.pop(context);
                await _markAbsent(ref);
              },
            ),
            const SizedBox(height: 12),
            _AbsentOption(
              icon: Icons.swap_horiz,
              title: 'Redistribute — On leave this week',
              subtitle: 'New leads skip them. Pending leads move to active TCs.',
              color: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context);
                await _markAbsent(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${tc.firstName} on leave. Backend will redistribute leads.'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _markAbsent(WidgetRef ref) async {
    try {
      await supabase.from('profiles').update({'is_active': false}).eq('id', tc.id);
      ref.read(profilesProvider.notifier).refresh();
    } catch (_) {}
  }
}

class _AbsentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _AbsentOption({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
