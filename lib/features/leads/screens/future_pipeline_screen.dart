import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/source_icon.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

class FuturePipelineScreen extends ConsumerStatefulWidget {
  const FuturePipelineScreen({super.key});

  @override
  ConsumerState<FuturePipelineScreen> createState() =>
      _FuturePipelineScreenState();
}

class _FuturePipelineScreenState extends ConsumerState<FuturePipelineScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = [null, FutureTag.hot, FutureTag.warm, FutureTag.cool, FutureTag.longTerm];
  static const _tabLabels = ['All', 'Hot', 'Warm', 'Cool', 'Long Term'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsProvider);
    final tcMap = {for (final t in ref.watch(profilesProvider)) t.id: t};

    final futureLeads = leads
        .where((l) => l.futureTag != null)
        .toList()
      ..sort((a, b) => (a.followupAt ?? DateTime(2100))
          .compareTo(b.followupAt ?? DateTime(2100)));

    final counts = {
      for (final tag in FutureTag.values)
        tag: futureLeads.where((l) => l.futureTag == tag).length,
    };

    // Budget pipeline value
    final totalBudget = futureLeads
        .where((l) => l.budget != null)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Future Pipeline'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: List.generate(_tabs.length, (i) {
            final tag = _tabs[i];
            final count = tag == null
                ? futureLeads.length
                : (counts[tag] ?? 0);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tag != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _tagColor(tag),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(_tabLabels[i]),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
      body: Column(
        children: [
          _buildSummaryBar(futureLeads, counts, totalBudget),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tag) {
                final filtered = tag == null
                    ? futureLeads
                    : futureLeads.where((l) => l.futureTag == tag).toList();
                if (filtered.isEmpty) {
                  return _buildEmpty(tag);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _FutureCard(
                    lead: filtered[i],
                    tc: tcMap[filtered[i].assignedTo],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(
      List<Lead> all, Map<FutureTag, int> counts, int withBudget) {
    final dueIn7 = all.where((l) {
      if (l.followupAt == null) return false;
      final diff = l.followupAt!.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 7;
    }).length;
    final dueIn30 = all.where((l) {
      if (l.followupAt == null) return false;
      final diff = l.followupAt!.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 30;
    }).length;

    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.thermostat,
            label: 'Due in 7d',
            value: '$dueIn7',
            color: Colors.redAccent,
          ),
          const SizedBox(width: 20),
          _SummaryChip(
            icon: Icons.calendar_month_outlined,
            label: 'Due in 30d',
            value: '$dueIn30',
            color: AppColors.gold,
          ),
          const SizedBox(width: 20),
          _SummaryChip(
            icon: Icons.people_outline,
            label: 'Total Nurture',
            value: '${all.length}',
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(FutureTag? tag) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            tag == null
                ? 'No future leads yet'
                : 'No ${tag.label} leads in the pipeline',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          const Text(
            'When a lead says "call later", tag them here',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _tagColor(FutureTag tag) {
    switch (tag) {
      case FutureTag.hot:      return Colors.redAccent;
      case FutureTag.warm:     return AppColors.gold;
      case FutureTag.cool:     return const Color(0xFF60A5FA);
      case FutureTag.longTerm: return AppColors.textSecondary;
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _FutureCard extends ConsumerWidget {
  final Lead lead;
  final TeamMember? tc;
  const _FutureCard({required this.lead, required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = lead.futureTag!;
    final daysUntil = lead.followupAt != null
        ? lead.followupAt!.difference(DateTime.now()).inDays
        : null;
    final isOverdue = daysUntil != null && daysUntil < 0;
    final tagColor = _tagColor(tag);

    return GestureDetector(
      onTap: () => context.push('/leads/${lead.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue
                ? Colors.redAccent.withValues(alpha: 0.5)
                : tagColor.withValues(alpha: 0.3),
            width: isOverdue ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // Tag color bar + info
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tagColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tag.label,
                          style: TextStyle(
                              color: tagColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tag.description,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  if (daysUntil != null)
                    _DaysChip(days: daysUntil, isOverdue: isOverdue),
                ],
              ),
            ),
            // Lead info
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SourceIcon(source: lead.source),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lead.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(
                              '${lead.serviceType.label} · ${lead.city.label}'
                              '${lead.area != null ? ' · ${lead.area}' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (lead.budget != null)
                        Text(
                          lead.budget!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  if (lead.notes != null && lead.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_outlined,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            lead.notes!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (tc != null) ...[
                        const Icon(Icons.person_outline,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          tc!.name.split(' ').first,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.call_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${lead.callLogs.length} call${lead.callLogs.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      // Activate button
                      GestureDetector(
                        onTap: () => _activate(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Activate',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _activate(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Activate Lead?'),
        content: Text(
          'Move ${lead.name} back to the active pipeline (Enquiry stage)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref
                  .read(leadsProvider.notifier)
                  .updateStage(lead.id, LeadStage.enquiryReceived);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${lead.name} moved to active pipeline'),
                  backgroundColor: AppColors.stageWon,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  Color _tagColor(FutureTag tag) {
    switch (tag) {
      case FutureTag.hot:      return Colors.redAccent;
      case FutureTag.warm:     return AppColors.gold;
      case FutureTag.cool:     return const Color(0xFF60A5FA);
      case FutureTag.longTerm: return AppColors.textSecondary;
    }
  }
}

class _DaysChip extends StatelessWidget {
  final int days;
  final bool isOverdue;
  const _DaysChip({required this.days, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    final label = isOverdue
        ? '${(-days)}d overdue'
        : days == 0
            ? 'Today!'
            : 'in $days d';
    final color = isOverdue
        ? Colors.redAccent
        : days <= 7
            ? AppColors.gold
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
