import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final location = GoRouterState.of(context).matchedLocation;

    final tabs = _tabsForRole(role);
    final currentIndex = _indexFor(location, tabs);
    final onLeads = location == '/leads';

    return Scaffold(
      body: child,
      floatingActionButton: onLeads
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/leads/add'),
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Lead',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.navy.withValues(alpha: 0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon, color: AppColors.textSecondary),
                  selectedIcon: Icon(t.selectedIcon, color: AppColors.navy),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }

  List<_TabItem> _tabsForRole(UserRole role) {
    final leads    = _TabItem('/leads',    Icons.contacts_outlined,   Icons.contacts,   'Leads');
    final queue    = _TabItem('/queue',    Icons.today_outlined,      Icons.today,      'Queue');
    final calendar = _TabItem('/calendar', Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar');
    final dashboard = _TabItem('/dashboard', Icons.bar_chart_outlined, Icons.bar_chart, 'Dashboard');
    final settings = _TabItem('/settings', Icons.settings_outlined,   Icons.settings,   'Settings');

    switch (role) {
      case UserRole.telecaller:
        return [leads, queue, calendar, settings];
      case UserRole.manager:
      case UserRole.admin:
        return [leads, queue, dashboard, settings];
    }
  }

  int _indexFor(String location, List<_TabItem> tabs) {
    for (int i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].path)) return i;
    }
    return 0;
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _TabItem(this.path, this.icon, this.selectedIcon, this.label);
}
