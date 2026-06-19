import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/services/leads_service.dart';
import 'package:buildacre_crm/main.dart';

// ─── Lightweight lead summary for stats (no nested call_logs/notes) ──────────

class LeadSummary {
  final String id;
  final String assignedTo;
  final LeadStage stage;
  final LeadSource source;
  final ServiceType serviceType;
  final City city;
  final DateTime createdAt;
  final DateTime? followupAt;

  const LeadSummary({
    required this.id,
    required this.assignedTo,
    required this.stage,
    required this.source,
    required this.serviceType,
    required this.city,
    required this.createdAt,
    this.followupAt,
  });

  bool get hasOverdueFollowup =>
      followupAt != null && followupAt!.isBefore(DateTime.now());
}

class CallLogSummary {
  final String leadId;
  final String calledBy;
  final DateTime calledAt;
  final int durationSeconds;
  final CallOutcome outcome;

  const CallLogSummary({
    required this.leadId,
    required this.calledBy,
    required this.calledAt,
    required this.durationSeconds,
    required this.outcome,
  });
}

// ─── Analytics state ──────────────────────────────────────────────────────────

class AnalyticsData {
  final List<LeadSummary> leads;
  final List<CallLogSummary> callLogs;
  final bool isLoading;

  const AnalyticsData({
    this.leads = const [],
    this.callLogs = const [],
    this.isLoading = true,
  });
}

class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  AnalyticsNotifier() : super(const AnalyticsData()) {
    _load();
    _subscribeRealtime();
  }

  Timer? _debounce;

  void _subscribeRealtime() {
    // Auto-refresh analytics when leads or call_logs change (debounced 3s)
    supabase
        .channel('analytics_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leads',
          callback: (_) => _debouncedRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'call_logs',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();
  }

  void _debouncedRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Lightweight leads query — no nested data
      final leadsData = await supabase
          .from('leads')
          .select('id, assigned_to, stage, source, service_type, city, created_at, followup_at')
          .order('created_at', ascending: false);

      // Call logs for last 90 days only
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final logsData = await supabase
          .from('call_logs')
          .select('lead_id, called_by, called_at, duration_seconds, outcome')
          .gte('called_at', cutoff.toUtc().toIso8601String());

      if (!mounted) return;

      final leads = (leadsData as List).map((m) => LeadSummary(
            id: m['id'] as String,
            assignedTo: m['assigned_to'] as String? ?? '',
            stage: LeadStage.values.firstWhere(
                (s) => s.name == m['stage'],
                orElse: () => LeadStage.enquiryReceived),
            source: LeadSource.values.firstWhere(
                (s) => s.name == m['source'],
                orElse: () => LeadSource.phone),
            serviceType: ServiceType.values.firstWhere(
                (s) => s.name == m['service_type'],
                orElse: () => ServiceType.construction),
            city: City.values.firstWhere(
                (c) => c.name == m['city'],
                orElse: () => City.bangalore),
            createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
            followupAt: m['followup_at'] != null
                ? DateTime.parse(m['followup_at'] as String).toLocal()
                : null,
          )).toList();

      final logs = (logsData as List).map((m) => CallLogSummary(
            leadId: m['lead_id'] as String,
            calledBy: m['called_by'] as String? ?? '',
            calledAt: DateTime.parse(m['called_at'] as String).toLocal(),
            durationSeconds: m['duration_seconds'] as int? ?? 0,
            outcome: CallOutcome.values.firstWhere(
                (o) => o.name == m['outcome'],
                orElse: () => CallOutcome.callback),
          )).toList();

      state = AnalyticsData(leads: leads, callLogs: logs, isLoading: false);
    } catch (_) {
      if (mounted) state = AnalyticsData(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = AnalyticsData(leads: state.leads, callLogs: state.callLogs, isLoading: true);
    await _load();
  }
}

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, AnalyticsData>(
  (ref) => AnalyticsNotifier(),
);
