import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { STAGE_ORDER, STAGE_LABEL, STAGE_COLOR, CITY_LABEL } from "@/lib/constants";
import {
  stageBreakdown,
  computeCityStats,
  computeTelecallerStats,
  isOverdue,
  formatDuration,
} from "@/lib/analytics";
import type { LeadSummary, CallLogSummary, Profile } from "@/lib/types";

export default async function DashboardPage() {
  const supabase = await createClient();

  const { data: leadsData } = await supabase
    .from("leads")
    .select("id, assigned_to, stage, source, service_type, city, created_at, followup_at")
    .returns<LeadSummary[]>();
  const leads = leadsData ?? [];

  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 90);
  const { data: logsData } = await supabase
    .from("call_logs")
    .select("lead_id, called_by, called_at, duration_seconds, outcome")
    .gte("called_at", cutoff.toISOString())
    .returns<CallLogSummary[]>();
  const logs = logsData ?? [];

  const { data: telecallersData } = await supabase
    .from("profiles")
    .select("id, name, email, role, city, phone, is_active")
    .eq("role", "telecaller")
    .returns<Profile[]>();
  const telecallers = telecallersData ?? [];

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayCount = leads.filter((l) => new Date(l.created_at) >= today).length;
  const overdueCount = leads.filter((l) => isOverdue(l.followup_at)).length;
  const byStage = stageBreakdown(leads);
  const wonCount = byStage.finalAgreement;
  const conversionRate = leads.length === 0 ? 0 : (wonCount / leads.length) * 100;

  const blr = computeCityStats("bangalore", leads);
  const mys = computeCityStats("mysore", leads);

  const tcStats = telecallers
    .map((tc) => computeTelecallerStats(tc, leads, logs))
    .sort((a, b) => b.performanceScore - a.performanceScore);

  const maxStageCount = Math.max(1, ...STAGE_ORDER.map((s) => byStage[s]));

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Dashboard</h1>

      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-5">
        <StatCard label="Total leads" value={leads.length} />
        <StatCard label="Today" value={todayCount} />
        <StatCard label="Calls (90d)" value={logs.length} />
        <StatCard
          label="Overdue"
          value={overdueCount}
          accent={overdueCount > 0 ? "warn" : undefined}
          href="/leads/followups"
        />
        <StatCard label="Conversion" value={`${conversionRate.toFixed(1)}%`} />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">Pipeline</h2>
          <div className="space-y-2.5">
            {STAGE_ORDER.map((s) => (
              <div key={s} className="flex items-center gap-3">
                <span className="w-24 shrink-0 text-xs text-zinc-500">{STAGE_LABEL[s]}</span>
                <div className="h-2 flex-1 overflow-hidden rounded-full bg-zinc-100">
                  <div
                    className="h-full rounded-full"
                    style={{
                      width: `${(byStage[s] / maxStageCount) * 100}%`,
                      backgroundColor: STAGE_COLOR[s],
                    }}
                  />
                </div>
                <span className="w-8 shrink-0 text-right text-xs text-zinc-500">{byStage[s]}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">City Breakdown</h2>
          <div className="grid grid-cols-2 gap-4">
            <CityCard stats={blr} />
            <CityCard stats={mys} />
          </div>
        </section>
      </div>

      <section className="mt-6 rounded-xl border border-zinc-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-zinc-500">Team Performance</h2>
        {tcStats.length === 0 ? (
          <p className="text-sm text-zinc-400">No telecallers yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-zinc-200 text-xs uppercase text-zinc-500">
                <tr>
                  <th className="py-2 pr-4">Telecaller</th>
                  <th className="py-2 pr-4">Leads</th>
                  <th className="py-2 pr-4">Calls Today</th>
                  <th className="py-2 pr-4">Calls This Week</th>
                  <th className="py-2 pr-4">Won</th>
                  <th className="py-2 pr-4">Overdue</th>
                  <th className="py-2 pr-4">Avg Call</th>
                  <th className="py-2 pr-4">Score</th>
                </tr>
              </thead>
              <tbody>
                {tcStats.map((s) => (
                  <tr key={s.profile.id} className="border-b border-zinc-100 last:border-0">
                    <td className="py-2.5 pr-4 font-medium text-[#0D1B2A]">{s.profile.name}</td>
                    <td className="py-2.5 pr-4 text-zinc-600">{s.totalLeads}</td>
                    <td className="py-2.5 pr-4 text-zinc-600">{s.callsToday}</td>
                    <td className="py-2.5 pr-4 text-zinc-600">{s.callsThisWeek}</td>
                    <td className="py-2.5 pr-4 text-zinc-600">{s.wonLeads}</td>
                    <td className="py-2.5 pr-4 text-zinc-600">{s.overdueFollowups}</td>
                    <td className="py-2.5 pr-4 text-zinc-600">
                      {s.avgCallDurationSeconds > 0 ? formatDuration(s.avgCallDurationSeconds) : "—"}
                    </td>
                    <td className="py-2.5 pr-4 font-medium text-[#0D1B2A]">
                      {s.performanceScore.toFixed(1)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}

function StatCard({
  label,
  value,
  accent,
  href,
}: {
  label: string;
  value: number | string;
  accent?: "warn";
  href?: string;
}) {
  const content = (
    <>
      <p className="text-sm text-zinc-500">{label}</p>
      <p className={`mt-1 text-3xl font-semibold ${accent === "warn" ? "text-amber-600" : "text-[#0D1B2A]"}`}>
        {value}
      </p>
    </>
  );
  if (href) {
    return (
      <Link href={href} className="block rounded-xl border border-zinc-200 bg-white p-5 hover:bg-zinc-50">
        {content}
      </Link>
    );
  }
  return <div className="rounded-xl border border-zinc-200 bg-white p-5">{content}</div>;
}

function CityCard({ stats }: { stats: ReturnType<typeof computeCityStats> }) {
  return (
    <div className="rounded-lg border border-zinc-100 p-3">
      <p className="mb-2 text-sm font-medium text-[#0D1B2A]">{CITY_LABEL[stats.city]}</p>
      <dl className="space-y-1 text-xs text-zinc-500">
        <Row label="Total" value={stats.total} />
        <Row label="Active" value={stats.active} />
        <Row label="Won" value={stats.won} />
        <Row label="Lost" value={stats.lost} />
        <Row label="Overdue" value={stats.overdue} />
        <Row label="Conversion" value={`${stats.conversionRate.toFixed(1)}%`} />
      </dl>
    </div>
  );
}

function Row({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="flex justify-between">
      <span>{label}</span>
      <span className="font-medium text-zinc-700">{value}</span>
    </div>
  );
}
