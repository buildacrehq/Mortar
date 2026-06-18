import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/stage_badge.dart';
import 'package:buildacre_crm/features/leads/widgets/source_icon.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/notifications/providers/notifications_provider.dart';

class LeadsListScreen extends ConsumerStatefulWidget {
  const LeadsListScreen({super.key});

  @override
  ConsumerState<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends ConsumerState<LeadsListScreen> {
  LeadStage? _filterStage;
  String _search = '';
  City? _filterCity;
  LeadSource? _filterSource;
  ServiceType? _filterService;

  int get _activeFilterCount =>
      (_filterCity != null ? 1 : 0) +
      (_filterSource != null ? 1 : 0) +
      (_filterService != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final allLeads = ref.watch(leadsProvider);
    final isLoading = ref.watch(leadsLoadingProvider);
    final overdueCount = ref.watch(overdueLeadsProvider).length;
    final todayCount = ref.watch(todayLeadsCountProvider);
    final role = ref.watch(currentUserRoleProvider);
    final isManager = role == UserRole.manager || role == UserRole.admin;
    final unreadNotifs = ref.watch(unreadCountProvider);

    final filtered = allLeads.where((l) {
      final matchesStage = _filterStage == null || l.stage == _filterStage;
      final matchesCity = _filterCity == null || l.city == _filterCity;
      final matchesSource = _filterSource == null || l.source == _filterSource;
      final matchesService = _filterService == null || l.serviceType == _filterService;
      final matchesSearch = _search.isEmpty ||
          l.name.toLowerCase().contains(_search.toLowerCase()) ||
          l.area?.toLowerCase().contains(_search.toLowerCase()) == true;
      return matchesStage && matchesCity && matchesSource && matchesService && matchesSearch;
    }).toList()
      ..sort((a, b) {
        if (a.hasOverdueFollowup && !b.hasOverdueFollowup) return -1;
        if (!a.hasOverdueFollowup && b.hasOverdueFollowup) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search leads',
            onPressed: () => context.push('/leads/search'),
          ),
          if (isManager)
            IconButton(
              icon: const Icon(Icons.assignment_ind_outlined),
              tooltip: 'Assign leads',
              onPressed: () => context.push('/leads/assign'),
            ),
          if (isManager)
            IconButton(
              icon: const Icon(Icons.person_off_outlined),
              tooltip: 'Lost leads',
              onPressed: () => context.push('/leads/lost'),
            ),
          if (isManager)
            IconButton(
              icon: const Icon(Icons.hourglass_top_outlined),
              tooltip: 'Future pipeline',
              onPressed: () => context.push('/leads/future'),
            ),
          IconButton(
            icon: const Icon(Icons.view_kanban_outlined),
            tooltip: 'Pipeline view',
            onPressed: () => context.push('/leads/kanban'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
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
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBar(todayCount, overdueCount, allLeads.length),
          _buildSearchAndFilter(),
          if (isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: AppColors.gold,
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.navy,
              onRefresh: () => ref.read(leadsProvider.notifier).refresh(),
              child: filtered.isEmpty
                ? isLoading
                    ? const SizedBox.shrink()
                    : _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _LeadCard(
                      lead: filtered[i],
                      onTap: () => context.push('/leads/${filtered[i].id}'),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int today, int overdue, int total) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _StatChip(label: 'Today', value: today, color: AppColors.gold),
          const SizedBox(width: 12),
          _StatChip(label: 'Total', value: total, color: Colors.white70),
          const SizedBox(width: 12),
          if (overdue > 0)
            _StatChip(label: 'Overdue', value: overdue, color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or area…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showFilterSheet(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _activeFilterCount > 0
                            ? AppColors.navy
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _activeFilterCount > 0
                              ? AppColors.navy
                              : AppColors.divider,
                        ),
                      ),
                      child: Icon(
                        Icons.tune_outlined,
                        size: 20,
                        color: _activeFilterCount > 0
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_activeFilterCount',
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filterStage == null,
                  onTap: () => setState(() => _filterStage = null),
                ),
                ...LeadStage.values
                    .where((s) => s != LeadStage.lost)
                    .map((s) => _FilterChip(
                          label: s.label,
                          selected: _filterStage == s,
                          onTap: () => setState(
                              () => _filterStage = _filterStage == s ? null : s),
                        )),
              ],
            ),
          ),
          // Active filter chips
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_filterCity != null)
                    _ActiveFilterChip(
                      label: _filterCity!.label,
                      onRemove: () => setState(() => _filterCity = null),
                    ),
                  if (_filterSource != null)
                    _ActiveFilterChip(
                      label: _filterSource!.label,
                      onRemove: () => setState(() => _filterSource = null),
                    ),
                  if (_filterService != null)
                    _ActiveFilterChip(
                      label: _filterService!.label,
                      onRemove: () => setState(() => _filterService = null),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      _filterCity = null;
                      _filterSource = null;
                      _filterService = null;
                    }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear all',
                        style: TextStyle(
                            fontSize: 12, color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        city: _filterCity,
        source: _filterSource,
        service: _filterService,
        onApply: (city, source, service) => setState(() {
          _filterCity = city;
          _filterSource = source;
          _filterService = service;
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty || _filterStage != null || _activeFilterCount > 0
                ? 'No leads match your filter'
                : 'No leads assigned yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
        ),
      ],
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.navy,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final City? city;
  final LeadSource? source;
  final ServiceType? service;
  final void Function(City?, LeadSource?, ServiceType?) onApply;

  const _FilterSheet({
    required this.city,
    required this.source,
    required this.service,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  City? _city;
  LeadSource? _source;
  ServiceType? _service;

  @override
  void initState() {
    super.initState();
    _city = widget.city;
    _source = widget.source;
    _service = widget.service;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Filters',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _city = null;
                  _source = null;
                  _service = null;
                }),
                child: const Text('Reset',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection('City', City.values.map((c) => (c.label, c == _city,
              () => setState(() => _city = _city == c ? null : c))).toList()),
          const SizedBox(height: 16),
          _buildSection('Service Type', ServiceType.values.map((s) => (s.label, s == _service,
              () => setState(() => _service = _service == s ? null : s))).toList()),
          const SizedBox(height: 16),
          _buildSection('Lead Source', LeadSource.values.map((s) => (s.label, s == _source,
              () => setState(() => _source = _source == s ? null : s))).toList()),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_city, _source, _service);
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<(String, bool, VoidCallback)> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = opt.$2;
            return GestureDetector(
              onTap: opt.$3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.navy : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.navy : AppColors.divider,
                  ),
                ),
                child: Text(
                  opt.$1,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadCard extends ConsumerWidget {
  final Lead lead;
  final VoidCallback onTap;

  const _LeadCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final isManager = role == UserRole.manager || role == UserRole.admin;
    final isOverdue = lead.hasOverdueFollowup;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.red.shade200 : AppColors.divider,
            width: isOverdue ? 1.5 : 1,
          ),
        ),
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
                      Text(
                        lead.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        isManager ? lead.phone : lead.maskedPhone,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ),
                StageBadge(stage: lead.stage, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _InfoPill(
                  icon: Icons.home_work_outlined,
                  label: lead.serviceType.label,
                ),
                _InfoPill(
                  icon: Icons.location_on_outlined,
                  label: '${lead.city.label}${lead.area != null ? ' · ${lead.area}' : ''}',
                ),
                if (lead.budget != null)
                  _InfoPill(
                    icon: Icons.currency_rupee,
                    label: lead.budget!,
                  ),
              ],
            ),
            if (lead.followupAt != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
                    size: 14,
                    color: isOverdue ? Colors.red : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOverdue
                        ? 'Overdue · ${_formatFollowup(lead.followupAt!)}'
                        : 'Followup · ${_formatFollowup(lead.followupAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : AppColors.textSecondary,
                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(lead.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _timeAgo(lead.createdAt),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFollowup(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inDays == 0) return 'Today ${DateFormat('h:mm a').format(dt)}';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays == -1) return 'Yesterday';
    if (diff.inDays < 0) return '${diff.inDays.abs()}d ago';
    return DateFormat('d MMM').format(dt);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
