import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/services/leads_service.dart';
import 'package:buildacre_crm/main.dart';

final _service = LeadsService();

class _LeadListNotifier extends StateNotifier<List<Lead>> {
  _LeadListNotifier(this._fetch, {String? realtimeChannel}) : super([]) {
    refresh();
    if (realtimeChannel != null) _subscribe(realtimeChannel);
  }

  final Future<List<Lead>> Function() _fetch;
  Timer? _debounce;

  void _subscribe(String channel) {
    supabase
        .channel(channel)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leads',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();
  }

  void _debouncedRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), refresh);
  }

  Future<void> refresh() async {
    try {
      final data = await _fetch();
      if (mounted) state = data;
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final lostLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(
    () => _service.fetchByStage(LeadStage.lost),
    realtimeChannel: 'lost_leads_rt',
  ),
);

final futurePipelineLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(
    _service.fetchFuturePipeline,
    realtimeChannel: 'future_leads_rt',
  ),
);

final calendarLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(
    _service.fetchWithFollowups,
    realtimeChannel: 'calendar_leads_rt',
  ),
);

final unassignedLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(
    _service.fetchUnassigned,
    realtimeChannel: 'unassigned_leads_rt',
  ),
);

final allOverdueLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(
    () async {
      final data = await _service.fetchWithFollowups();
      final now = DateTime.now();
      return data
          .where((l) =>
              l.followupAt != null &&
              l.followupAt!.isBefore(now) &&
              l.stage != LeadStage.lost &&
              l.stage != LeadStage.finalAgreement)
          .toList()
        ..sort((a, b) => a.followupAt!.compareTo(b.followupAt!));
    },
    realtimeChannel: 'overdue_leads_rt',
  ),
);

final kanbanLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(
    () => _service.fetchByStages([
      LeadStage.enquiryReceived,
      LeadStage.telecallerCallDone,
      LeadStage.meetingAtOffice,
      LeadStage.siteVisit,
      LeadStage.quotationSent,
      LeadStage.negotiation,
      LeadStage.finalAgreement,
    ]),
    realtimeChannel: 'kanban_leads_rt',
  ),
);
