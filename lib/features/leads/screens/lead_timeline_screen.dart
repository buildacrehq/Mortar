import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/models/lead_activity.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';

class LeadTimelineScreen extends ConsumerWidget {
  final String leadId;
  const LeadTimelineScreen({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadByIdProvider(leadId));

    if (lead == null) {
      return const Scaffold(body: Center(child: Text('Lead not found')));
    }

    final timeline = buildTimeline(lead);
    final totalCalls = lead.callLogs.length;
    final totalSeconds = lead.callLogs.fold(0, (s, l) => s + l.durationSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lead.name),
            Text(
              '${lead.serviceType.label} · ${lead.city.label}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryBar(context, totalCalls, totalSeconds, lead),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: timeline.length,
              itemBuilder: (_, i) => _TimelineItem(
                activity: timeline[i],
                isLast: i == timeline.length - 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(
      BuildContext context, int calls, int seconds, Lead lead) {
    final m = seconds ~/ 60;
    final h = m ~/ 60;
    final durLabel = h > 0 ? '${h}h ${m % 60}m' : '${m}m';

    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _SumStat(label: 'Total Calls', value: '$calls'),
          const SizedBox(width: 24),
          _SumStat(label: 'Talk Time', value: calls == 0 ? '—' : durLabel),
          const SizedBox(width: 24),
          _SumStat(
            label: 'Pipeline Step',
            value: lead.stage.step > 0 ? '${lead.stage.step}/7' : lead.stage.label,
            highlight: lead.stage == LeadStage.finalAgreement,
          ),
          const Spacer(),
          if (lead.hasOverdueFollowup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Overdue',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _SumStat(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: highlight ? AppColors.gold : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final LeadActivity activity;
  final bool isLast;
  const _TimelineItem({required this.activity, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, bgColor) = _iconForType(activity);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      Text(
                        _formatTime(activity.at),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (activity.durationSeconds != null) ...[
                    const SizedBox(height: 4),
                    _DurationChip(
                        seconds: activity.durationSeconds!,
                        outcome: activity.outcome),
                  ],
                  if (activity.subtitle != null &&
                      activity.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity.subtitle!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _fullDate(activity.at),
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _iconForType(LeadActivity a) {
    switch (a.type) {
      case ActivityType.created:
        return (Icons.person_add_outlined, AppColors.navy,
            AppColors.navy.withValues(alpha: 0.08));
      case ActivityType.called:
        return _callIconForOutcome(a.outcome);
      case ActivityType.stageChanged:
        return (Icons.swap_horiz, AppColors.stageQuotation,
            AppColors.stageQuotation.withValues(alpha: 0.08));
      case ActivityType.noteAdded:
        return (Icons.sticky_note_2_outlined, AppColors.stageMeeting,
            AppColors.stageMeeting.withValues(alpha: 0.08));
      case ActivityType.followupSet:
        return (Icons.schedule, AppColors.gold,
            AppColors.gold.withValues(alpha: 0.08));
    }
  }

  (IconData, Color, Color) _callIconForOutcome(CallOutcome? o) {
    switch (o) {
      case CallOutcome.interested:
        return (Icons.thumb_up_outlined, AppColors.stageWon,
            AppColors.stageWon.withValues(alpha: 0.08));
      case CallOutcome.notInterested:
        return (Icons.thumb_down_outlined, AppColors.stageLost,
            AppColors.stageLost.withValues(alpha: 0.08));
      case CallOutcome.callback:
        return (Icons.schedule, AppColors.stageCalled,
            AppColors.stageCalled.withValues(alpha: 0.08));
      case CallOutcome.notReachable:
        return (Icons.phone_missed_outlined, AppColors.textSecondary,
            AppColors.surface);
      case CallOutcome.future:
        return (Icons.hourglass_empty, AppColors.stageMeeting,
            AppColors.stageMeeting.withValues(alpha: 0.08));
      default:
        return (Icons.call_outlined, AppColors.navy,
            AppColors.navy.withValues(alpha: 0.08));
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return DateFormat('h:mm a').format(dt);
    final diff = today.difference(d).inDays;
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  String _fullDate(DateTime dt) =>
      DateFormat('EEEE, d MMM yyyy · h:mm a').format(dt);
}

class _DurationChip extends StatelessWidget {
  final int seconds;
  final CallOutcome? outcome;
  const _DurationChip({required this.seconds, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final isShort = seconds < AppConstants.shortCallThresholdSeconds;
    final color = isShort ? Colors.red : AppColors.stageWon;
    final label = isShort ? '${s}s · Short call' : '${m}m ${s}s';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
