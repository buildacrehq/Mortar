import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/stage_badge.dart';
import 'package:buildacre_crm/features/dashboard/providers/performance_provider.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';
import 'package:buildacre_crm/features/notifications/providers/notifications_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(leadsProvider);
    final overdue = ref.watch(overdueLeadsProvider);
    final todayCount = ref.watch(todayLeadsCountProvider);
    final tcStats = ref.watch(telecallerStatsProvider);

    final unreadNotifs = ref.watch(unreadCountProvider);

    final byStage = <LeadStage, int>{};
    for (final s in LeadStage.values) {
      byStage[s] = leads.where((l) => l.stage == s).length;
    }

    final bySource = <LeadSource, int>{};
    for (final s in LeadSource.values) {
      bySource[s] = leads.where((l) => l.source == s).length;
    }

    final totalCalls = leads.fold<int>(0, (sum, l) => sum + l.callLogs.length);
    final wonLeads = byStage[LeadStage.finalAgreement] ?? 0;
    final conversionRate = leads.isEmpty
        ? 0.0
        : (wonLeads / leads.length * 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadNotifs > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadNotifs > 9 ? '9+' : '$unreadNotifs',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTopStats(context, todayCount, leads.length, totalCalls, overdue.length),
          const SizedBox(height: 16),
          _buildPerformanceBanner(context, tcStats),
          const SizedBox(height: 10),
          _buildRecordingsBanner(context, totalCalls),
          const SizedBox(height: 10),
          _buildCityBanner(context, leads),
          const SizedBox(height: 10),
          _buildCalendarBanner(context, leads),
          const SizedBox(height: 10),
          _buildReportsBanner(context),
          const SizedBox(height: 10),
          _buildLostLeadsBanner(context, leads),
          const SizedBox(height: 10),
          _buildFuturePipelineBanner(context, leads),
          const SizedBox(height: 16),
          _buildPipelineSnapshot(context, byStage, leads.length),
          const SizedBox(height: 16),
          _buildConversionCard(context, conversionRate, byStage),
          const SizedBox(height: 16),
          _buildSourceBreakdown(context, bySource, leads.length),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildOverdueList(context, overdue),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildReportsBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/dashboard/reports'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.assessment_outlined, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reports',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text('7 days · 30 days · All time',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLostLeadsBanner(BuildContext context, List<Lead> leads) {
    final lostCount = leads.where((l) => l.stage == LeadStage.lost).length;
    return GestureDetector(
      onTap: () => context.push('/leads/lost'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: lostCount > 0
                ? AppColors.stageLost.withValues(alpha: 0.4)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.stageLost.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_outlined,
                  color: AppColors.stageLost, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lost Leads Recovery',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    lostCount > 0
                        ? '$lostCount leads — tap to re-engage'
                        : 'No lost leads',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (lostCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stageLost.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$lostCount',
                  style: const TextStyle(
                      color: AppColors.stageLost,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFuturePipelineBanner(BuildContext context, List<Lead> leads) {
    final futureLeads = leads.where((l) => l.futureTag != null).toList();
    final dueIn7 = futureLeads.where((l) {
      if (l.followupAt == null) return false;
      final diff = l.followupAt!.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 7;
    }).length;
    return GestureDetector(
      onTap: () => context.push('/leads/future'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: futureLeads.isNotEmpty
                ? const Color(0xFFF5A623).withValues(alpha: 0.4)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_outlined,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Future Pipeline',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    futureLeads.isEmpty
                        ? 'No future leads tagged'
                        : dueIn7 > 0
                            ? '$dueIn7 due this week · ${futureLeads.length} total'
                            : '${futureLeads.length} leads in nurture',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (dueIn7 > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$dueIn7 due',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarBanner(BuildContext context, List<Lead> leads) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayCount = leads.where((l) {
      if (l.followupAt == null) return false;
      final d = DateTime(l.followupAt!.year, l.followupAt!.month, l.followupAt!.day);
      return d == today;
    }).length;
    final weekCount = leads.where((l) {
      if (l.followupAt == null) return false;
      final d = DateTime(l.followupAt!.year, l.followupAt!.month, l.followupAt!.day);
      return d.isAfter(today) && d.isBefore(today.add(const Duration(days: 7)));
    }).length;
    return GestureDetector(
      onTap: () => context.push('/calendar'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: AppColors.navy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Follow-up Calendar',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    'Today $todayCount  ·  Next 7 days $weekCount',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCityBanner(BuildContext context, List<Lead> leads) {
    final blr = leads.where((l) => l.city == City.bangalore).length;
    final mys = leads.where((l) => l.city == City.mysore).length;
    return GestureDetector(
      onTap: () => context.push('/dashboard/city'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_city_outlined, color: AppColors.navy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('City Analytics',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    'Bangalore $blr  ·  Mysore $mys',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsBanner(BuildContext context, int totalCalls) {
    return GestureDetector(
      onTap: () => context.push('/dashboard/recordings'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.voicemail, color: AppColors.navy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Call Recordings',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    '$totalCalls calls logged · Tap to review',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceBanner(BuildContext context, List<TelecallerStats> tcStats) {
    if (tcStats.isEmpty) return const SizedBox.shrink();
    final top = tcStats.first;
    final score = top.performanceScore.toStringAsFixed(1);
    return GestureDetector(
      onTap: () => context.push('/dashboard/performance'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.leaderboard, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telecaller Performance',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    '${tcStats.length} reps · Top: ${top.profile.name} ($score/10)',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStats(BuildContext context, int today, int total, int calls, int overdue) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Today', value: '$today', icon: Icons.today, color: AppColors.gold)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Total Leads', value: '$total', icon: Icons.people_outline, color: AppColors.stageCalled)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Calls Made', value: '$calls', icon: Icons.call_outlined, color: AppColors.stageWon)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Overdue', value: '$overdue', icon: Icons.warning_amber_outlined, color: overdue > 0 ? Colors.red : AppColors.stageLost)),
      ],
    );
  }

  Widget _buildPipelineSnapshot(BuildContext context, Map<LeadStage, int> byStage, int total) {
    const activeStages = [
      LeadStage.enquiryReceived,
      LeadStage.telecallerCallDone,
      LeadStage.meetingAtOffice,
      LeadStage.siteVisit,
      LeadStage.quotationSent,
      LeadStage.negotiation,
      LeadStage.finalAgreement,
    ];

    final maxCount = activeStages
        .map((s) => byStage[s] ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    return _Card(
      title: 'Pipeline Snapshot',
      child: Column(
        children: activeStages.map((stage) {
          final count = byStage[stage] ?? 0;
          final pct = maxCount == 0 ? 0.0 : count / maxCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    stage.label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation(_stageColor(stage)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConversionCard(BuildContext context, double rate, Map<LeadStage, int> byStage) {
    final meeting = byStage[LeadStage.meetingAtOffice] ?? 0;
    final siteVisit = byStage[LeadStage.siteVisit] ?? 0;
    final won = byStage[LeadStage.finalAgreement] ?? 0;
    final total = byStage.values.fold(0, (a, b) => a + b);

    return _Card(
      title: 'Conversion Funnel',
      child: Column(
        children: [
          _FunnelRow(label: 'All Leads', count: total, total: total, color: AppColors.stageEnquiry),
          _FunnelRow(label: 'Meeting Done', count: meeting + siteVisit + won, total: total, color: AppColors.stageMeeting),
          _FunnelRow(label: 'Site Visit', count: siteVisit + won, total: total, color: AppColors.stageSiteVisit),
          _FunnelRow(label: 'Won', count: won, total: total, color: AppColors.stageWon),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Overall conversion rate  ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.stageWon),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBreakdown(BuildContext context, Map<LeadSource, int> bySource, int total) {
    final sorted = bySource.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Card(
      title: 'Lead Sources',
      child: Column(
        children: sorted.map((e) {
          final pct = total == 0 ? 0.0 : e.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    e.key.label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation(_sourceColor(e.key)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverdueList(BuildContext context, List<Lead> overdue) {
    return _Card(
      title: '🔴 Needs Attention (${overdue.length})',
      child: Column(
        children: overdue.map((lead) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.red.shade50,
                child: Text(
                  lead.name[0],
                  style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(
                      '${lead.serviceType.label} · ${lead.city.label}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StageBadge(stage: lead.stage, compact: true),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Color _stageColor(LeadStage s) {
    switch (s) {
      case LeadStage.enquiryReceived:    return AppColors.stageEnquiry;
      case LeadStage.telecallerCallDone: return AppColors.stageCalled;
      case LeadStage.meetingAtOffice:    return AppColors.stageMeeting;
      case LeadStage.siteVisit:          return AppColors.stageSiteVisit;
      case LeadStage.quotationSent:      return AppColors.stageQuotation;
      case LeadStage.negotiation:        return AppColors.stageNegotiation;
      case LeadStage.finalAgreement:     return AppColors.stageWon;
      default:                           return AppColors.stageLost;
    }
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
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

class _FunnelRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _FunnelRow({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
