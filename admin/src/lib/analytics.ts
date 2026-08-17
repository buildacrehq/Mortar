import { STAGE_ORDER } from "./constants";
import type { LeadSummary, CallLogSummary, LeadStage, City, Profile } from "./types";

export function isOverdue(followupAt: string | null): boolean {
  return followupAt !== null && new Date(followupAt) < new Date();
}

export function stageBreakdown(leads: LeadSummary[]): Record<LeadStage, number> {
  const result = {} as Record<LeadStage, number>;
  for (const stage of STAGE_ORDER) {
    result[stage] = leads.filter((l) => l.stage === stage).length;
  }
  return result;
}

export type CityStats = {
  city: City;
  total: number;
  won: number;
  lost: number;
  active: number;
  overdue: number;
  conversionRate: number;
};

// Mirrors _computeCityStats in city_analytics_screen.dart.
export function computeCityStats(city: City, leads: LeadSummary[]): CityStats {
  const cl = leads.filter((l) => l.city === city);
  const won = cl.filter((l) => l.stage === "finalAgreement").length;
  const lost = cl.filter((l) => l.stage === "lost").length;
  const active = cl.filter(
    (l) => l.stage !== "finalAgreement" && l.stage !== "lost" && l.stage !== "future",
  ).length;
  const overdue = cl.filter((l) => isOverdue(l.followup_at)).length;

  return {
    city,
    total: cl.length,
    won,
    lost,
    active,
    overdue,
    conversionRate: cl.length === 0 ? 0 : (won / cl.length) * 100,
  };
}

export type TelecallerStats = {
  profile: Profile;
  totalLeads: number;
  callsToday: number;
  callsThisWeek: number;
  totalCallDurationSeconds: number;
  avgCallDurationSeconds: number;
  overdueFollowups: number;
  wonLeads: number;
  performanceScore: number;
};

// Mirrors TelecallerStats.performanceScore in telecaller_stats.dart —
// 35% call volume, 25% avg call length, 25% conversion, 15% overdue penalty.
export function computeTelecallerStats(
  profile: Profile,
  leads: LeadSummary[],
  logs: CallLogSummary[],
): TelecallerStats {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const weekStart = new Date(todayStart);
  const dayOfWeek = todayStart.getDay() === 0 ? 7 : todayStart.getDay();
  weekStart.setDate(weekStart.getDate() - (dayOfWeek - 1));

  const myLeads = leads.filter((l) => l.assigned_to === profile.id);
  const myLogs = logs.filter((c) => c.called_by === profile.id);

  const callsToday = myLogs.filter((c) => new Date(c.called_at) >= todayStart).length;
  const callsThisWeek = myLogs.filter((c) => new Date(c.called_at) >= weekStart).length;
  const totalCallDurationSeconds = myLogs.reduce((sum, c) => sum + c.duration_seconds, 0);
  const avgCallDurationSeconds = myLogs.length === 0 ? 0 : Math.floor(totalCallDurationSeconds / myLogs.length);
  const overdueFollowups = myLeads.filter((l) => isOverdue(l.followup_at)).length;
  const wonLeads = myLeads.filter((l) => l.stage === "finalAgreement").length;

  const callScore = Math.min(1, callsThisWeek / 25);
  const durationScore = avgCallDurationSeconds > 0 ? Math.min(1, avgCallDurationSeconds / 600) : 0;
  const conversionScore = myLeads.length > 0 ? Math.min(1, wonLeads / myLeads.length) : 0;
  const overdueScore = myLeads.length > 0 ? Math.max(0, 1 - overdueFollowups / myLeads.length) : 1;
  const performanceScore =
    (callScore * 0.35 + durationScore * 0.25 + conversionScore * 0.25 + overdueScore * 0.15) * 10;

  return {
    profile,
    totalLeads: myLeads.length,
    callsToday,
    callsThisWeek,
    totalCallDurationSeconds,
    avgCallDurationSeconds,
    overdueFollowups,
    wonLeads,
    performanceScore,
  };
}

export function formatDuration(totalSeconds: number): string {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}
