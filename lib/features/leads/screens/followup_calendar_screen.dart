import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/filtered_leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/stage_badge.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

class FollowupCalendarScreen extends ConsumerStatefulWidget {
  const FollowupCalendarScreen({super.key});

  @override
  ConsumerState<FollowupCalendarScreen> createState() =>
      _FollowupCalendarScreenState();
}

class _FollowupCalendarScreenState
    extends ConsumerState<FollowupCalendarScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    // Week starts on Monday
    _weekStart = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    // Use calendarLeadsProvider for accurate data — not affected by list pagination
    final leads = ref.watch(calendarLeadsProvider);
    final role = ref.watch(currentUserRoleProvider);
    final user = ref.watch(authProvider);
    final tcMap = {for (final t in ref.watch(profilesProvider)) t.id: t};

    final myLeads = role == UserRole.telecaller
        ? leads.where((l) => l.assignedTo == user?.id).toList()
        : leads;

    // Build date → leads map
    final followupMap = <DateTime, List<Lead>>{};
    for (final lead in myLeads) {
      if (lead.followupAt == null) continue;
      if (lead.stage == LeadStage.lost || lead.stage == LeadStage.finalAgreement) continue;
      final day = DateTime(
          lead.followupAt!.year, lead.followupAt!.month, lead.followupAt!.day);
      followupMap.putIfAbsent(day, () => []).add(lead);
    }

    final selectedLeads = (followupMap[_selectedDay] ?? [])
      ..sort((a, b) => a.followupAt!.compareTo(b.followupAt!));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Count overdue (before today, has followup, not done)
    final overdueCount = myLeads
        .where((l) =>
            l.hasOverdueFollowup &&
            l.stage != LeadStage.lost &&
            l.stage != LeadStage.finalAgreement)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up Calendar'),
        actions: [
          if (overdueCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$overdueCount overdue',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthHeader(context, todayDate),
          _buildWeekStrip(context, followupMap, todayDate),
          _buildSelectedDayHeader(context, selectedLeads.length, todayDate),
          Expanded(
            child: selectedLeads.isEmpty
                ? _buildDayEmpty(context, todayDate)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: selectedLeads.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _FollowupCard(
                      lead: selectedLeads[i],
                      tc: tcMap[selectedLeads[i].assignedTo],
                      isToday: _selectedDay == todayDate,
                      isPast: _selectedDay.isBefore(todayDate),
                    ),
                  ),
          ),
          // Upcoming summary strip
          _buildUpcomingSummary(context, followupMap, todayDate),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context, DateTime today) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final sameMonth = _weekStart.month == weekEnd.month;
    final label = sameMonth
        ? DateFormat('MMMM yyyy').format(_weekStart)
        : '${DateFormat('MMM').format(_weekStart)} – ${DateFormat('MMM yyyy').format(weekEnd)}';

    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white70),
            onPressed: () => setState(
                () => _weekStart = _weekStart.subtract(const Duration(days: 7))),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white70),
            onPressed: () => setState(
                () => _weekStart = _weekStart.add(const Duration(days: 7))),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              final td = DateTime(now.year, now.month, now.day);
              setState(() {
                _selectedDay = td;
                _weekStart = td.subtract(Duration(days: td.weekday - 1));
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Today',
                style: TextStyle(color: AppColors.gold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(BuildContext context,
      Map<DateTime, List<Lead>> followupMap, DateTime today) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        children: List.generate(7, (i) {
          final day = _weekStart.add(Duration(days: i));
          final isToday = day == today;
          final isSelected = day == _selectedDay;
          final isPast = day.isBefore(today);
          final leads = followupMap[day] ?? [];
          final count = leads.length;
          final hasOverdue = isPast && count > 0;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isToday ? AppColors.gold : Colors.white.withValues(alpha: 0.15))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day)[0], // M T W T F S S
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white
                            : (isPast ? Colors.white38 : Colors.white60),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w800
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : (isPast ? Colors.white38 : Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Dot indicator
                    if (count > 0)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: hasOverdue
                              ? Colors.red
                              : (isToday
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.25)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedDayHeader(
      BuildContext context, int count, DateTime today) {
    final isPast = _selectedDay.isBefore(today);
    final isToday = _selectedDay == today;

    String dayLabel;
    if (isToday) {
      dayLabel = 'Today';
    } else if (_selectedDay == today.add(const Duration(days: 1))) {
      dayLabel = 'Tomorrow';
    } else if (_selectedDay == today.subtract(const Duration(days: 1))) {
      dayLabel = 'Yesterday';
    } else {
      dayLabel = DateFormat('EEEE, d MMM').format(_selectedDay);
    }

    Color labelColor = AppColors.textPrimary;
    if (isPast && count > 0) labelColor = Colors.red;
    if (isToday) labelColor = AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: Row(
        children: [
          Text(
            dayLabel,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: labelColor),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: labelColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count follow-up${count != 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayEmpty(BuildContext context, DateTime today) {
    final isPast = _selectedDay.isBefore(today);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPast ? Icons.check_circle_outline : Icons.event_available_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            isPast ? 'No follow-ups were due' : 'Nothing scheduled',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSummary(BuildContext context,
      Map<DateTime, List<Lead>> followupMap, DateTime today) {
    // Next 7 days with counts
    final upcoming = List.generate(7, (i) {
      final d = today.add(Duration(days: i + 1));
      return (d, followupMap[d]?.length ?? 0);
    }).where((e) => e.$2 > 0).toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UPCOMING',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: upcoming.map((e) {
                return GestureDetector(
                  onTap: () {
                    final d = DateTime(e.$1.year, e.$1.month, e.$1.day);
                    setState(() {
                      _selectedDay = d;
                      _weekStart = d.subtract(Duration(days: d.weekday - 1));
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(e.$1),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${e.$1.day}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${e.$2}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowupCard extends ConsumerWidget {
  final Lead lead;
  final TeamMember? tc;
  final bool isToday;
  final bool isPast;

  const _FollowupCard(
      {required this.lead,
      required this.tc,
      required this.isToday,
      required this.isPast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = lead.followupAt != null
        ? DateFormat('h:mm a').format(lead.followupAt!)
        : '';

    Color accentColor = AppColors.navy;
    if (isPast) accentColor = Colors.red;
    if (isToday) accentColor = AppColors.gold;

    return GestureDetector(
      onTap: () => context.push('/leads/${lead.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPast ? Colors.red.shade200 : AppColors.divider,
            width: isPast ? 1.5 : 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored time sidebar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: accentColor.withValues(alpha: 0.1),
                        child: Text(
                          lead.name[0].toUpperCase(),
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lead.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              '${lead.serviceType.label} · ${lead.city.label}${lead.area != null ? ' · ${lead.area}' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (lead.lastOutcome != null) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.history,
                                    size: 11, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Last: ${lead.lastOutcome!.label}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ]),
                            ],
                            if (tc != null) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.person_outline,
                                    size: 11, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  tc!.name.split(' ').first,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      // Right side: time + stage
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor),
                            ),
                          const SizedBox(height: 4),
                          StageBadge(stage: lead.stage, compact: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
