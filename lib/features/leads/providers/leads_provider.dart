import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/models/mock_data.dart';

class LeadsNotifier extends StateNotifier<List<Lead>> {
  LeadsNotifier() : super(mockLeads);

  Lead? getById(String id) {
    try {
      return state.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  void addLead({
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
  }) {
    final lead = Lead(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      assignedTo: 'tc_1', // TODO: replace with logged-in user ID
      createdAt: DateTime.now(),
    );
    state = [lead, ...state];
  }

  void updateStage(String id, LeadStage stage, {LostReason? lostReason}) {
    state = [
      for (final lead in state)
        if (lead.id == id)
          lead.copyWith(stage: stage, lostReason: lostReason)
        else
          lead,
    ];
  }

  void updateLead({
    required String id,
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
  }) {
    state = [
      for (final lead in state)
        if (lead.id == id)
          Lead(
            id: lead.id,
            name: name,
            phone: phone,
            email: email,
            source: source,
            serviceType: serviceType,
            city: city,
            stage: lead.stage,
            area: area,
            plotSize: plotSize,
            budget: budget,
            notes: notes,
            assignedTo: lead.assignedTo,
            createdAt: lead.createdAt,
            lastContactedAt: lead.lastContactedAt,
            followupAt: lead.followupAt,
            lastOutcome: lead.lastOutcome,
            futureTag: lead.futureTag,
            callLogs: lead.callLogs,
          )
        else
          lead,
    ];
  }

  void assignLead(String id, String telecallerId) {
    state = [
      for (final lead in state)
        if (lead.id == id) lead.copyWith(assignedTo: telecallerId) else lead,
    ];
  }

  void logCall({
    required String leadId,
    required int durationSeconds,
    required CallOutcome outcome,
    String? notes,
    DateTime? followupAt,
    FutureTag? futureTag,
  }) {
    final log = CallLog(
      id: 'cl_${DateTime.now().millisecondsSinceEpoch}',
      calledAt: DateTime.now(),
      durationSeconds: durationSeconds,
      outcome: outcome,
      notes: notes,
    );

    LeadStage? newStage;
    if (outcome == CallOutcome.interested) {
      newStage = LeadStage.telecallerCallDone;
    } else if (outcome == CallOutcome.notInterested) {
      newStage = LeadStage.lost;
    } else if (outcome == CallOutcome.future) {
      newStage = LeadStage.future;
    }

    state = [
      for (final lead in state)
        if (lead.id == leadId)
          lead.copyWith(
            stage: newStage ?? lead.stage,
            lastOutcome: outcome,
            lastContactedAt: DateTime.now(),
            followupAt: followupAt,
            futureTag: futureTag,
            notes: notes != null
                ? (lead.notes != null ? '${lead.notes}\n\n$notes' : notes)
                : lead.notes,
            callLogs: [...lead.callLogs, log],
          )
        else
          lead,
    ];
  }

  void addNote(String leadId, String authorId, String authorName, String text) {
    final note = LeadNote(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      authorId: authorId,
      authorName: authorName,
      text: text,
      createdAt: DateTime.now(),
    );
    state = [
      for (final lead in state)
        if (lead.id == leadId)
          lead.copyWith(internalNotes: [...lead.internalNotes, note])
        else
          lead,
    ];
  }
}

final leadsProvider = StateNotifierProvider<LeadsNotifier, List<Lead>>(
  (ref) => LeadsNotifier(),
);

final leadByIdProvider = Provider.family<Lead?, String>((ref, id) {
  return ref.watch(leadsProvider.notifier).getById(id);
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
