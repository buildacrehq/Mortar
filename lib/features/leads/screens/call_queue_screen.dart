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
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';
import 'package:buildacre_crm/features/calls/screens/log_outcome_sheet.dart';

enum _QueueSection { overdue, today, uncalled }

class CallQueueScreen extends ConsumerStatefulWidget {
  const CallQueueScreen({super.key});

  @override
  ConsumerState<CallQueueScreen> createState() => _CallQueueScreenState();
}

class _CallQueueScreenState extends ConsumerState<CallQueueScreen> {
  String? _selectedTcId; // null = all TCs (manager only)

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final allLeads = ref.watch(leadsProvider);
    final role = ref.watch(currentUserRoleProvider);
    final telecallers = ref.watch(telecallersProvider);
    final isManager = role == UserRole.manager || role == UserRole.admin;

    // Telecallers see only their leads; managers/admins see everyone (with optional filter)
    final myLeads = role == UserRole.telecaller
        ? allLeads.where((l) => l.assignedTo == user?.id).toList()
        : _selectedTcId != null
            ? allLeads.where((l) => l.assignedTo == _selectedTcId).toList()
            : allLeads.toList();

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

    // Today's call stats for TC
    final todayLogs = myLeads
        .expand((l) => l.callLogs)
        .where((c) => c.calledAt.isAfter(todayStart))
        .toList();
    final callsToday = todayLogs.length;
    final talkSecsToday = todayLogs.fold<int>(0, (sum, c) => sum + c.durationSeconds);
    final talkMinsToday = talkSecsToday ~/ 60;

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
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => ref.read(leadsProvider.notifier).refresh(),
        child: totalPending == 0
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [_buildAllDone(context)],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (!isManager)
                  _buildTodayStats(context, callsToday, talkMinsToday, myLeads.length),
                if (isManager && telecallers.isNotEmpty)
                  _buildTcFilter(context, telecallers),
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
      ),
    );
  }

  Widget _buildTcFilter(BuildContext context, List<TeamMember> telecallers) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _TcChip(
              label: 'All',
              selected: _selectedTcId == null,
              onTap: () => setState(() => _selectedTcId = null),
            ),
            const SizedBox(width: 8),
            ...telecallers.map((tc) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _TcChip(
                    label: tc.firstName,
                    selected: _selectedTcId == tc.id,
                    onTap: () => setState(
                        () => _selectedTcId =
                            _selectedTcId == tc.id ? null : tc.id),
                    isActive: tc.isActive,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(
      BuildContext context, int calls, int talkMins, int totalLeads) {
    final target = 25; // weekly target / 5 days
    final pct = (calls / target).clamp(0.0, 1.0);
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TODAY',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatPill(
                      icon: Icons.call_outlined,
                      value: '$calls',
                      label: 'calls',
                      color: calls >= 5 ? AppColors.stageWon : AppColors.gold,
                    ),
                    const SizedBox(width: 12),
                    _StatPill(
                      icon: Icons.timer_outlined,
                      value: '${talkMins}m',
                      label: 'talk time',
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    _StatPill(
                      icon: Icons.people_outline,
                      value: '$totalLeads',
                      label: 'assigned',
                      color: Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(
                              pct >= 1.0 ? AppColors.stageWon : AppColors.gold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$calls/$target daily target',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (calls >= 5)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.stageWon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: AppColors.stageWon, size: 20),
                  Text(
                    calls >= target ? 'Target!' : 'Good!',
                    style: const TextStyle(
                        color: AppColors.stageWon,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
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

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

class _TcChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isActive;
  const _TcChip({required this.label, required this.selected, required this.onTap, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.navy : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isActive)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                ),
              ),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
