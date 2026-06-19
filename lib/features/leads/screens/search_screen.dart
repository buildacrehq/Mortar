import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/stage_badge.dart';
import 'package:buildacre_crm/features/leads/widgets/source_icon.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

// Recent searches — session-only state
final _recentSearchesProvider = StateProvider<List<String>>((ref) => []);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _saveRecent(String q) {
    if (q.trim().length < 2) return;
    final recents = ref.read(_recentSearchesProvider);
    final updated = [q, ...recents.where((r) => r != q)].take(8).toList();
    ref.read(_recentSearchesProvider.notifier).state = updated;
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsProvider);
    final recents = ref.watch(_recentSearchesProvider);
    final tcMap = {for (final t in ref.watch(profilesProvider)) t.id: t};

    final results = _query.length >= 2 ? _search(leads, _query) : <Lead>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          decoration: InputDecoration(
            hintText: 'Search name, phone, area, notes…',
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: AppColors.gold,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) _saveRecent(v.trim());
          },
        ),
      ),
      body: _query.length < 2
          ? _buildEmptyState(context, recents)
          : _buildResults(context, results, tcMap),
    );
  }

  List<Lead> _search(List<Lead> leads, String q) {
    final lower = q.toLowerCase();
    return leads.where((l) {
      return l.name.toLowerCase().contains(lower) ||
          l.phone.contains(lower) ||
          (l.area?.toLowerCase().contains(lower) ?? false) ||
          (l.email?.toLowerCase().contains(lower) ?? false) ||
          (l.budget?.toLowerCase().contains(lower) ?? false) ||
          l.serviceType.label.toLowerCase().contains(lower) ||
          l.city.label.toLowerCase().contains(lower) ||
          (l.notes?.toLowerCase().contains(lower) ?? false) ||
          l.internalNotes.any((n) => n.text.toLowerCase().contains(lower)) ||
          l.callLogs.any((c) => c.notes?.toLowerCase().contains(lower) ?? false);
    }).toList()
      ..sort((a, b) {
        // Exact name match first
        final aExact = a.name.toLowerCase().startsWith(lower) ? 0 : 1;
        final bExact = b.name.toLowerCase().startsWith(lower) ? 0 : 1;
        if (aExact != bExact) return aExact - bExact;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Widget _buildEmptyState(BuildContext context, List<String> recents) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (recents.isEmpty) ...[
          const SizedBox(height: 48),
          Icon(Icons.search, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Search across all leads',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Name · Phone · Area · Email · Budget',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ] else ...[
          Row(
            children: [
              const Text('RECENT',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8)),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(_recentSearchesProvider.notifier).state = [],
                child: const Text('Clear',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...recents.map((r) => _RecentTile(
                query: r,
                onTap: () {
                  _controller.text = r;
                  setState(() => _query = r);
                },
                onRemove: () {
                  final updated = recents.where((x) => x != r).toList();
                  ref.read(_recentSearchesProvider.notifier).state = updated;
                },
              )),
        ],
        const SizedBox(height: 20),
        _buildQuickFilters(context),
      ],
    );
  }

  Widget _buildQuickFilters(BuildContext context) {
    final chips = [
      ('Construction', Icons.home_work_outlined),
      ('Renovation', Icons.handyman_outlined),
      ('Interiors', Icons.chair_outlined),
      ('Bangalore', Icons.location_on_outlined),
      ('Mysore', Icons.location_on_outlined),
      ('Facebook', Icons.thumb_up_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK SEARCH',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips
              .map((c) => GestureDetector(
                    onTap: () {
                      _controller.text = c.$1;
                      setState(() => _query = c.$1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.$2, size: 14, color: AppColors.navy),
                          const SizedBox(width: 6),
                          Text(c.$1,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResults(
      BuildContext context, List<Lead> results, Map<String, TeamMember?> tcMap) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No leads match "$_query"',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surface,
          child: Row(
            children: [
              Text(
                '${results.length} result${results.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ResultCard(
              lead: results[i],
              query: _query,
              tc: tcMap[results[i].assignedTo],
              onTap: () {
                _saveRecent(_query.trim());
                context.push('/leads/${results[i].id}');
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _RecentTile({required this.query, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.history, size: 18, color: AppColors.textSecondary),
      title: Text(query, style: const TextStyle(fontSize: 14)),
      trailing: GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Lead lead;
  final String query;
  final TeamMember? tc;
  final VoidCallback onTap;
  const _ResultCard(
      {required this.lead, required this.query, required this.tc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SourceIcon(source: lead.source),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(text: lead.name, query: query,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _MetaText(lead.serviceType.label),
                      _MetaText(lead.city.label),
                      if (lead.area != null) _MetaText(lead.area!),
                      if (lead.budget != null) _MetaText(lead.budget!),
                    ],
                  ),
                  if (tc != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(tc!.name,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StageBadge(stage: lead.stage, compact: true),
                if (lead.hasOverdueFollowup) ...[
                  const SizedBox(height: 6),
                  const Icon(Icons.access_time, size: 14, color: Colors.orange),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Highlights the matching query text in bold gold
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  const _HighlightText({required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final idx = lower.indexOf(lowerQ);

    if (idx < 0) return Text(text, style: style);

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: style.copyWith(color: AppColors.gold, fontWeight: FontWeight.w800),
          ),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String text;
  const _MetaText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
  }
}
