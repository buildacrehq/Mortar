import { STAGE_ORDER } from "./constants";
import type { LeadSummary, CallLogSummary, LeadStage, City, Profile, CallOutcome } from "./types";

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

// Mirrors _Period in performance_screen.dart — the dedicated Performance page
// lets a manager compare TCs over different windows, unlike the Dashboard's
// fixed "this week" table.
export type PerformancePeriod = "thisWeek" | "lastWeek" | "thisMonth" | "allTime";

export function periodRange(period: PerformancePeriod): { start: Date; end: Date } {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const dayOfWeek = todayStart.getDay() === 0 ? 7 : todayStart.getDay();
  const thisWeekStart = new Date(todayStart);
  thisWeekStart.setDate(thisWeekStart.getDate() - (dayOfWeek - 1));

  switch (period) {
    case "thisWeek":
      return { start: thisWeekStart, end: now };
    case "lastWeek": {
      const lastWeekStart = new Date(thisWeekStart);
      lastWeekStart.setDate(lastWeekStart.getDate() - 7);
      return { start: lastWeekStart, end: thisWeekStart };
    }
    case "thisMonth":
      return { start: new Date(now.getFullYear(), now.getMonth(), 1), end: now };
    case "allTime":
      return { start: new Date(2000, 0, 1), end: now };
  }
}

export type TelecallerPeriodStats = TelecallerStats & {
  outcomeBreakdown: Record<CallOutcome, number>;
};

export function computeTelecallerStatsForPeriod(
  profile: Profile,
  leads: LeadSummary[],
  logs: CallLogSummary[],
  period: PerformancePeriod,
): TelecallerPeriodStats {
  const { start, end } = periodRange(period);
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const myLeads = leads.filter((l) => l.assigned_to === profile.id);
  const myLogs = logs.filter((c) => c.called_by === profile.id);
  const periodLogs = myLogs.filter((c) => {
    const d = new Date(c.called_at);
    return d >= start && d < end;
  });

  const callsToday = myLogs.filter((c) => new Date(c.called_at) >= todayStart).length;
  const callsThisWeek = periodLogs.length;
  const totalCallDurationSeconds = periodLogs.reduce((sum, c) => sum + c.duration_seconds, 0);
  const avgCallDurationSeconds =
    periodLogs.length === 0 ? 0 : Math.floor(totalCallDurationSeconds / periodLogs.length);
  const overdueFollowups = myLeads.filter((l) => isOverdue(l.followup_at)).length;
  const wonLeads = myLeads.filter((l) => l.stage === "finalAgreement").length;

  const outcomes: CallOutcome[] = ["interested", "notInterested", "callback", "notReachable", "future"];
  const outcomeBreakdown = {} as Record<CallOutcome, number>;
  for (const o of outcomes) outcomeBreakdown[o] = periodLogs.filter((c) => c.outcome === o).length;

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
    outcomeBreakdown,
  };
}

export function formatDuration(totalSeconds: number): string {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}
