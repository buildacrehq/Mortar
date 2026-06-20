import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';
import 'package:buildacre_crm/features/dashboard/providers/analytics_provider.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

enum _Period { thisWeek, lastWeek, thisMonth, allTime }

extension _PeriodExt on _Period {
  String get label {
    switch (this) {
      case _Period.thisWeek:  return 'This Week';
      case _Period.lastWeek:  return 'Last Week';
      case _Period.thisMonth: return 'This Month';
      case _Period.allTime:   return 'All Time';
    }
  }
}

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  _Period _period = _Period.thisWeek;

  @override
  Widget build(BuildContext context) {
    // Use analytics for accurate stats across ALL leads
    final analytics = ref.watch(analyticsProvider);
    final allLeads = analytics.leads;
    final allCallLogs = analytics.callLogs;
    final telecallers = ref.watch(telecallersProvider);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final DateTime periodStart;
    switch (_period) {
      case _Period.thisWeek:
        periodStart = todayStart.subtract(Duration(days: now.weekday - 1));
      case _Period.lastWeek:
        final thisWeekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        periodStart = thisWeekStart.subtract(const Duration(days: 7));
      case _Period.thisMonth:
        periodStart = DateTime(now.year, now.month, 1);
      case _Period.allTime:
        periodStart = DateTime(2000);
    }
    final periodEnd = _period == _Period.lastWeek
        ? todayStart.subtract(Duration(days: now.weekday - 1))
        : now;

    final stats = telecallers.map((tc) {
      final myLeads = allLeads.where((l) => l.assignedTo == tc.id).toList();
      final myLogs = allCallLogs.where((c) => c.calledBy == tc.id).toList();
      final periodLogs = myLogs
          .where((c) => c.calledAt.isAfter(periodStart) && c.calledAt.isBefore(periodEnd))
          .toList();
      final totalDuration = periodLogs.fold<int>(0, (s, c) => s + c.durationSeconds);
      final outcomes = <CallOutcome, int>{};
      for (final o in CallOutcome.values) {
        outcomes[o] = periodLogs.where((c) => c.outcome == o).length;
      }
      return TelecallerStats(
        profile: tc,
        totalLeads: myLeads.length,
        callsToday: myLogs.where((c) => c.calledAt.isAfter(todayStart)).length,
        callsThisWeek: periodLogs.length,
        totalCallDurationSeconds: totalDuration,
        outcomeBreakdown: outcomes,
        overdueFollowups: myLeads.where((l) => l.hasOverdueFollowup).length,
        wonLeads: myLeads.where((l) => l.stage == LeadStage.finalAgreement).length,
      );
    }).toList()
      ..sort((a, b) => b.performanceScore.compareTo(a.performanceScore));

    final totalCalls = stats.fold(0, (s, t) => s + t.callsThisWeek);

    return Scaffold(
      appBar: AppBar(title: const Text('Telecaller Performance')),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => ref.read(analyticsProvider.notifier).refresh(),
        child: Column(
        children: [
          // Period filter
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _Period.values.map((p) {
                  final isSelected = _period == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _period = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.gold : Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(p.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          _buildSummaryBar(context, stats.length, totalCalls, totalCalls),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: stats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TelecallerCard(stats: stats[i], rank: i + 1),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSummaryBar(BuildContext context, int count, int today, int week) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _SumStat(label: 'Telecallers', value: '$count'),
          const SizedBox(width: 24),
          _SumStat(label: 'Calls Today', value: '$today', highlight: true),
          const SizedBox(width: 24),
          _SumStat(label: 'This Week', value: '$week'),
        ],
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SumStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.gold : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _TelecallerCard extends StatefulWidget {
  final TelecallerStats stats;
  final int rank;

  const _TelecallerCard({required this.stats, required this.rank});

  @override
  State<_TelecallerCard> createState() => _TelecallerCardState();
}

class _TelecallerCardState extends State<_TelecallerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final score = s.performanceScore;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            _buildHeader(s, score),
            if (_expanded) ...[
              const Divider(height: 1),
              _buildDetails(s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TelecallerStats s, double score) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _RankBadge(rank: widget.rank),
          const SizedBox(width: 12),
          _Avatar(name: s.profile.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.profile.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 6),
                    _CityChip(city: s.profile.city),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniStat(label: 'Today', value: '${s.callsToday}'),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'Week', value: '${s.callsThisWeek}'),
                    const SizedBox(width: 12),
                    _MiniStat(label: 'Leads', value: '${s.totalLeads}'),
                  ],
                ),
                const SizedBox(height: 8),
                _ScoreBar(score: score),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _scoreColor(score),
                ),
              ),
              Text('/10', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10)),
              const SizedBox(height: 4),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(TelecallerStats s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Call Outcomes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: CallOutcome.values
                .where((o) => (s.outcomeBreakdown[o] ?? 0) > 0)
                .map((o) => _OutcomePill(outcome: o, count: s.outcomeBreakdown[o]!))
                .toList(),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DetailStat(label: 'Avg Call Duration', value: s.formattedAvgDuration)),
              Expanded(child: _DetailStat(label: 'Total Talk Time', value: s.formattedTotalDuration)),
              Expanded(child: _DetailStat(
                label: 'Overdue',
                value: '${s.overdueFollowups}',
                valueColor: s.overdueFollowups > 0 ? Colors.red : AppColors.stageWon,
              )),
            ],
          ),
          if (s.wonLeads > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.stageWon.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: AppColors.stageWon, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${s.wonLeads} deal${s.wonLeads > 1 ? 's' : ''} closed',
                    style: const TextStyle(
                      color: AppColors.stageWon,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 7) return AppColors.stageWon;
    if (score >= 4) return AppColors.gold;
    return Colors.red;
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.gold, const Color(0xFFB0BEC5), const Color(0xFFBF8970)];
    final color = rank <= 3 ? colors[rank - 1] : AppColors.surface;
    final textColor = rank <= 3 ? Colors.white : AppColors.textSecondary;

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.navy.withValues(alpha: 0.1),
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16),
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String? city;
  const _CityChip({required this.city});

  @override
  Widget build(BuildContext context) {
    if (city == null || city!.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        city!,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double score;
  const _ScoreBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 7
        ? AppColors.stageWon
        : score >= 4
            ? AppColors.gold
            : Colors.red;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: score / 10,
        minHeight: 5,
        backgroundColor: AppColors.surface,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  final CallOutcome outcome;
  final int count;
  const _OutcomePill({required this.outcome, required this.count});

  Color get _color {
    switch (outcome) {
      case CallOutcome.interested:    return AppColors.stageWon;
      case CallOutcome.notInterested: return AppColors.stageLost;
      case CallOutcome.callback:      return AppColors.stageCalled;
      case CallOutcome.notReachable:  return AppColors.textSecondary;
      case CallOutcome.future:        return AppColors.stageMeeting;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count × ${outcome.label}',
        style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
