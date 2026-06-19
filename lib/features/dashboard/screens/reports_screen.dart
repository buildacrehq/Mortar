import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';
import 'package:buildacre_crm/features/dashboard/providers/analytics_provider.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

enum _Period { week, month, allTime }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    // Use analytics provider — sees ALL leads regardless of pagination
    final analytics = ref.watch(analyticsProvider);
    final leads = analytics.leads;
    final allCallLogs = analytics.callLogs;
    final now = DateTime.now();

    DateTime? since;
    String periodLabel;
    switch (_period) {
      case _Period.week:
        since = now.subtract(const Duration(days: 7));
        periodLabel = 'Last 7 Days';
      case _Period.month:
        since = now.subtract(const Duration(days: 30));
        periodLabel = 'Last 30 Days';
      case _Period.allTime:
        since = null;
        periodLabel = 'All Time';
    }

    final filtered = since == null
        ? leads
        : leads.where((l) => l.createdAt.isAfter(since!)).toList();

    final periodLogs = since == null
        ? allCallLogs
        : allCallLogs.where((c) => c.calledAt.isAfter(since!)).toList();

    // Metrics
    final newLeads = filtered.length;
    final wonLeads = filtered.where((l) => l.stage == LeadStage.finalAgreement).length;
    final lostLeads = filtered.where((l) => l.stage == LeadStage.lost).length;
    final totalCalls = periodLogs.length;
    final convRate = newLeads == 0 ? 0.0 : wonLeads / newLeads * 100;
    final lossRate = newLeads == 0 ? 0.0 : lostLeads / newLeads * 100;
    final avgDuration = periodLogs.isEmpty
        ? 0
        : periodLogs.fold(0, (s, l) => s + l.durationSeconds) ~/
            periodLogs.length;

    // Best source
    final sourceCount = <LeadSource, int>{};
    for (final l in filtered) {
      sourceCount[l.source] = (sourceCount[l.source] ?? 0) + 1;
    }
    final bestSource = sourceCount.entries.isEmpty
        ? null
        : sourceCount.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Best telecaller by calls in period
    final tcCallCount = <String, int>{};
    for (final log in periodLogs) {
      // calledBy = TC's profile ID stored on the call log
      if (log.calledBy.isNotEmpty) {
        tcCallCount[log.calledBy] = (tcCallCount[log.calledBy] ?? 0) + 1;
      }
    }
    final tcMap = {for (final t in ref.watch(profilesProvider)) t.id: t};
    final bestTcEntry = tcCallCount.entries.isEmpty
        ? null
        : tcCallCount.entries.reduce((a, b) => a.value > b.value ? a : b);
    final bestTc = bestTcEntry == null ? null : tcMap[bestTcEntry.key];

    // Stage funnel for period
    final byStage = <LeadStage, int>{};
    for (final s in LeadStage.values) {
      byStage[s] = filtered.where((l) => l.stage == s).length;
    }

    // Daily lead trend (last 7 days always shown)
    final trend = List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      return leads
          .where((l) =>
              l.createdAt.year == day.year &&
              l.createdAt.month == day.month &&
              l.createdAt.day == day.day)
          .length;
    });
    final trendMax = trend.fold(0, (a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => ref.read(analyticsProvider.notifier).refresh(),
        child: ListView(
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          _buildPeriodSelector(),
          _buildKpiRow(context, newLeads, totalCalls, convRate, lossRate, periodLabel),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildAvgDuration(context, avgDuration, totalCalls),
                const SizedBox(height: 12),
                _buildTrend(context, trend, trendMax, now),
                const SizedBox(height: 12),
                _buildFunnel(context, byStage, newLeads),
                const SizedBox(height: 12),
                _buildHighlights(context, bestSource, bestTc, bestTcEntry?.value),
                const SizedBox(height: 12),
                _buildSourceTable(context, sourceCount, newLeads),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: _Period.values.map((p) {
          final label = switch (p) {
            _Period.week    => '7 Days',
            _Period.month   => '30 Days',
            _Period.allTime => 'All Time',
          };
          final isSelected = p == _period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.white60,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiRow(BuildContext context, int newLeads, int calls,
      double conv, double loss, String period) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _KpiCard(label: 'New Leads', value: '$newLeads', icon: Icons.person_add_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              _KpiCard(label: 'Calls Made', value: '$calls', icon: Icons.call_outlined, color: AppColors.stageCalled),
              const SizedBox(width: 10),
              _KpiCard(label: 'Won', value: '${conv.toStringAsFixed(1)}%', icon: Icons.emoji_events_outlined, color: AppColors.stageWon),
              const SizedBox(width: 10),
              _KpiCard(label: 'Lost', value: '${loss.toStringAsFixed(1)}%', icon: Icons.do_not_disturb_outlined, color: AppColors.stageLost),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvgDuration(BuildContext context, int avgSeconds, int calls) {
    final m = avgSeconds ~/ 60;
    final s = avgSeconds % 60;
    return _Card(
      title: 'Call Quality',
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Avg Duration',
              value: calls == 0 ? '—' : '${m}m ${s}s',
              icon: Icons.timer_outlined,
              color: avgSeconds >= 300 ? AppColors.stageWon : AppColors.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Target',
              value: '5m 00s',
              icon: Icons.flag_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Status',
              value: calls == 0
                  ? 'No calls'
                  : avgSeconds >= 300
                      ? '✓ On track'
                      : '↓ Below',
              icon: avgSeconds >= 300
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
              color: avgSeconds >= 300 ? AppColors.stageWon : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrend(
      BuildContext context, List<int> trend, int max, DateTime now) {
    return _Card(
      title: 'Lead Volume — Last 7 Days',
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = trend[i];
                final pct = max == 0 ? 0.0 : count / max;
                final isToday = i == 6;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text('$count',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isToday
                                      ? AppColors.gold
                                      : AppColors.navy)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 60 * pct + (count > 0 ? 4 : 2),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.gold
                                : AppColors.navy.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(7, (i) {
              final day = DateTime(now.year, now.month, now.day)
                  .subtract(Duration(days: 6 - i));
              return Expanded(
                child: Text(
                  DateFormat('E').format(day)[0],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: i == 6 ? AppColors.gold : AppColors.textSecondary,
                    fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnel(
      BuildContext context, Map<LeadStage, int> byStage, int total) {
    const stages = [
      LeadStage.enquiryReceived,
      LeadStage.telecallerCallDone,
      LeadStage.meetingAtOffice,
      LeadStage.siteVisit,
      LeadStage.quotationSent,
      LeadStage.negotiation,
      LeadStage.finalAgreement,
    ];
    final stageColors = [
      AppColors.stageEnquiry,
      AppColors.stageCalled,
      AppColors.stageMeeting,
      AppColors.stageSiteVisit,
      AppColors.stageQuotation,
      AppColors.stageNegotiation,
      AppColors.stageWon,
    ];

    return _Card(
      title: 'Pipeline Funnel',
      child: Column(
        children: List.generate(stages.length, (i) {
          final s = stages[i];
          final count = byStage[s] ?? 0;
          final pct = total == 0 ? 0.0 : count / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(s.label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation(stageColors[i]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: stageColors[i]),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHighlights(BuildContext context, MapEntry<LeadSource, int>? src,
      TeamMember? tc, int? tcCalls) {
    return Row(
      children: [
        Expanded(
          child: _HighlightCard(
            title: 'Top Source',
            icon: Icons.ads_click,
            color: const Color(0xFF1877F2),
            value: src?.key.label ?? '—',
            subtitle: src != null ? '${src.value} leads' : 'No data',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HighlightCard(
            title: 'Most Active Rep',
            icon: Icons.phone_in_talk_outlined,
            color: AppColors.stageWon,
            value: tc?.name.split(' ').first ?? '—',
            subtitle: tcCalls != null ? '$tcCalls calls' : 'No data',
          ),
        ),
      ],
    );
  }

  Widget _buildSourceTable(BuildContext context,
      Map<LeadSource, int> sourceCount, int total) {
    final sorted = sourceCount.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) return const SizedBox.shrink();

    return _Card(
      title: 'Leads by Source',
      child: Column(
        children: sorted.map((e) {
          final pct = total == 0 ? 0.0 : e.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(e.key.label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: AppColors.surface,
                      valueColor:
                          AlwaysStoppedAnimation(_sourceColor(e.key)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _sourceColor(LeadSource s) {
    switch (s) {
      case LeadSource.facebook:  return const Color(0xFF1877F2);
      case LeadSource.instagram: return const Color(0xFFE1306C);
      case LeadSource.website:   return AppColors.navy;
      case LeadSource.phone:     return AppColors.stageWon;
      case LeadSource.whatsapp:  return const Color(0xFF25D366);
      case LeadSource.referral:  return AppColors.gold;
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String subtitle;
  const _HighlightCard({required this.title, required this.icon, required this.color, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
