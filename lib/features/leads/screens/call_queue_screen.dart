import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/stage_badge.dart';
import 'package:buildacre_crm/features/calls/screens/log_outcome_sheet.dart';

enum _QueueSection { overdue, today, uncalled }

class CallQueueScreen extends ConsumerWidget {
  const CallQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final allLeads = ref.watch(leadsProvider);
    final role = ref.watch(currentUserRoleProvider);

    // Telecallers see only their leads; managers/admins see everyone
    final myLeads = role == UserRole.telecaller
        ? allLeads.where((l) => l.assignedTo == user?.id).toList()
        : allLeads;

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayStart = DateTime(now.year, now.month, now.day);

    // Overdue: followup was in the past
    final overdue = myLeads
        .where((l) =>
            l.followupAt != null &&
            l.followupAt!.isBefore(todayStart) &&
            l.stage != LeadStage.lost &&
            l.stage != LeadStage.finalAgreement)
        .toList()
      ..sort((a, b) => a.followupAt!.compareTo(b.followupAt!));

    // Due today: followup is today
    final dueToday = myLeads
        .where((l) =>
            l.followupAt != null &&
            !l.followupAt!.isBefore(todayStart) &&
            l.followupAt!.isBefore(todayEnd) &&
            l.stage != LeadStage.lost &&
            l.stage != LeadStage.finalAgreement)
        .toList()
      ..sort((a, b) => a.followupAt!.compareTo(b.followupAt!));

    // Uncalled: no calls yet and not lost/won
    final uncalled = myLeads
        .where((l) =>
            l.callLogs.isEmpty &&
            l.stage != LeadStage.lost &&
            l.stage != LeadStage.finalAgreement)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final totalPending = overdue.length + dueToday.length + uncalled.length;
    final isManager = role == UserRole.manager || role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Queue"),
        actions: [
          if (!isManager)
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: 'My Performance',
              onPressed: () => context.push('/my-performance'),
            ),
          if (totalPending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalPending pending',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: totalPending == 0
          ? _buildAllDone(context)
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _buildProgress(context, overdue.length, dueToday.length, uncalled.length),
                if (overdue.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Overdue',
                    count: overdue.length,
                    color: Colors.red,
                    icon: Icons.warning_amber_rounded,
                  ),
                  ...overdue.map((l) => _QueueCard(
                        lead: l,
                        section: _QueueSection.overdue,
                      )),
                ],
                if (dueToday.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Due Today',
                    count: dueToday.length,
                    color: AppColors.gold,
                    icon: Icons.today,
                  ),
                  ...dueToday.map((l) => _QueueCard(
                        lead: l,
                        section: _QueueSection.today,
                      )),
                ],
                if (uncalled.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Fresh Leads (No Call Yet)',
                    count: uncalled.length,
                    color: AppColors.stageCalled,
                    icon: Icons.fiber_new_outlined,
                  ),
                  ...uncalled.map((l) => _QueueCard(
                        lead: l,
                        section: _QueueSection.uncalled,
                      )),
                ],
              ],
            ),
    );
  }

  Widget _buildProgress(
      BuildContext context, int overdue, int today, int uncalled) {
    final total = overdue + today + uncalled;
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProgressStat(label: 'Overdue', value: '$overdue', color: Colors.redAccent),
              const SizedBox(width: 24),
              _ProgressStat(label: 'Due Today', value: '$today', color: AppColors.gold),
              const SizedBox(width: 24),
              _ProgressStat(label: 'Fresh', value: '$uncalled', color: AppColors.stageCalled),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (overdue > 0)
                  Expanded(
                    flex: overdue,
                    child: Container(height: 6, color: Colors.redAccent),
                  ),
                if (today > 0)
                  Expanded(
                    flex: today,
                    child: Container(height: 6, color: AppColors.gold),
                  ),
                if (uncalled > 0)
                  Expanded(
                    flex: uncalled,
                    child: Container(height: 6, color: AppColors.stageCalled),
                  ),
                if (total == 0)
                  Expanded(child: Container(height: 6, color: AppColors.stageWon)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDone(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: AppColors.stageWon),
          const SizedBox(height: 16),
          Text(
            "All clear!",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.stageWon),
          ),
          const SizedBox(height: 8),
          const Text(
            'No pending calls for today.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ProgressStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends ConsumerWidget {
  final Lead lead;
  final _QueueSection section;
  const _QueueCard({required this.lead, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    String subtitle;
    Color subtitleColor;

    if (section == _QueueSection.overdue && lead.followupAt != null) {
      final diff = now.difference(lead.followupAt!);
      final days = diff.inDays;
      subtitle = days > 0 ? '$days day${days > 1 ? 's' : ''} overdue' : 'Due today (missed)';
      subtitleColor = Colors.red;
    } else if (section == _QueueSection.today && lead.followupAt != null) {
      subtitle = 'Due at ${DateFormat('h:mm a').format(lead.followupAt!)}';
      subtitleColor = AppColors.gold;
    } else {
      final diff = now.difference(lead.createdAt);
      final hours = diff.inHours;
      final days = diff.inDays;
      subtitle = days > 0
          ? 'Added $days day${days > 1 ? 's' : ''} ago — no call yet'
          : 'Added ${hours}h ago — no call yet';
      subtitleColor = AppColors.stageCalled;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: _sectionColor(section).withValues(alpha: 0.1),
                child: Text(
                  lead.name[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _sectionColor(section)),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _MiniChip(label: lead.serviceType.label),
                        _MiniChip(label: lead.city.label),
                        if (lead.area != null) _MiniChip(label: lead.area!),
                      ],
                    ),
                    if (lead.lastOutcome != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.history, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Last: ${lead.lastOutcome!.label}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StageBadge(stage: lead.stage, compact: true),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionBtn(
                        icon: Icons.info_outline,
                        color: AppColors.navy,
                        onTap: () => context.push('/leads/${lead.id}'),
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: Icons.call,
                        color: AppColors.gold,
                        onTap: () => _logCall(context, ref, lead),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _sectionColor(_QueueSection s) {
    switch (s) {
      case _QueueSection.overdue: return Colors.red;
      case _QueueSection.today:   return AppColors.gold;
      case _QueueSection.uncalled: return AppColors.stageCalled;
    }
  }

  void _logCall(BuildContext context, WidgetRef ref, Lead lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogOutcomeSheet(leadId: lead.id),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    );
  }
}
