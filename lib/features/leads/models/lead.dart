import 'package:buildacre_crm/core/constants/app_constants.dart';

class LeadNote {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const LeadNote({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });
}

class Lead {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final LeadSource source;
  final ServiceType serviceType;
  final City city;
  final LeadStage stage;
  final String? area;
  final String? plotSize;
  final String? budget;
  final String? notes;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime? lastContactedAt;
  final DateTime? followupAt;
  final CallOutcome? lastOutcome;
  final FutureTag? futureTag;
  final LostReason? lostReason;
  final KhataType? khataType;
  final PlanningTimeline? planningTimeline;
  final List<CallLog> callLogs;
  final List<LeadNote> internalNotes;

  const Lead({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.source,
    required this.serviceType,
    required this.city,
    required this.stage,
    this.area,
    this.plotSize,
    this.budget,
    this.notes,
    required this.assignedTo,
    required this.createdAt,
    this.lastContactedAt,
    this.followupAt,
    this.lastOutcome,
    this.futureTag,
    this.lostReason,
    this.khataType,
    this.planningTimeline,
    this.callLogs = const [],
    this.internalNotes = const [],
  });

  String get maskedPhone {
    if (phone.length < 6) return '••••• •••••';
    return '${phone.substring(0, 5)} •••••';
  }

  bool get hasOverdueFollowup {
    if (followupAt == null) return false;
    return followupAt!.isBefore(DateTime.now());
  }

  Lead copyWith({
    LeadStage? stage,
    String? notes,
    DateTime? followupAt,
    CallOutcome? lastOutcome,
    FutureTag? futureTag,
    LostReason? lostReason,
    KhataType? khataType,
    PlanningTimeline? planningTimeline,
    List<CallLog>? callLogs,
    List<LeadNote>? internalNotes,
    DateTime? lastContactedAt,
    String? assignedTo,
  }) {
    return Lead(
      id: id,
      name: name,
      phone: phone,
      email: email,
      source: source,
      serviceType: serviceType,
      city: city,
      stage: stage ?? this.stage,
      area: area,
      plotSize: plotSize,
      budget: budget,
      notes: notes ?? this.notes,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      followupAt: followupAt ?? this.followupAt,
      lastOutcome: lastOutcome ?? this.lastOutcome,
      futureTag: futureTag ?? this.futureTag,
      lostReason: lostReason ?? this.lostReason,
      khataType: khataType ?? this.khataType,
      planningTimeline: planningTimeline ?? this.planningTimeline,
      callLogs: callLogs ?? this.callLogs,
      internalNotes: internalNotes ?? this.internalNotes,
    );
  }
}

class CallLog {
  final String id;
  final DateTime calledAt;
  final int durationSeconds;
  final CallOutcome outcome;
  final String? notes;
  final String? recordingUrl;

  const CallLog({
    required this.id,
    required this.calledAt,
    required this.durationSeconds,
    required this.outcome,
    this.notes,
    this.recordingUrl,
  });

  bool get isSuspiciouslyShort =>
      durationSeconds < AppConstants.shortCallThresholdSeconds;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m}m ${s}s';
  }
}
