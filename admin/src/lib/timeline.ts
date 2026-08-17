import { SOURCE_LABEL, SERVICE_TYPE_LABEL, CITY_LABEL, OUTCOME_LABEL, KHATA_LABEL } from "./constants";
import type { Lead, CallLog, LeadNote } from "./types";

export type ActivityType = "created" | "called" | "noteAdded" | "followupSet" | "khataSet";

export type LeadActivity = {
  type: ActivityType;
  at: string;
  title: string;
  subtitle?: string;
  durationSeconds?: number;
};

// Mirrors buildTimeline() in lead_activity.dart — a computed view over data
// that already exists (lead fields + call_logs + lead_notes), not a separate
// activity-log table.
export function buildTimeline(lead: Lead, callLogs: CallLog[], notes: LeadNote[]): LeadActivity[] {
  const activities: LeadActivity[] = [];

  activities.push({
    type: "created",
    at: lead.created_at,
    title: "Lead created",
    subtitle: `${SOURCE_LABEL[lead.source]} · ${SERVICE_TYPE_LABEL[lead.service_type]} · ${CITY_LABEL[lead.city]}`,
  });

  for (const log of callLogs) {
    activities.push({
      type: "called",
      at: log.called_at,
      title: `Call — ${OUTCOME_LABEL[log.outcome]}`,
      subtitle: log.notes ?? undefined,
      durationSeconds: log.duration_seconds,
    });
  }

  for (const note of notes) {
    activities.push({
      type: "noteAdded",
      at: note.created_at,
      title: `Note by ${note.author_name}`,
      subtitle: note.text,
    });
  }

  if (lead.followup_at && callLogs.length > 0) {
    const lastCall = callLogs[callLogs.length - 1];
    activities.push({
      type: "followupSet",
      at: lastCall.called_at,
      title: "Follow-up scheduled",
      subtitle: formatFollowup(lead.followup_at),
    });
  }

  if (lead.khata_type) {
    activities.push({
      type: "khataSet",
      at: lead.last_contacted_at ?? lead.created_at,
      title: `Khata type set — ${KHATA_LABEL[lead.khata_type]}`,
    });
  }

  activities.sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());
  return activities;
}

function formatFollowup(iso: string): string {
  const dt = new Date(iso);
  const now = new Date();
  const diffMs = dt.getTime() - now.getTime();
  const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays < 0) {
    const days = Math.abs(diffDays);
    return days === 0 ? "Was due today" : `${days} day${days > 1 ? "s" : ""} ago`;
  }
  if (diffDays === 0) return "Due today";
  if (diffDays === 1) return "Due tomorrow";
  return `In ${diffDays} days`;
}
