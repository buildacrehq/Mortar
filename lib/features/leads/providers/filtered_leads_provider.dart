import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/services/leads_service.dart';

final _service = LeadsService();

// ─── Lost Leads (stage = lost) ────────────────────────────────────────────────

class _LeadListNotifier extends StateNotifier<List<Lead>> {
  _LeadListNotifier(this._fetch) : super([]) {
    refresh();
  }

  final Future<List<Lead>> Function() _fetch;
  bool _loading = true;

  bool get isLoading => _loading;

  Future<void> refresh() async {
    _loading = true;
    try {
      final data = await _fetch();
      if (mounted) {
        state = data;
        _loading = false;
      }
    } catch (_) {
      if (mounted) _loading = false;
    }
  }
}

final lostLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(() => _service.fetchByStage(LeadStage.lost)),
);

final futurePipelineLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(_service.fetchFuturePipeline),
);

final calendarLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(_service.fetchWithFollowups),
);

final unassignedLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(_service.fetchUnassigned),
);

/// All overdue follow-up leads — for dashboard overdue list widget.
final allOverdueLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(() async {
    final data = await _service.fetchWithFollowups();
    final now = DateTime.now();
    return data.where((l) =>
        l.followupAt != null &&
        l.followupAt!.isBefore(now) &&
        l.stage != LeadStage.lost &&
        l.stage != LeadStage.finalAgreement).toList()
      ..sort((a, b) => a.followupAt!.compareTo(b.followupAt!));
  }),
);

/// All active pipeline leads for kanban — fetches all stages except lost/future.
final kanbanLeadsProvider =
    StateNotifierProvider<_LeadListNotifier, List<Lead>>(
  (ref) => _LeadListNotifier(() => _service.fetchByStages([
        LeadStage.enquiryReceived,
        LeadStage.telecallerCallDone,
        LeadStage.meetingAtOffice,
        LeadStage.siteVisit,
        LeadStage.quotationSent,
        LeadStage.negotiation,
        LeadStage.finalAgreement,
      ])),
);
