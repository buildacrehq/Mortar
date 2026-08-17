import { createClient } from "@/lib/supabase/server";
import { STAGE_ORDER, STAGE_LABEL, SOURCE_LABEL, SERVICE_TYPE_LABEL } from "@/lib/constants";
import { computeCityStats } from "@/lib/analytics";
import type { LeadSummary, LeadSource, ServiceType } from "@/lib/types";

export default async function CityAnalyticsPage() {
  const supabase = await createClient();

  const { data: leadsData } = await supabase
    .from("leads")
    .select("id, assigned_to, stage, source, service_type, city, created_at, followup_at")
    .returns<LeadSummary[]>();
  const leads = leadsData ?? [];

  const blr = computeCityStats("bangalore", leads);
  const mys = computeCityStats("mysore", leads);
  const total = leads.length;
  const blrPct = total === 0 ? 50 : (blr.total / total) * 100;

  const blrLeads = leads.filter((l) => l.city === "bangalore");
  const mysLeads = leads.filter((l) => l.city === "mysore");

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">City Analytics</h1>

      <div className="mb-6 rounded-xl bg-[#0D1B2A] p-5">
        <div className="grid grid-cols-2 gap-4 text-center">
          <div>
            <p className="text-sm font-semibold text-[#4FC3F7]">Bangalore</p>
            <p className="mt-1 text-3xl font-bold text-white">{blr.total}</p>
            <p className="text-xs text-white/50">total leads</p>
          </div>
          <div>
            <p className="text-sm font-semibold text-[#FFB74D]">Mysore</p>
            <p className="mt-1 text-3xl font-bold text-white">{mys.total}</p>
            <p className="text-xs text-white/50">total leads</p>
          </div>
        </div>
        <div className="mt-4 flex h-2 overflow-hidden rounded-full">
          <div className="bg-[#4FC3F7]" style={{ width: `${blrPct}%` }} />
          <div className="bg-[#FFB74D]" style={{ width: `${100 - blrPct}%` }} />
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">Key Metrics</h2>
          <div className="space-y-2">
            <MetricRow label="Active Leads" blr={blr.active} mys={mys.active} />
            <MetricRow label="Won" blr={blr.won} mys={mys.won} />
            <MetricRow label="Lost" blr={blr.lost} mys={mys.lost} />
            <MetricRow label="Overdue" blr={blr.overdue} mys={mys.overdue} />
            <MetricRow
              label="Conversion"
              blr={`${blr.conversionRate.toFixed(1)}%`}
              mys={`${mys.conversionRate.toFixed(1)}%`}
            />
          </div>
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">Pipeline Distribution</h2>
          <div className="space-y-2">
            {STAGE_ORDER.filter((s) => s !== "lost" && s !== "future").map((s) => (
              <MetricRow
                key={s}
                label={STAGE_LABEL[s]}
                blr={blrLeads.filter((l) => l.stage === s).length}
                mys={mysLeads.filter((l) => l.stage === s).length}
              />
            ))}
          </div>
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">By Source</h2>
          <div className="space-y-2">
            {(Object.keys(SOURCE_LABEL) as LeadSource[])
              .filter((s) => blrLeads.some((l) => l.source === s) || mysLeads.some((l) => l.source === s))
              .map((s) => (
                <MetricRow
                  key={s}
                  label={SOURCE_LABEL[s]}
                  blr={blrLeads.filter((l) => l.source === s).length}
                  mys={mysLeads.filter((l) => l.source === s).length}
                />
              ))}
          </div>
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">By Service Type</h2>
          <div className="space-y-2">
            {(Object.keys(SERVICE_TYPE_LABEL) as ServiceType[]).map((s) => (
              <MetricRow
                key={s}
                label={SERVICE_TYPE_LABEL[s]}
                blr={blrLeads.filter((l) => l.service_type === s).length}
                mys={mysLeads.filter((l) => l.service_type === s).length}
              />
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}

function MetricRow({ label, blr, mys }: { label: string; blr: number | string; mys: number | string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-zinc-100 px-3 py-2 text-sm">
      <span className="text-zinc-500">{label}</span>
      <div className="flex gap-6">
        <span className="w-12 text-right font-medium text-[#0284C7]">{blr}</span>
        <span className="w-12 text-right font-medium text-[#D97706]">{mys}</span>
      </div>
    </div>
  );
}
