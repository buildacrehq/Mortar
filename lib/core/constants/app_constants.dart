class AppConstants {
  // App name — change here to rename across the entire app
  static const appName = 'Mortar';
  static const shortCallThresholdSeconds = 30;
  static const quotationFollowupDays = 3;

  // Mortar backend on Vercel
  static const backendUrl = 'https://mortar-seven.vercel.app';

  // Exotel trial ExoPhone
  static const exotelPhone = '08047285622';
}

enum UserRole { telecaller, manager, admin }

enum LeadSource { facebook, instagram, website, phone, whatsapp, referral }

enum LeadStage {
  enquiryReceived,
  telecallerCallDone,
  meetingAtOffice,
  siteVisit,
  quotationSent,
  negotiation,
  finalAgreement,
  lost,
  future,
}

enum ServiceType { construction, renovation, interiors }

enum City { bangalore, mysore }

enum CallOutcome { interested, notInterested, callback, notReachable, future }

enum FutureTag { hot, warm, cool, longTerm }

enum KhataType { aKhata, bKhata, bda, bmrda, panchayat, other }

enum PlanningTimeline { immediate, within3Months, within6Months, withinYear }

enum LostReason {
  priceTooHigh,
  wentWithCompetitor,
  nobudget,
  projectOnHold,
  notInterested,
  noResponse,
  invalidLead,
  other,
}

extension LeadStageExt on LeadStage {
  String get label {
    switch (this) {
      case LeadStage.enquiryReceived:   return 'Enquiry';
      case LeadStage.telecallerCallDone: return 'Called';
      case LeadStage.meetingAtOffice:   return 'Meeting';
      case LeadStage.siteVisit:         return 'Site Visit';
      case LeadStage.quotationSent:     return 'Quotation';
      case LeadStage.negotiation:       return 'Negotiation';
      case LeadStage.finalAgreement:    return 'Won';
      case LeadStage.lost:              return 'Lost';
      case LeadStage.future:            return 'Future';
    }
  }

  int get step {
    const order = [
      LeadStage.enquiryReceived,
      LeadStage.telecallerCallDone,
      LeadStage.meetingAtOffice,
      LeadStage.siteVisit,
      LeadStage.quotationSent,
      LeadStage.negotiation,
      LeadStage.finalAgreement,
    ];
    return order.indexOf(this) + 1;
  }
}

extension LeadSourceExt on LeadSource {
  String get label {
    switch (this) {
      case LeadSource.facebook:   return 'Facebook';
      case LeadSource.instagram:  return 'Instagram';
      case LeadSource.website:    return 'Website';
      case LeadSource.phone:      return 'Phone';
      case LeadSource.whatsapp:   return 'WhatsApp';
      case LeadSource.referral:   return 'Referral';
    }
  }
}

extension ServiceTypeExt on ServiceType {
  String get label {
    switch (this) {
      case ServiceType.construction: return 'Construction';
      case ServiceType.renovation:   return 'Renovation';
      case ServiceType.interiors:    return 'Interiors';
    }
  }
}

extension CityExt on City {
  String get label {
    switch (this) {
      case City.bangalore: return 'Bangalore';
      case City.mysore:    return 'Mysore';
    }
  }
}

extension CallOutcomeExt on CallOutcome {
  String get label {
    switch (this) {
      case CallOutcome.interested:    return 'Interested';
      case CallOutcome.notInterested: return 'Not Interested';
      case CallOutcome.callback:      return 'Callback';
      case CallOutcome.notReachable:  return 'Not Reachable';
      case CallOutcome.future:        return 'Future Client';
    }
  }
}

extension FutureTagExt on FutureTag {
  String get label {
    switch (this) {
      case FutureTag.hot:      return 'Hot';
      case FutureTag.warm:     return 'Warm';
      case FutureTag.cool:     return 'Cool';
      case FutureTag.longTerm: return 'Long Term';
    }
  }

  String get description {
    switch (this) {
      case FutureTag.hot:      return 'Follow up in 2–4 weeks';
      case FutureTag.warm:     return 'Follow up in 1–3 months';
      case FutureTag.cool:     return 'Follow up in 3–6 months';
      case FutureTag.longTerm: return 'Follow up in 6+ months';
    }
  }
}

extension LostReasonExt on LostReason {
  String get label {
    switch (this) {
      case LostReason.priceTooHigh:       return 'Price Too High';
      case LostReason.wentWithCompetitor: return 'Went with Competitor';
      case LostReason.nobudget:           return 'No Budget Right Now';
      case LostReason.projectOnHold:      return 'Project on Hold';
      case LostReason.notInterested:      return 'Not Interested';
      case LostReason.noResponse:         return 'No Response / Ghosted';
      case LostReason.invalidLead:        return 'Invalid / Wrong Number';
      case LostReason.other:              return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case LostReason.priceTooHigh:       return '💰';
      case LostReason.wentWithCompetitor: return '🏃';
      case LostReason.nobudget:           return '🪙';
      case LostReason.projectOnHold:      return '⏸️';
      case LostReason.notInterested:      return '👎';
      case LostReason.noResponse:         return '🔇';
      case LostReason.invalidLead:        return '❌';
      case LostReason.other:              return '📝';
    }
  }
}

extension KhataTypeExt on KhataType {
  String get label {
    switch (this) {
      case KhataType.aKhata:   return 'A Khata';
      case KhataType.bKhata:   return 'B Khata';
      case KhataType.bda:      return 'BDA';
      case KhataType.bmrda:    return 'BMRDA';
      case KhataType.panchayat: return 'Panchayat';
      case KhataType.other:    return 'Others';
    }
  }

  String get description {
    switch (this) {
      case KhataType.aKhata:   return 'BBMP approved — easy permits';
      case KhataType.bKhata:   return 'Needs regularization';
      case KhataType.bda:      return 'BDA layout';
      case KhataType.bmrda:    return 'BMRDA layout';
      case KhataType.panchayat: return 'Outside municipal limits';
      case KhataType.other:    return 'Other / Unknown';
    }
  }

  // Color coding — green for easiest, amber for moderate, red/grey for complex
  bool get isQuickStart => this == KhataType.aKhata || this == KhataType.bda;
}

extension PlanningTimelineExt on PlanningTimeline {
  String get label {
    switch (this) {
      case PlanningTimeline.immediate:      return 'Immediate';
      case PlanningTimeline.within3Months:  return 'Within 3 Months';
      case PlanningTimeline.within6Months:  return 'Within 6 Months';
      case PlanningTimeline.withinYear:     return 'Within a Year';
    }
  }

  String get emoji {
    switch (this) {
      case PlanningTimeline.immediate:      return '🔥';
      case PlanningTimeline.within3Months:  return '📅';
      case PlanningTimeline.within6Months:  return '🗓️';
      case PlanningTimeline.withinYear:     return '⏳';
    }
  }

  bool get isUrgent => this == PlanningTimeline.immediate;
}
