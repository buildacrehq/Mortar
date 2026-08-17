"use client";

import { useState } from "react";
import { formatDuration } from "@/lib/analytics";
import { SOURCE_LABEL } from "@/lib/constants";
import type { LeadSummary, CallLogSummary, Profile, LeadSource } from "@/lib/types";

type ReportPeriod = "week" | "month" | "allTime";

const PERIODS: { value: ReportPeriod; label: string }[] = [
  { value: "week", label: "Last 7 Days" },
  { value: "month", label: "Last 30 Days" },
  { value: "allTime", label: "All Time" },
];

export function ReportsView({
  leads,
  logs,
  telecallers,
}: {
  leads: LeadSummary[];
  logs: CallLogSummary[];
  telecallers: Profile[];
}) {
  const [period, setPeriod] = useState<ReportPeriod>("month");

  const now = new Date();
  const since =
    period === "week"
      ? new Date(now.getTime() - 7 * 86400000)
      : period === "month"
        ? new Date(now.getTime() - 30 * 86400000)
        : null;

  const filteredLeads = since ? leads.filter((l) => new Date(l.created_at) >= since) : leads;
  const periodLogs = since ? logs.filter((c) => new Date(c.called_at) >= since) : logs;

  const newLeads = filteredLeads.length;
  const wonLeads = filteredLeads.filter((l) => l.stage === "finalAgreement").length;
  const lostLeads = filteredLeads.filter((l) => l.stage === "lost").length;
  const totalCalls = periodLogs.length;
  const convRate = newLeads === 0 ? 0 : (wonLeads / newLeads) * 100;
  const lossRate = newLeads === 0 ? 0 : (lostLeads / newLeads) * 100;
  const avgDuration =
    periodLogs.length === 0
      ? 0
      : Math.floor(periodLogs.reduce((s, l) => s + l.duration_seconds, 0) / periodLogs.length);

  const sourceCount = new Map<LeadSource, number>();
  for (const l of filteredLeads) sourceCount.set(l.source, (sourceCount.get(l.source) ?? 0) + 1);
  const bestSource = [...sourceCount.entries()].sort((a, b) => b[1] - a[1])[0];

  const tcCallCount = new Map<string, number>();
  for (const log of periodLogs) {
    if (log.called_by) tcCallCount.set(log.called_by, (tcCallCount.get(log.called_by) ?? 0) + 1);
  }
  const bestTcEntry = [...tcCallCount.entries()].sort((a, b) => b[1] - a[1])[0];
  const bestTc = bestTcEntry ? telecallers.find((t) => t.id === bestTcEntry[0]) : null;

  // 7-day trend, independent of the period selector — mirrors Flutter's fixed "Last 7 Days" chart.
  const trend = Array.from({ length: 7 }, (_, i) => {
    const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (6 - i));
    const nextDay = new Date(day.getTime() + 86400000);
    return leads.filter((l) => {
      const created = new Date(l.created_at);
      return created >= day && created < nextDay;
    }).length;
  });
  const maxTrend = Math.max(1, ...trend);
  const dayLabels = Array.from({ length: 7 }, (_, i) => {
    const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (6 - i));
    return day.toLocaleDateString(undefined, { weekday: "short" })[0];
  });

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

      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-5">
        <Kpi label="New Leads" value={newLeads} />
        <Kpi label="Total Calls" value={totalCalls} />
        <Kpi label="Conversion" value={`${convRate.toFixed(1)}%`} />
        <Kpi label="Loss Rate" value={`${lossRate.toFixed(1)}%`} />
        <Kpi label="Avg Call" value={avgDuration > 0 ? formatDuration(avgDuration) : "—"} />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">Lead Volume — Last 7 Days</h2>
          <div className="flex h-20 items-end gap-2">
            {trend.map((count, i) => (
              <div key={i} className="flex flex-1 flex-col items-center justify-end gap-1">
                {count > 0 && <span className="text-xs font-semibold text-[#0D1B2A]">{count}</span>}
                <div
                  className="w-full rounded"
                  style={{
                    height: `${Math.max(4, (count / maxTrend) * 60)}px`,
                    backgroundColor: i === 6 ? "#F5A623" : "#0D1B2A26",
                  }}
                />
              </div>
            ))}
          </div>
          <div className="mt-2 flex gap-2">
            {dayLabels.map((d, i) => (
              <span key={i} className="flex-1 text-center text-xs text-zinc-400">
                {d}
              </span>
            ))}
          </div>
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">Highlights</h2>
          <div className="space-y-3 text-sm">
            <div className="flex justify-between">
              <span className="text-zinc-500">Best Source</span>
              <span className="font-medium text-[#0D1B2A]">
                {bestSource ? `${SOURCE_LABEL[bestSource[0]]} (${bestSource[1]})` : "—"}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-zinc-500">Top Telecaller (calls)</span>
              <span className="font-medium text-[#0D1B2A]">
                {bestTc ? `${bestTc.name} (${bestTcEntry![1]})` : "—"}
              </span>
            </div>
          </div>

          <h3 className="mb-2 mt-5 text-xs font-semibold text-zinc-500">By Source</h3>
          <div className="space-y-1.5">
            {[...sourceCount.entries()]
              .sort((a, b) => b[1] - a[1])
              .map(([source, count]) => (
                <div key={source} className="flex items-center justify-between text-sm">
                  <span className="text-zinc-600">{SOURCE_LABEL[source]}</span>
                  <span className="text-zinc-500">
                    {count} ({newLeads === 0 ? 0 : ((count / newLeads) * 100).toFixed(0)}%)
                  </span>
                </div>
              ))}
            {sourceCount.size === 0 && <p className="text-sm text-zinc-400">No leads in this period.</p>}
          </div>
        </section>
      </div>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-4">
      <p className="text-xs text-zinc-500">{label}</p>
      <p className="mt-1 text-xl font-semibold text-[#0D1B2A]">{value}</p>
    </div>
  );
}
