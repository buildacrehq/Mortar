import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';

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
