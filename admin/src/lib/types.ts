export type LeadStage =
  | "enquiryReceived"
  | "telecallerCallDone"
  | "meetingAtOffice"
  | "siteVisit"
  | "quotationSent"
  | "negotiation"
  | "finalAgreement"
  | "lost"
  | "future";

export type LeadSource = "facebook" | "instagram" | "website" | "phone" | "whatsapp" | "referral";
export type City = "bangalore" | "mysore";
export type CallOutcome = "interested" | "notInterested" | "callback" | "notReachable" | "future";
export type UserRole = "telecaller" | "manager" | "admin";
export type ServiceType = "construction" | "renovation" | "interiors";
export type FutureTag = "hot" | "warm" | "cool" | "longTerm";
export type KhataType = "aKhata" | "bKhata" | "bda" | "bmrda" | "panchayat" | "other";
export type PlanningTimeline = "immediate" | "within3Months" | "within6Months" | "withinYear";
export type LostReason =
  | "priceTooHigh"
  | "wentWithCompetitor"
  | "nobudget"
  | "projectOnHold"
  | "notInterested"
  | "noResponse"
  | "invalidLead"
  | "other";
export type AssignmentStrategy =
  | "linear"
  | "reverse"
  | "performance"
  | "weighted"
  | "random"
  | "manual";

export type Profile = {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  city: City | null;
  phone: string | null;
  is_active: boolean;
};

export type Lead = {
  id: string;
  name: string;
  phone: string;
  email: string | null;
  source: LeadSource;
  service_type: ServiceType;
  city: City;
  stage: LeadStage;
  area: string | null;
  plot_size: string | null;
  budget: string | null;
  notes: string | null;
  assigned_to: string | null;
  last_outcome: CallOutcome | null;
  followup_at: string | null;
  future_tag: FutureTag | null;
  lost_reason: LostReason | null;
  khata_type: KhataType | null;
  planning_timeline: PlanningTimeline | null;
  last_contacted_at: string | null;
  created_at: string;
  updated_at: string;
};

export type CallLog = {
  id: string;
  lead_id: string;
  called_by: string | null;
  called_at: string;
  duration_seconds: number;
  outcome: CallOutcome;
  notes: string | null;
};

// Lightweight subsets for analytics — mirrors analytics_provider.dart's
// LeadSummary/CallLogSummary, which avoid fetching nested call_logs/notes
// for every lead just to compute counts.
export type LeadSummary = {
  id: string;
  assigned_to: string | null;
  stage: LeadStage;
  source: LeadSource;
  service_type: ServiceType;
  city: City;
  created_at: string;
  followup_at: string | null;
};

export type CallLogSummary = {
  lead_id: string;
  called_by: string | null;
  called_at: string;
  duration_seconds: number;
  outcome: CallOutcome;
};

export type LeadNote = {
  id: string;
  lead_id: string;
  author_name: string;
  text: string;
  created_at: string;
};

// Shared shape for the Add/Edit lead form — everything except stage and
// assignment, which have their own dedicated controls elsewhere.
export type LeadFormInput = {
  name: string;
  phone: string;
  email: string;
  source: LeadSource;
  service_type: ServiceType;
  city: City;
  area: string;
  plot_size: string;
  budget: string;
  notes: string;
  khata_type: KhataType | "";
  planning_timeline: PlanningTimeline | "";
};
