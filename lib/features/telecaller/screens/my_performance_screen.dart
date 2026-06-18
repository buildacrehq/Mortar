import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

const _dailyTarget = 5;
const _weeklyTarget = 25;

class MyPerformanceScreen extends ConsumerWidget {
  const MyPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final leads = ref.watch(leadsProvider);

    final allMembers = ref.watch(profilesProvider);
    final profile = allMembers.firstWhere(
      (t) => t.id == user?.id,
      orElse: () => TeamMember(
          id: user?.id ?? '',
          name: user?.name ?? 'Me',
          email: user?.email ?? '',
          role: UserRole.telecaller),
    );
    final stats = computeStats(profile, leads);

    // Team rank
    final allStats = allMembers
        .map((t) => computeStats(t, leads))
        .toList()
      ..sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
    final rank =
        allStats.indexWhere((s) => s.profile.id == profile.id) + 1;

    // Recent call logs (newest first, across all assigned leads)
    final recentLogs = leads
        .where((l) => l.assignedTo == profile.id)
        .expand((l) => l.callLogs.map((c) => (lead: l, log: c)))
        .toList()
      ..sort((a, b) => b.log.calledAt.compareTo(a.log.calledAt));

    return Scaffold(
      appBar: AppBar(title: const Text('My Performance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(profile, stats, rank, allMembers.length),
          const SizedBox(height: 16),
          _buildTargets(stats),
          const SizedBox(height: 16),
          _buildScoreCard(stats),
          const SizedBox(height: 16),
          _buildOutcomeBreakdown(stats),
          const SizedBox(height: 16),
          _buildCallStats(stats),
          const SizedBox(height: 16),
          _buildRecentCalls(recentLogs.take(8).toList()),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      TeamMember profile, TelecallerStats stats, int rank, int teamSize) {
    final initial = profile.name[0].toUpperCase();
    final scoreColor = stats.performanceScore >= 7
        ? AppColors.stageWon
        : stats.performanceScore >= 4
            ? Colors.amber
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  profile.city ?? '',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _HeaderChip(
                      label: '${stats.totalLeads} leads',
                      icon: Icons.people_outline,
                    ),
                    const SizedBox(width: 8),
                    _HeaderChip(
                      label: '#$rank of $teamSize',
                      icon: Icons.leaderboard_outlined,
                      highlight: rank == 1,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Score circle
          Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    stats.performanceScore.toStringAsFixed(1),
                    style: TextStyle(
                        color: scoreColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Score',
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargets(TelecallerStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TARGETS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 14),
          _TargetBar(
            label: 'Today',
            current: stats.callsToday,
            target: _dailyTarget,
            color: AppColors.navy,
          ),
          const SizedBox(height: 12),
          _TargetBar(
            label: 'This Week',
            current: stats.callsThisWeek,
            target: _weeklyTarget,
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(TelecallerStats stats) {
    final scoreColor = stats.performanceScore >= 7
        ? AppColors.stageWon
        : stats.performanceScore >= 4
            ? Colors.amber
            : Colors.redAccent;
    final scoreLabel = stats.performanceScore >= 7
        ? 'Excellent'
        : stats.performanceScore >= 4
            ? 'Average'
            : 'Needs Improvement';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERFORMANCE BREAKDOWN',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ScoreRow(
                  label: 'Call Volume (35%)',
                  value: '${stats.callsThisWeek}/$_weeklyTarget this week',
                  score: (stats.callsThisWeek / _weeklyTarget).clamp(0.0, 1.0),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _ScoreRow(
            label: 'Avg Duration (25%)',
            value: stats.formattedAvgDuration,
            score:
                (stats.avgCallDurationSeconds / 600).clamp(0.0, 1.0),
          ),
          const Divider(height: 20),
          _ScoreRow(
            label: 'Conversion (25%)',
            value: stats.totalLeads > 0
                ? '${stats.wonLeads}/${stats.totalLeads} won'
                : 'No leads yet',
            score: stats.totalLeads > 0
                ? (stats.wonLeads / stats.totalLeads).clamp(0.0, 1.0)
                : 0.0,
          ),
          const Divider(height: 20),
          _ScoreRow(
            label: 'No Overdue (15%)',
            value: stats.overdueFollowups > 0
                ? '${stats.overdueFollowups} overdue'
                : 'All clear',
            score: stats.totalLeads > 0
                ? (1 - stats.overdueFollowups / stats.totalLeads)
                    .clamp(0.0, 1.0)
                : 1.0,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                stats.performanceScore.toStringAsFixed(1),
                style: TextStyle(
                    color: scoreColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800),
              ),
              Text(
                '/10',
                style: TextStyle(color: scoreColor.withValues(alpha: 0.6), fontSize: 16),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scoreLabel,
                  style: TextStyle(
                      color: scoreColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeBreakdown(TelecallerStats stats) {
    final total =
        stats.outcomeBreakdown.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final outcomes = [
      (CallOutcome.interested, AppColors.stageWon, 'Interested'),
      (CallOutcome.callback, AppColors.gold, 'Callback'),
      (CallOutcome.future, const Color(0xFF60A5FA), 'Future'),
      (CallOutcome.notReachable, AppColors.textSecondary, 'No Answer'),
      (CallOutcome.notInterested, Colors.redAccent, 'Not Interested'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CALL OUTCOMES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 14),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: outcomes.map((o) {
                final count = stats.outcomeBreakdown[o.$1] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Expanded(
                  flex: count,
                  child: Container(height: 10, color: o.$2),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: outcomes.map((o) {
              final count = stats.outcomeBreakdown[o.$1] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              final pct = (count / total * 100).round();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: o.$2, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${o.$3} $count ($pct%)',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallStats(TelecallerStats stats) {
    final avgSecs = stats.avgCallDurationSeconds;
    final targetSecs = 300; // 5 min
    final atTarget = avgSecs >= targetSecs;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CALL STATS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatBox(
                label: 'Total Talk Time',
                value: stats.formattedTotalDuration,
                icon: Icons.timer_outlined,
                color: AppColors.navy,
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'Avg Duration',
                value: stats.formattedAvgDuration,
                icon: Icons.av_timer_outlined,
                color: atTarget ? AppColors.stageWon : Colors.orangeAccent,
                subtitle: atTarget ? '✓ On target' : 'Target: 5m',
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'Deals Won',
                value: '${stats.wonLeads}',
                icon: Icons.emoji_events_outlined,
                color: AppColors.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCalls(
      List<({Lead lead, CallLog log})> logs) {
    if (logs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT CALLS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          ...logs.indexed.map((entry) {
            final i = entry.$1;
            final item = entry.$2;
            final log = item.log;
            final lead = item.lead;
            final dur = log.durationSeconds;
            final mins = dur ~/ 60;
            final secs = dur % 60;
            final isShort = log.isSuspiciouslyShort;

            final outcomeColor = switch (log.outcome) {
              CallOutcome.interested => AppColors.stageWon,
              CallOutcome.callback => AppColors.gold,
              CallOutcome.notInterested => Colors.redAccent,
              CallOutcome.notReachable => AppColors.textSecondary,
              CallOutcome.future => const Color(0xFF60A5FA),
            };

            return Column(
              children: [
                if (i > 0) const Divider(height: 16),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: outcomeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lead.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (isShort)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Short',
                            style: TextStyle(
                                fontSize: 10, color: Colors.redAccent)),
                      ),
                    Text(
                      '${mins}m ${secs}s',
                      style: TextStyle(
                          fontSize: 12,
                          color: isShort
                              ? Colors.redAccent
                              : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(log.calledAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlight;
  const _HeaderChip(
      {required this.label, required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.2)
            : Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: highlight ? AppColors.gold : Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: highlight ? AppColors.gold : Colors.white70)),
        ],
      ),
    );
  }
}

class _TargetBar extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final Color color;
  const _TargetBar(
      {required this.label,
      required this.current,
      required this.target,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (current / target).clamp(0.0, 1.0);
    final met = current >= target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text(
              '$current / $target calls',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: met ? AppColors.stageWon : AppColors.textPrimary),
            ),
            if (met) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.stageWon),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
              met ? AppColors.stageWon : color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  final double score;
  const _ScoreRow(
      {required this.label, required this.value, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.7
        ? AppColors.stageWon
        : score >= 0.4
            ? Colors.amber
            : Colors.redAccent;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 6,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
            if (subtitle != null)
              Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
