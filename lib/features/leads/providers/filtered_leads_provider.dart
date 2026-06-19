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
