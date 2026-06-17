import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/source_icon.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';

class LostLeadsScreen extends ConsumerStatefulWidget {
  const LostLeadsScreen({super.key});

  @override
  ConsumerState<LostLeadsScreen> createState() => _LostLeadsScreenState();
}

class _LostLeadsScreenState extends ConsumerState<LostLeadsScreen> {
  LeadSource? _sourceFilter;
  City? _cityFilter;
  String _sortBy = 'recent'; // 'recent' | 'oldest'

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsProvider);
    final tcMap = {for (final t in mockTelecallers) t.id: t};

    final lost = leads.where((l) => l.stage == LeadStage.lost).toList();

    // Stats
    final bySource = <LeadSource, int>{};
    final byService = <ServiceType, int>{};
    for (final l in lost) {
      bySource[l.source] = (bySource[l.source] ?? 0) + 1;
      byService[l.serviceType] = (byService[l.serviceType] ?? 0) + 1;
    }
    final topLossSource = bySource.entries.isEmpty
        ? null
        : bySource.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Filtered list
    var filtered = lost.where((l) {
      if (_sourceFilter != null && l.source != _sourceFilter) return false;
      if (_cityFilter != null && l.city != _cityFilter) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => _sortBy == 'recent'
        ? b.lastContactedAt
                ?.compareTo(a.lastContactedAt ?? DateTime(2000)) ??
            b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost Leads'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.stageLost.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${lost.length} lost',
                  style: const TextStyle(
                      color: AppColors.stageLost,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInsightsBar(context, lost.length, bySource, byService, topLossSource),
          _buildFilters(context, lost),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty(lost.isEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _LostCard(
                      lead: filtered[i],
                      tc: tcMap[filtered[i].assignedTo],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsBar(
    BuildContext context,
    int total,
    Map<LeadSource, int> bySource,
    Map<ServiceType, int> byService,
    MapEntry<LeadSource, int>? topSource,
  ) {
    final byCity = <City, int>{};
    final leads = ref.read(leadsProvider)
        .where((l) => l.stage == LeadStage.lost);
    for (final l in leads) {
      byCity[l.city] = (byCity[l.city] ?? 0) + 1;
    }

    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InsightStat(label: 'Total Lost', value: '$total'),
              const SizedBox(width: 24),
              _InsightStat(
                label: 'Top Loss Source',
                value: topSource?.key.label ?? '—',
                highlight: true,
              ),
              const SizedBox(width: 24),
              _InsightStat(
                label: 'Bangalore',
                value: '${byCity[City.bangalore] ?? 0}',
              ),
              const SizedBox(width: 24),
              _InsightStat(
                label: 'Mysore',
                value: '${byCity[City.mysore] ?? 0}',
              ),
            ],
          ),
          if (bySource.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Source breakdown mini bars
            Row(
              children: LeadSource.values
                  .where((s) => (bySource[s] ?? 0) > 0)
                  .map((s) {
                final count = bySource[s]!;
                return Expanded(
                  flex: count,
                  child: Tooltip(
                    message: '${s.label}: $count',
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: _sourceColor(s),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            const Text(
              'Loss by source',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, List<Lead> lost) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Source filter
          Expanded(
            child: _DropdownFilter<LeadSource?>(
              value: _sourceFilter,
              hint: 'All Sources',
              items: [
                const DropdownMenuItem(value: null, child: Text('All Sources')),
                ...LeadSource.values
                    .where((s) => lost.any((l) => l.source == s))
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        )),
              ],
              onChanged: (v) => setState(() => _sourceFilter = v),
            ),
          ),
          const SizedBox(width: 10),
          // City filter
          Expanded(
            child: _DropdownFilter<City?>(
              value: _cityFilter,
              hint: 'All Cities',
              items: [
                const DropdownMenuItem(value: null, child: Text('All Cities')),
                ...City.values.map((c) =>
                    DropdownMenuItem(value: c, child: Text(c.label))),
              ],
              onChanged: (v) => setState(() => _cityFilter = v),
            ),
          ),
          const SizedBox(width: 10),
          // Sort
          GestureDetector(
            onTap: () => setState(
                () => _sortBy = _sortBy == 'recent' ? 'oldest' : 'recent'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sortBy == 'recent'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortBy == 'recent' ? 'Recent' : 'Oldest',
                    style: const TextStyle(fontSize: 12, color: AppColors.navy),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool noLostAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noLostAtAll ? Icons.sentiment_satisfied_outlined : Icons.filter_alt_off,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            noLostAtAll ? 'No lost leads yet!' : 'No matches for this filter',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
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

class _InsightStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _InsightStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: highlight ? Colors.redAccent : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

class _LostCard extends ConsumerWidget {
  final Lead lead;
  final TelecallerProfile? tc;
  const _LostCard({required this.lead, required this.tc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysSinceContact = lead.lastContactedAt != null
        ? DateTime.now().difference(lead.lastContactedAt!).inDays
        : DateTime.now().difference(lead.createdAt).inDays;

    return GestureDetector(
      onTap: () => context.push('/leads/${lead.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                  // Days since lost
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$daysSinceContact d ago',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (lead.budget != null)
                        Text(
                          lead.budget!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ),
              if (lead.callLogs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.call_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${lead.callLogs.length} call${lead.callLogs.length > 1 ? 's' : ''} made',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (tc != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.person_outline,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        tc!.name.split(' ').first,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
              if (lead.lastOutcome != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Last outcome: ${lead.lastOutcome!.label}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Re-engage button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Re-engage Lead'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _reEngage(context, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reEngage(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Re-engage Lead?'),
        content: Text(
          'Move ${lead.name} back to Enquiry stage and add to the active pipeline?',
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
                  content: Text('${lead.name} moved back to Enquiry'),
                  backgroundColor: AppColors.stageWon,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Re-engage'),
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
