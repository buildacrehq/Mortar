import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';

class TelecallerStats {
  final TeamMember profile;
  final int totalLeads;
  final int callsToday;
  final int callsThisWeek;
  final int totalCallDurationSeconds;
  final Map<CallOutcome, int> outcomeBreakdown;
  final int overdueFollowups;
  final int wonLeads;

  const TelecallerStats({
    required this.profile,
    required this.totalLeads,
    required this.callsToday,
    required this.callsThisWeek,
    required this.totalCallDurationSeconds,
    required this.outcomeBreakdown,
    required this.overdueFollowups,
    required this.wonLeads,
  });

  double get performanceScore {
    final callScore = (callsThisWeek / 25).clamp(0.0, 1.0);
    final durationScore = avgCallDurationSeconds > 0
        ? (avgCallDurationSeconds / 600).clamp(0.0, 1.0)
        : 0.0;
    final conversionScore =
        totalLeads > 0 ? (wonLeads / totalLeads).clamp(0.0, 1.0) : 0.0;
    final overdueScore =
        totalLeads > 0 ? (1 - overdueFollowups / totalLeads).clamp(0.0, 1.0) : 1.0;

    return ((callScore * 0.35) +
            (durationScore * 0.25) +
            (conversionScore * 0.25) +
            (overdueScore * 0.15)) *
        10;
  }

  int get avgCallDurationSeconds {
    final total = outcomeBreakdown.values.fold(0, (a, b) => a + b);
    if (total == 0) return 0;
    return totalCallDurationSeconds ~/ total;
  }

  String get formattedTotalDuration {
    final h = totalCallDurationSeconds ~/ 3600;
    final m = (totalCallDurationSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String get formattedAvgDuration {
    final m = avgCallDurationSeconds ~/ 60;
    final s = avgCallDurationSeconds % 60;
    return '${m}m ${s}s';
  }
}

TelecallerStats computeStats(TeamMember profile, List<Lead> allLeads) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

  final myLeads = allLeads.where((l) => l.assignedTo == profile.id).toList();
  final allLogs = myLeads.expand((l) => l.callLogs).toList();

  final callsToday = allLogs.where((c) => c.calledAt.isAfter(todayStart)).length;
  final callsThisWeek = allLogs.where((c) => c.calledAt.isAfter(weekStart)).length;
  final totalDuration = allLogs.fold<int>(0, (sum, c) => sum + c.durationSeconds);

  final outcomeBreakdown = <CallOutcome, int>{};
  for (final outcome in CallOutcome.values) {
    outcomeBreakdown[outcome] = allLogs.where((c) => c.outcome == outcome).length;
  }

  final overdue = myLeads.where((l) => l.hasOverdueFollowup).length;
  final won = myLeads.where((l) => l.stage == LeadStage.finalAgreement).length;

  return TelecallerStats(
    profile: profile,
    totalLeads: myLeads.length,
    callsToday: callsToday,
    callsThisWeek: callsThisWeek,
    totalCallDurationSeconds: totalDuration,
    outcomeBreakdown: outcomeBreakdown,
    overdueFollowups: overdue,
    wonLeads: won,
  );
}
