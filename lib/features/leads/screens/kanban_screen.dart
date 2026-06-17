import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';

const _activeStages = [
  LeadStage.enquiryReceived,
  LeadStage.telecallerCallDone,
  LeadStage.meetingAtOffice,
  LeadStage.siteVisit,
  LeadStage.quotationSent,
  LeadStage.negotiation,
  LeadStage.finalAgreement,
];

class KanbanScreen extends ConsumerStatefulWidget {
  const KanbanScreen({super.key});

  @override
  ConsumerState<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends ConsumerState<KanbanScreen> {
  int _focusedStageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsProvider);

    final byStage = {
      for (final s in _activeStages)
        s: leads.where((l) => l.stage == s).toList()
          ..sort((a, b) {
            // overdue first
            final aOver = a.hasOverdueFollowup ? 0 : 1;
            final bOver = b.hasOverdueFollowup ? 0 : 1;
            if (aOver != bOver) return aOver - bOver;
            return b.createdAt.compareTo(a.createdAt);
          }),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${leads.length} leads',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _StageTabBar(
            stages: _activeStages,
            counts: {for (final s in _activeStages) s: byStage[s]!.length},
            selected: _focusedStageIndex,
            onTap: (i) {
              setState(() => _focusedStageIndex = i);
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              );
            },
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _activeStages.length,
              onPageChanged: (i) => setState(() => _focusedStageIndex = i),
              itemBuilder: (_, i) {
                final stage = _activeStages[i];
                final stageLeads = byStage[stage]!;
                return _StageColumn(
                  stage: stage,
                  leads: stageLeads,
                  stageIndex: i,
                  totalStages: _activeStages.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTabBar extends StatelessWidget {
  final List<LeadStage> stages;
  final Map<LeadStage, int> counts;
  final int selected;
  final void Function(int) onTap;

  const _StageTabBar({
    required this.stages,
    required this.counts,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: stages.indexed.map((entry) {
            final i = entry.$1;
            final stage = entry.$2;
            final count = counts[stage] ?? 0;
            final isSelected = i == selected;

            return GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stage.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? AppColors.navy : Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _stageColor(stage)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
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
}

class _StageColumn extends ConsumerWidget {
  final LeadStage stage;
  final List<Lead> leads;
  final int stageIndex;
  final int totalStages;

  const _StageColumn({
    required this.stage,
    required this.leads,
    required this.stageIndex,
    required this.totalStages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No leads in ${stage.label}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Swipe to see other stages',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: leads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _KanbanCard(
        lead: leads[i],
        stage: stage,
        stageIndex: stageIndex,
        totalStages: totalStages,
      ),
    );
  }
}

class _KanbanCard extends ConsumerWidget {
  final Lead lead;
  final LeadStage stage;
  final int stageIndex;
  final int totalStages;

  const _KanbanCard({
    required this.lead,
    required this.stage,
    required this.stageIndex,
    required this.totalStages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = lead.hasOverdueFollowup;

    return GestureDetector(
      onTap: () => context.push('/leads/${lead.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.orange.shade200 : AppColors.divider,
            width: isOverdue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name row
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                    child: Text(
                      lead.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lead.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOverdue)
                    const Icon(Icons.access_time, color: Colors.orange, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              // Service + city
              Wrap(
                spacing: 8,
                children: [
                  _Pill(label: lead.serviceType.label, color: AppColors.stageCalled),
                  _Pill(label: lead.city.label, color: AppColors.navy),
                  if (lead.area != null)
                    _Pill(label: lead.area!, color: AppColors.textSecondary),
                ],
              ),
              if (lead.budget != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, size: 12, color: AppColors.textSecondary),
                    Text(
                      lead.budget!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              // Actions row
              Row(
                children: [
                  // Call count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call_outlined,
                          size: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        '${lead.callLogs.length}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Move to next stage button
                  if (stageIndex < totalStages - 1)
                    GestureDetector(
                      onTap: () => _moveNext(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _activeStages[stageIndex + 1].label,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, size: 11, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveNext(BuildContext context, WidgetRef ref) {
    final nextStage = _activeStages[stageIndex + 1];
    ref.read(leadsProvider.notifier).updateStage(lead.id, nextStage);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${lead.name} → ${nextStage.label}'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
