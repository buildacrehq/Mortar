import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';

enum ActivityType { created, called, stageChanged, noteAdded, followupSet }

class LeadActivity {
  final ActivityType type;
  final DateTime at;
  final String title;
  final String? subtitle;
  final CallOutcome? outcome;
  final LeadStage? stage;
  final int? durationSeconds;

  const LeadActivity({
    required this.type,
    required this.at,
    required this.title,
    this.subtitle,
    this.outcome,
    this.stage,
    this.durationSeconds,
  });
}

/// Builds a chronological activity list from a Lead's data.
List<LeadActivity> buildTimeline(Lead lead) {
  final activities = <LeadActivity>[];

  // Lead created
  activities.add(LeadActivity(
    type: ActivityType.created,
    at: lead.createdAt,
    title: 'Lead created',
    subtitle: '${lead.source.label} · ${lead.serviceType.label} · ${lead.city.label}',
  ));

  // Call logs
  for (final log in lead.callLogs) {
    activities.add(LeadActivity(
      type: ActivityType.called,
      at: log.calledAt,
      title: 'Call — ${log.outcome.label}',
      subtitle: log.notes,
      outcome: log.outcome,
      durationSeconds: log.durationSeconds,
    ));
  }

  // Follow-up scheduled (from latest call that has one)
  if (lead.followupAt != null && lead.callLogs.isNotEmpty) {
    final lastCall = lead.callLogs.last;
    activities.add(LeadActivity(
      type: ActivityType.followupSet,
      at: lastCall.calledAt.add(const Duration(seconds: 1)),
      title: 'Follow-up scheduled',
      subtitle: _formatFollowup(lead.followupAt!),
    ));
  }

  activities.sort((a, b) => b.at.compareTo(a.at)); // newest first
  return activities;
}

String _formatFollowup(DateTime dt) {
  final now = DateTime.now();
  final diff = dt.difference(now);
  if (diff.isNegative) {
    final days = diff.inDays.abs();
    return days == 0 ? 'Was due today' : '$days day${days > 1 ? 's' : ''} ago';
  }
  final days = diff.inDays;
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'In $days days';
}
