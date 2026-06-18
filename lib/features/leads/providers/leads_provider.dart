import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/services/leads_service.dart';
import 'package:buildacre_crm/main.dart';

final _service = LeadsService();

// Tracks whether the initial load is in progress
final leadsLoadingProvider = StateProvider<bool>((ref) => true);

// Tracks load error message
final leadsErrorProvider = StateProvider<String?>((ref) => null);

class LeadsNotifier extends StateNotifier<List<Lead>> {
  LeadsNotifier(this._ref) : super([]) {
    _load();
    _subscribeRealtime();
  }

  final Ref _ref;

  // ─── Load ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    _ref.read(leadsErrorProvider.notifier).state = null;
    try {
      final leads = await _service.fetchAll();
      if (mounted) {
        state = leads;
        _ref.read(leadsLoadingProvider.notifier).state = false;
      }
    } catch (e) {
      if (mounted) {
        _ref.read(leadsLoadingProvider.notifier).state = false;
        _ref.read(leadsErrorProvider.notifier).state =
            'Could not connect to server. Check your internet connection.';
      }
    }
  }

  Future<void> refresh() async {
    _ref.read(leadsLoadingProvider.notifier).state = true;
    _ref.read(leadsErrorProvider.notifier).state = null;
    await _load();
  }

  void _subscribeRealtime() {
    supabase
        .channel('leads_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leads',
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'call_logs',
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lead_notes',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ─── Local helper ─────────────────────────────────────────────────────────

  Lead? getById(String id) {
    try {
      return state.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  void _updateLocal(String id, Lead Function(Lead) updater) {
    state = [for (final l in state) if (l.id == id) updater(l) else l];
  }

  // ─── Add Lead ─────────────────────────────────────────────────────────────

  Future<void> addLead({
    required String name,
    required String phone,
    String? email,
    required LeadSource source,
    required ServiceType serviceType,
    required City city,
    String? area,
    String? plotSize,
    String? budget,
    String? notes,
    String? assignedTo,
    KhataType? khataType,
    PlanningTimeline? planningTimeline,
  }) async {
    final lead = Lead(
      id: '',
      name: name,
      phone: phone,
      email: email,
      source: source,
      serviceType: serviceType,
      city: city,
      stage: LeadStage.enquiryReceived,
      area: area,
      plotSize: plotSize,
      budget: budget,
      notes: notes,
      assignedTo: assignedTo ?? '',
      khataType: khataType,
      planningTimeline: planningTimeline,
      createdAt: DateTime.now(),
    );
    try {
      final saved = await _service.insert(lead);
      state = [saved, ...state];
    } catch (_) {}
  }

  // ─── Update Stage ─────────────────────────────────────────────────────────

  Future<void> updateStage(String id, LeadStage stage, {LostReason? lostReason}) async {
    _updateLocal(id, (l) => l.copyWith(stage: stage, lostReason: lostReason));
    try {
      await _service.updateFields(id, {
        'stage': stage.name,
        if (lostReason != null) 'lost_reason': lostReason.name,
      });
    } catch (_) {
      await _load();
    }
  }

  // ─── Update Lead (full edit) ───────────────────────────────────────────────

  Future<void> updateLead({
    required String id,
    required String name,
    required String phone,
    String? email,
    required LeadSource source,
    required ServiceType serviceType,
    required City city,
    required LeadStage stage,
    String? area,
    String? plotSize,
    String? budget,
    String? notes,
    KhataType? khataType,
    PlanningTimeline? planningTimeline,
  }) async {
    _updateLocal(
      id,
      (l) => Lead(
        id: l.id,
        name: name,
        phone: phone,
        email: email,
        source: source,
        serviceType: serviceType,
        city: city,
        stage: stage,
        area: area,
        plotSize: plotSize,
        budget: budget,
        notes: notes,
        assignedTo: l.assignedTo,
        createdAt: l.createdAt,
        lastContactedAt: l.lastContactedAt,
        followupAt: l.followupAt,
        lastOutcome: l.lastOutcome,
        futureTag: l.futureTag,
        lostReason: l.lostReason,
        khataType: khataType ?? l.khataType,
        planningTimeline: planningTimeline ?? l.planningTimeline,
        callLogs: l.callLogs,
        internalNotes: l.internalNotes,
      ),
    );
    try {
      await _service.updateFields(id, {
        'name': name,
        'phone': phone,
        'email': email,
        'source': source.name,
        'service_type': serviceType.name,
        'city': city.name,
        'stage': stage.name,
        if (area != null) 'area': area,
        if (plotSize != null) 'plot_size': plotSize,
        if (budget != null) 'budget': budget,
        if (notes != null) 'notes': notes,
        'khata_type': khataType?.name,
        'planning_timeline': planningTimeline?.name,
      });
    } catch (_) {
      await _load();
    }
  }

  // ─── Assign Lead ──────────────────────────────────────────────────────────

  Future<void> assignLead(String id, String telecallerId) async {
    _updateLocal(id, (l) => l.copyWith(assignedTo: telecallerId));
    try {
      await _service.updateFields(id, {
        'assigned_to': telecallerId.isNotEmpty ? telecallerId : null,
      });
    } catch (_) {
      await _load();
    }
  }

  // ─── Update Planning Timeline ─────────────────────────────────────────────

  Future<void> updatePlanningTimeline(String id, PlanningTimeline? timeline) async {
    _updateLocal(id, (l) => l.copyWith(planningTimeline: timeline));
    try {
      await _service.updateFields(id, {'planning_timeline': timeline?.name});
    } catch (_) {
      await _load();
    }
  }

  // ─── Update Khata ─────────────────────────────────────────────────────────

  Future<void> updateKhata(String id, KhataType? khataType) async {
    _updateLocal(id, (l) => l.copyWith(khataType: khataType));
    try {
      await _service.updateFields(id, {
        'khata_type': khataType?.name,
      });
    } catch (_) {
      await _load();
    }
  }

  // ─── Log Call ─────────────────────────────────────────────────────────────

  Future<void> logCall({
    required String leadId,
    required int durationSeconds,
    required CallOutcome outcome,
    String? notes,
    DateTime? followupAt,
    FutureTag? futureTag,
  }) async {
    final log = CallLog(
      id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      calledAt: DateTime.now(),
      durationSeconds: durationSeconds,
      outcome: outcome,
      notes: notes,
    );

    LeadStage? newStage;
    if (outcome == CallOutcome.interested) newStage = LeadStage.telecallerCallDone;
    if (outcome == CallOutcome.notInterested) newStage = LeadStage.lost;
    if (outcome == CallOutcome.future) newStage = LeadStage.future;

    // Optimistic local update
    _updateLocal(leadId, (l) => l.copyWith(
          stage: newStage ?? l.stage,
          lastOutcome: outcome,
          lastContactedAt: DateTime.now(),
          followupAt: followupAt,
          futureTag: futureTag,
          callLogs: [...l.callLogs, log],
        ));

    // Write to Supabase
    final userId = supabase.auth.currentUser?.id ?? '';
    try {
      await _service.insertCallLog(
        leadId: leadId,
        calledBy: userId,
        durationSeconds: durationSeconds,
        outcome: outcome,
        notes: notes,
      );
      await _service.updateFields(leadId, {
        if (newStage != null) 'stage': newStage.name,
        'last_outcome': outcome.name,
        'last_contacted_at': DateTime.now().toUtc().toIso8601String(),
        if (followupAt != null) 'followup_at': followupAt.toUtc().toIso8601String(),
        if (futureTag != null) 'future_tag': futureTag.name,
      });
      // Reload to get real DB id for the call log
      await _load();
    } catch (_) {
      await _load();
    }
  }

  // ─── Add Note ─────────────────────────────────────────────────────────────

  Future<void> addNote(
      String leadId, String authorId, String authorName, String text) async {
    final note = LeadNote(
      id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
      authorId: authorId,
      authorName: authorName,
      text: text,
      createdAt: DateTime.now(),
    );
    _updateLocal(leadId, (l) => l.copyWith(internalNotes: [...l.internalNotes, note]));
    try {
      await _service.insertNote(
        leadId: leadId,
        authorId: authorId,
        authorName: authorName,
        text: text,
      );
    } catch (_) {
      await _load();
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final leadsProvider = StateNotifierProvider<LeadsNotifier, List<Lead>>(
  (ref) => LeadsNotifier(ref),
);

final leadByIdProvider = Provider.family<Lead?, String>((ref, id) {
  final leads = ref.watch(leadsProvider);
  try {
    return leads.firstWhere((l) => l.id == id);
  } catch (_) {
    return null; // Lead not found — caller handles null
  }
});

final todayLeadsCountProvider = Provider<int>((ref) {
  final leads = ref.watch(leadsProvider);
  final today = DateTime.now();
  return leads
      .where((l) =>
          l.createdAt.year == today.year &&
          l.createdAt.month == today.month &&
          l.createdAt.day == today.day)
      .length;
});

final overdueLeadsProvider = Provider<List<Lead>>((ref) {
  final leads = ref.watch(leadsProvider);
  return leads.where((l) => l.hasOverdueFollowup).toList();
});
