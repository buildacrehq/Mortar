"use client";

import { useState } from "react";
import { computeTelecallerStatsForPeriod, formatDuration } from "@/lib/analytics";
import { OUTCOME_LABEL } from "@/lib/constants";
import type { LeadSummary, CallLogSummary, Profile, CallOutcome } from "@/lib/types";
import type { PerformancePeriod } from "@/lib/analytics";

const PERIODS: { value: PerformancePeriod; label: string }[] = [
  { value: "thisWeek", label: "This Week" },
  { value: "lastWeek", label: "Last Week" },
  { value: "thisMonth", label: "This Month" },
  { value: "allTime", label: "All Time" },
];

function scoreColor(score: number): string {
  if (score >= 7) return "#10B981";
  if (score >= 4) return "#F59E0B";
  return "#EF4444";
}

export function PerformanceView({
  leads,
  logs,
  telecallers,
}: {
  leads: LeadSummary[];
  logs: CallLogSummary[];
  telecallers: Profile[];
}) {
  const [period, setPeriod] = useState<PerformancePeriod>("thisWeek");
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const stats = telecallers
    .map((tc) => computeTelecallerStatsForPeriod(tc, leads, logs, period))
    .sort((a, b) => b.performanceScore - a.performanceScore);

  return (
    <div>
      <div className="mb-6 flex flex-wrap gap-2">
        {PERIODS.map((p) => (
          <button
            key={p.value}
            onClick={() => setPeriod(p.value)}
            className={`rounded-full px-4 py-1.5 text-sm ${
              period === p.value
                ? "bg-[#0D1B2A] text-white"
                : "border border-zinc-300 bg-white text-zinc-600 hover:bg-zinc-50"
            }`}
          >
            {p.label}
          </button>
        ))}
      </div>

      {stats.length === 0 ? (
        <p className="text-sm text-zinc-400">No telecallers yet.</p>
      ) : (
        <div className="space-y-3">
          {stats.map((s, i) => {
            const expanded = expandedId === s.profile.id;
            return (
              <div key={s.profile.id} className="rounded-xl border border-zinc-200 bg-white">
                <button
                  onClick={() => setExpandedId(expanded ? null : s.profile.id)}
                  className="flex w-full items-center gap-4 p-4 text-left"
                >
                  <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-zinc-100 text-sm font-semibold text-zinc-500">
                    {i + 1}
                  </span>
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-[#0D1B2A]">{s.profile.name}</span>
                      {s.profile.city && (
                        <span className="rounded-full bg-zinc-100 px-2 py-0.5 text-[11px] text-zinc-500">
                          {s.profile.city}
                        </span>
                      )}
                    </div>
                    <div className="mt-1 flex gap-4 text-xs text-zinc-500">
                      <span>Today: {s.callsToday}</span>
                      <span>Period: {s.callsThisWeek}</span>
                      <span>Leads: {s.totalLeads}</span>
                    </div>
                    <div className="mt-2 h-1.5 w-full max-w-xs overflow-hidden rounded-full bg-zinc-100">
                      <div
                        className="h-full rounded-full"
                        style={{
                          width: `${Math.min(100, (s.performanceScore / 10) * 100)}%`,
                          backgroundColor: scoreColor(s.performanceScore),
                        }}
                      />
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-2xl font-bold" style={{ color: scoreColor(s.performanceScore) }}>
                      {s.performanceScore.toFixed(1)}
                    </p>
                    <p className="text-[10px] text-zinc-400">/10</p>
                  </div>
                </button>
                {expanded && (
                  <div className="border-t border-zinc-100 p-4">
                    <p className="mb-2 text-xs font-semibold text-zinc-500">Call Outcomes</p>
                    <div className="flex flex-wrap gap-2">
                      {(Object.keys(s.outcomeBreakdown) as CallOutcome[])
                        .filter((o) => s.outcomeBreakdown[o] > 0)
                        .map((o) => (
                          <span
                            key={o}
                            className="rounded-full bg-zinc-100 px-2.5 py-1 text-xs text-zinc-600"
                          >
                            {OUTCOME_LABEL[o]}: {s.outcomeBreakdown[o]}
                          </span>
                        ))}
                      {Object.values(s.outcomeBreakdown).every((v) => v === 0) && (
                        <span className="text-xs text-zinc-400">No calls logged in this period.</span>
                      )}
                    </div>
                    <div className="mt-3 grid grid-cols-3 gap-3 text-xs text-zinc-500">
                      <div>
                        <p className="text-zinc-400">Won</p>
                        <p className="font-medium text-zinc-700">{s.wonLeads}</p>
                      </div>
                      <div>
                        <p className="text-zinc-400">Overdue</p>
                        <p className="font-medium text-zinc-700">{s.overdueFollowups}</p>
                      </div>
                      <div>
                        <p className="text-zinc-400">Avg Call</p>
                        <p className="font-medium text-zinc-700">
                          {s.avgCallDurationSeconds > 0 ? formatDuration(s.avgCallDurationSeconds) : "—"}
                        </p>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
