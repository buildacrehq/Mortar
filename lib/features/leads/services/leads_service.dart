import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/main.dart';

// ─── Mappers ─────────────────────────────────────────────────────────────────

Lead leadFromMap(Map<String, dynamic> m) {
  return Lead(
    id: m['id'] as String,
    name: m['name'] as String,
    phone: m['phone'] as String,
    email: m['email'] as String?,
    source: _src(m['source'] as String),
    serviceType: _svc(m['service_type'] as String),
    city: _city(m['city'] as String),
    stage: _stage(m['stage'] as String),
    area: m['area'] as String?,
    plotSize: m['plot_size'] as String?,
    budget: m['budget'] as String?,
    notes: m['notes'] as String?,
    assignedTo: m['assigned_to'] as String? ?? '',
    lastOutcome: m['last_outcome'] != null ? _outcome(m['last_outcome'] as String) : null,
    followupAt: m['followup_at'] != null ? DateTime.parse(m['followup_at'] as String).toLocal() : null,
    futureTag: m['future_tag'] != null ? _futureTag(m['future_tag'] as String) : null,
    lostReason: m['lost_reason'] != null ? _lostReason(m['lost_reason'] as String) : null,
    khataType: m['khata_type'] != null ? _khata(m['khata_type'] as String) : null,
    planningTimeline: m['planning_timeline'] != null ? _timeline(m['planning_timeline'] as String) : null,
    lastContactedAt: m['last_contacted_at'] != null ? DateTime.parse(m['last_contacted_at'] as String).toLocal() : null,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    callLogs: (m['call_logs'] as List<dynamic>? ?? [])
        .map((c) => _callLogFromMap(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.calledAt.compareTo(b.calledAt)),
    internalNotes: (m['lead_notes'] as List<dynamic>? ?? [])
        .map((n) => _noteFromMap(n as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
  );
}

Map<String, dynamic> leadToMap(Lead l) => {
      'name': l.name,
      'phone': l.phone,
      if (l.email != null) 'email': l.email,
      'source': l.source.name,
      'service_type': l.serviceType.name,
      'city': l.city.name,
      'stage': l.stage.name,
      if (l.area != null) 'area': l.area,
      if (l.plotSize != null) 'plot_size': l.plotSize,
      if (l.budget != null) 'budget': l.budget,
      if (l.notes != null) 'notes': l.notes,
      if (l.assignedTo.isNotEmpty) 'assigned_to': l.assignedTo,
      if (l.lastOutcome != null) 'last_outcome': l.lastOutcome!.name,
      if (l.followupAt != null) 'followup_at': l.followupAt!.toUtc().toIso8601String(),
      if (l.futureTag != null) 'future_tag': l.futureTag!.name,
      if (l.lostReason != null) 'lost_reason': l.lostReason!.name,
      if (l.khataType != null) 'khata_type': l.khataType!.name,
      if (l.planningTimeline != null) 'planning_timeline': l.planningTimeline!.name,
      if (l.lastContactedAt != null) 'last_contacted_at': l.lastContactedAt!.toUtc().toIso8601String(),
    };

CallLog _callLogFromMap(Map<String, dynamic> m) => CallLog(
      id: m['id'] as String,
      calledAt: DateTime.parse(m['called_at'] as String).toLocal(),
      durationSeconds: m['duration_seconds'] as int? ?? 0,
      outcome: _outcome(m['outcome'] as String),
      notes: m['notes'] as String?,
      recordingUrl: m['recording_url'] as String?,
    );

LeadNote _noteFromMap(Map<String, dynamic> m) => LeadNote(
      id: m['id'] as String,
      authorId: m['author_id'] as String? ?? '',
      authorName: m['author_name'] as String,
      text: m['text'] as String,
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    );

// ─── Supabase operations ──────────────────────────────────────────────────────

const _pageSize = 25;

class LeadsService {
  /// Fetch a page of leads. Returns list and whether more pages exist.
  Future<({List<Lead> leads, bool hasMore})> fetchPage(int page) async {
    final from = page * _pageSize;
    final to = from + _pageSize - 1;
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .order('created_at', ascending: false)
        .range(from, to);
    final leads = (data as List).map((m) => leadFromMap(m as Map<String, dynamic>)).toList();
    return (leads: leads, hasMore: leads.length == _pageSize);
  }

  /// Fetch all leads — used for stats/performance screens only.
  Future<List<Lead>> fetchAll() async {
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .order('created_at', ascending: false);
    return (data as List).map((m) => leadFromMap(m as Map<String, dynamic>)).toList();
  }

  /// Fetch leads by stage — for Lost Leads screen.
  Future<List<Lead>> fetchByStage(LeadStage stage) async {
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .eq('stage', stage.name)
        .order('last_contacted_at', ascending: false);
    return (data as List).map((m) => leadFromMap(m as Map<String, dynamic>)).toList();
  }

  /// Fetch future pipeline leads — has futureTag set.
  Future<List<Lead>> fetchFuturePipeline() async {
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .not('future_tag', 'is', null)
        .order('followup_at', ascending: true);
    return (data as List).map((m) => leadFromMap(m as Map<String, dynamic>)).toList();
  }

  /// Fetch leads with upcoming follow-ups for calendar view.
  Future<List<Lead>> fetchWithFollowups() async {
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .not('followup_at', 'is', null)
        .order('followup_at', ascending: true);
    return (data as List).map((m) => leadFromMap(m as Map<String, dynamic>)).toList();
  }

  /// Fetch unassigned leads for assignment screen.
  Future<List<Lead>> fetchUnassigned() async {
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .or('assigned_to.is.null,assigned_to.eq.')
        .not('stage', 'in', '("lost","finalAgreement")')
        .order('created_at', ascending: false);
    return (data as List).map((m) => leadFromMap(m as Map<String, dynamic>)).toList();
  }

  /// Server-side search — searches name, phone, area across ALL leads.
  Future<List<Lead>> search(String query) async {
    if (query.trim().length < 2) return [];
    final q = query.trim().toLowerCase();
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .or('name.ilike.%$q%,phone.ilike.%$q%,area.ilike.%$q%,email.ilike.%$q%,budget.ilike.%$q%,notes.ilike.%$q%')
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((m) => leadFromMap(m as Map<String, dynamic>)).toList();
  }

  Future<Lead> fetchOne(String id) async {
    final data = await supabase
        .from('leads')
        .select('*, call_logs(*), lead_notes(*)')
        .eq('id', id)
        .single();
    return leadFromMap(data as Map<String, dynamic>);
  }

  Future<Lead> insert(Lead lead) async {
    final data = await supabase
        .from('leads')
        .insert(leadToMap(lead))
        .select('*, call_logs(*), lead_notes(*)')
        .single();
    return leadFromMap(data as Map<String, dynamic>);
  }

  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    await supabase.from('leads').update(fields).eq('id', id);
  }

  Future<void> insertCallLog({
    required String leadId,
    required String calledBy,
    required int durationSeconds,
    required CallOutcome outcome,
    String? notes,
  }) async {
    await supabase.from('call_logs').insert({
      'lead_id': leadId,
      'called_by': calledBy.isNotEmpty ? calledBy : null,
      'duration_seconds': durationSeconds,
      'outcome': outcome.name,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> insertNote({
    required String leadId,
    required String authorId,
    required String authorName,
    required String text,
  }) async {
    await supabase.from('lead_notes').insert({
      'lead_id': leadId,
      'author_id': authorId.isNotEmpty ? authorId : null,
      'author_name': authorName,
      'text': text,
    });
  }
}

// ─── Enum parsers ─────────────────────────────────────────────────────────────

LeadSource _src(String s) =>
    LeadSource.values.firstWhere((e) => e.name == s, orElse: () => LeadSource.phone);

ServiceType _svc(String s) =>
    ServiceType.values.firstWhere((e) => e.name == s, orElse: () => ServiceType.construction);

City _city(String s) =>
    City.values.firstWhere((e) => e.name == s, orElse: () => City.bangalore);

LeadStage _stage(String s) =>
    LeadStage.values.firstWhere((e) => e.name == s, orElse: () => LeadStage.enquiryReceived);

CallOutcome _outcome(String s) =>
    CallOutcome.values.firstWhere((e) => e.name == s, orElse: () => CallOutcome.callback);

FutureTag _futureTag(String s) =>
    FutureTag.values.firstWhere((e) => e.name == s, orElse: () => FutureTag.warm);

LostReason _lostReason(String s) =>
    LostReason.values.firstWhere((e) => e.name == s, orElse: () => LostReason.other);

KhataType _khata(String s) =>
    KhataType.values.firstWhere((e) => e.name == s, orElse: () => KhataType.other);

PlanningTimeline _timeline(String s) =>
    PlanningTimeline.values.firstWhere((e) => e.name == s, orElse: () => PlanningTimeline.withinYear);
