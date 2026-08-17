import type {
  LeadStage,
  LeadSource,
  City,
  CallOutcome,
  ServiceType,
  FutureTag,
  KhataType,
  PlanningTimeline,
  LostReason,
  AssignmentStrategy,
} from "./types";

// Order matters — mirrors the pipeline sequence, `lost`/`future` are side-branches.
export const STAGE_ORDER: LeadStage[] = [
  "enquiryReceived",
  "telecallerCallDone",
  "meetingAtOffice",
  "siteVisit",
  "quotationSent",
  "negotiation",
  "finalAgreement",
  "lost",
  "future",
];

export const STAGE_LABEL: Record<LeadStage, string> = {
  enquiryReceived: "Enquiry",
  telecallerCallDone: "Called",
  meetingAtOffice: "Meeting",
  siteVisit: "Site Visit",
  quotationSent: "Quotation",
  negotiation: "Negotiation",
  finalAgreement: "Won",
  lost: "Lost",
  future: "Future",
};

// Matches lib/core/theme/app_theme.dart AppColors.stage* for visual consistency with the mobile app.
export const STAGE_COLOR: Record<LeadStage, string> = {
  enquiryReceived: "#6C63FF",
  telecallerCallDone: "#3B82F6",
  meetingAtOffice: "#F59E0B",
  siteVisit: "#8B5CF6",
  quotationSent: "#EF4444",
  negotiation: "#EC4899",
  finalAgreement: "#10B981",
  lost: "#94A3B8",
  future: "#06B6D4",
};

export const CITY_LABEL: Record<City, string> = {
  bangalore: "Bangalore",
  mysore: "Mysore",
};

export const SOURCE_LABEL: Record<LeadSource, string> = {
  facebook: "Facebook",
  instagram: "Instagram",
  website: "Website",
  phone: "Phone",
  whatsapp: "WhatsApp",
  referral: "Referral",
};

export const OUTCOME_LABEL: Record<CallOutcome, string> = {
  interested: "Interested",
  notInterested: "Not Interested",
  callback: "Callback",
  notReachable: "Not Reachable",
  future: "Future Client",
};

export const SERVICE_TYPE_LABEL: Record<ServiceType, string> = {
  construction: "Construction",
  renovation: "Renovation",
  interiors: "Interiors",
};

export const FUTURE_TAG_LABEL: Record<FutureTag, string> = {
  hot: "Hot",
  warm: "Warm",
  cool: "Cool",
  longTerm: "Long Term",
};

export const KHATA_LABEL: Record<KhataType, string> = {
  aKhata: "A Khata",
  bKhata: "B Khata",
  bda: "BDA",
  bmrda: "BMRDA",
  panchayat: "Panchayat",
  other: "Others",
};

export const PLANNING_LABEL: Record<PlanningTimeline, string> = {
  immediate: "Immediate",
  within3Months: "Within 3 Months",
  within6Months: "Within 6 Months",
  withinYear: "Within a Year",
};

export const LOST_REASON_LABEL: Record<LostReason, string> = {
  priceTooHigh: "Price Too High",
  wentWithCompetitor: "Went with Competitor",
  nobudget: "No Budget Right Now",
  projectOnHold: "Project on Hold",
  notInterested: "Not Interested",
  noResponse: "No Response / Ghosted",
  invalidLead: "Invalid / Wrong Number",
  other: "Other",
};

export const STRATEGY_ORDER: AssignmentStrategy[] = [
  "linear",
  "reverse",
  "performance",
  "weighted",
  "random",
  "manual",
];

export const STRATEGY_LABEL: Record<AssignmentStrategy, string> = {
  linear: "Linear",
  reverse: "Reverse",
  performance: "Performance",
  weighted: "Weighted",
  random: "Random",
  manual: "Manual",
};

export const STRATEGY_DESCRIPTION: Record<AssignmentStrategy, string> = {
  linear: "Equal round-robin — fewest leads today gets the next one",
  reverse: "Reverse order — most-loaded TC gets priority",
  performance: "Top scorer this week gets more leads",
  weighted: "Custom percentage split per telecaller (falls back to Linear — not yet configurable)",
  random: "Completely random each time",
  manual: "Manager assigns every lead manually — no auto-assign",
};

// Same Express/Vercel backend the Flutter app calls for team management.
export const BACKEND_URL = "https://mortar-seven.vercel.app";

export const PAGE_SIZE = 25;
