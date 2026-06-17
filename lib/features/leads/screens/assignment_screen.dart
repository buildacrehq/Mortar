import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/source_icon.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';

class AssignmentScreen extends ConsumerStatefulWidget {
  const AssignmentScreen({super.key});

  @override
  ConsumerState<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends ConsumerState<AssignmentScreen> {
  String? _selectedTcFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsProvider);

    // Unassigned = 'unassigned' id OR leads assigned to unknown tc
    final knownIds = mockTelecallers.map((t) => t.id).toSet();
    final unassigned = leads
        .where((l) => !knownIds.contains(l.assignedTo))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Build workload map
    final workload = <String, int>{};
    for (final tc in mockTelecallers) {
      workload[tc.id] = leads.where((l) => l.assignedTo == tc.id).length;
    }
    final maxLoad = workload.values.fold(0, (a, b) => a > b ? a : b);

    // All leads for reassignment view, filtered by selected tc
    final assigned = leads
        .where((l) => knownIds.contains(l.assignedTo))
        .where((l) => _selectedTcFilter == null || l.assignedTo == _selectedTcFilter)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Lead Assignment')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Workload bar
          _WorkloadSection(
            telecallers: mockTelecallers,
            workload: workload,
            maxLoad: maxLoad,
            selected: _selectedTcFilter,
            onTap: (id) => setState(() =>
                _selectedTcFilter = _selectedTcFilter == id ? null : id),
          ),

          // Unassigned leads
          if (unassigned.isNotEmpty) ...[
            _SectionHeader(
              label: 'Unassigned',
              count: unassigned.length,
              color: Colors.red,
              icon: Icons.person_off_outlined,
            ),
            ...unassigned.map((l) => _LeadRow(
                  lead: l,
                  telecallers: mockTelecallers,
                  workload: workload,
                  highlight: true,
                )),
            const SizedBox(height: 8),
          ],

          // Assigned leads (filterable)
          _SectionHeader(
            label: _selectedTcFilter == null
                ? 'All Assigned Leads'
                : '${mockTelecallers.firstWhere((t) => t.id == _selectedTcFilter).name.split(' ').first}\'s Leads',
            count: assigned.length,
            color: AppColors.navy,
            icon: Icons.assignment_ind_outlined,
          ),
          ...assigned.map((l) => _LeadRow(
                lead: l,
                telecallers: mockTelecallers,
                workload: workload,
              )),
        ],
      ),
    );
  }
}

class _WorkloadSection extends StatelessWidget {
  final List<TelecallerProfile> telecallers;
  final Map<String, int> workload;
  final int maxLoad;
  final String? selected;
  final void Function(String) onTap;

  const _WorkloadSection({
    required this.telecallers,
    required this.workload,
    required this.maxLoad,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEAM WORKLOAD',
            style: TextStyle(
                color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          ...telecallers.map((tc) {
            final count = workload[tc.id] ?? 0;
            final pct = maxLoad == 0 ? 0.0 : count / maxLoad;
            final isSelected = selected == tc.id;

            return GestureDetector(
              onTap: () => onTap(tc.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                      child: Text(
                        tc.name[0],
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tc.name.split(' ').first,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            tc.city.label,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(
                              pct > 0.8 ? Colors.redAccent : AppColors.gold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$count leads',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          const Text(
            'Tap a rep to filter · Bar turns red when overloaded',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SectionHeader(
      {required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _LeadRow extends ConsumerWidget {
  final Lead lead;
  final List<TelecallerProfile> telecallers;
  final Map<String, int> workload;
  final bool highlight;

  const _LeadRow({
    required this.lead,
    required this.telecallers,
    required this.workload,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTc = telecallers.where((t) => t.id == lead.assignedTo).firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? Colors.red.shade200 : AppColors.divider,
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Source icon
              SourceIcon(source: lead.source),
              const SizedBox(width: 10),
              // Lead info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${lead.serviceType.label} · ${lead.city.label}${lead.area != null ? ' · ${lead.area}' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Current assignee + change button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (currentTc != null)
                    Text(
                      currentTc.name.split(' ').first,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    )
                  else
                    const Text('Unassigned',
                        style: TextStyle(
                            fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showAssignSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: highlight ? Colors.red : AppColors.navy,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        highlight ? 'Assign' : 'Reassign',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
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

  void _showAssignSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignSheet(
        lead: lead,
        telecallers: telecallers,
        workload: workload,
        onAssign: (tcId) {
          ref.read(leadsProvider.notifier).assignLead(lead.id, tcId);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${lead.name} assigned to ${telecallers.firstWhere((t) => t.id == tcId).name.split(' ').first}'),
              backgroundColor: AppColors.navy,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

class _AssignSheet extends StatelessWidget {
  final Lead lead;
  final List<TelecallerProfile> telecallers;
  final Map<String, int> workload;
  final void Function(String) onAssign;

  const _AssignSheet({
    required this.lead,
    required this.telecallers,
    required this.workload,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...telecallers]
      ..sort((a, b) => (workload[a.id] ?? 0).compareTo(workload[b.id] ?? 0));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign ${lead.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${lead.serviceType.label} · ${lead.city.label}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sorted by lightest workload first',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...sorted.map((tc) {
            final count = workload[tc.id] ?? 0;
            final isCurrent = tc.id == lead.assignedTo;
            return GestureDetector(
              onTap: isCurrent ? null : () => onAssign(tc.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.navy.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent ? AppColors.navy : AppColors.divider,
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                      child: Text(tc.name[0],
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(tc.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              if (isCurrent) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.navy.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Current',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.navy,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${tc.city.label} · $count lead${count != 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Assign',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
