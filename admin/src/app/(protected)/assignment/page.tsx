import { createClient } from "@/lib/supabase/server";
import { StrategySelector } from "@/components/strategy-selector";
import { LeadAssignSelect } from "@/components/lead-detail-controls";
import Link from "next/link";
import type { AssignmentStrategy, Profile } from "@/lib/types";

export default async function AssignmentPage() {
  const supabase = await createClient();

  const { data: telecallers } = await supabase
    .from("profiles")
    .select("id, name, email, role, city, phone, is_active")
    .eq("role", "telecaller")
    .eq("is_active", true)
    .order("name")
    .returns<Profile[]>();

  const tcList = telecallers ?? [];

  const workload = await Promise.all(
    tcList.map(async (tc) => {
      const { count } = await supabase
        .from("leads")
        .select("id", { count: "exact", head: true })
        .eq("assigned_to", tc.id);
      return { tc, count: count ?? 0 };
    }),
  );
  const maxLoad = Math.max(1, ...workload.map((w) => w.count));

  const { data: unassigned } = await supabase
    .from("leads")
    .select("id, name, phone, city, source, created_at")
    .is("assigned_to", null)
    .order("created_at", { ascending: false })
    .limit(50);

  const { data: settingsRow } = await supabase
    .from("team_settings")
    .select("assignment_strategy")
    .limit(1)
    .single();
  const currentStrategy = (settingsRow?.assignment_strategy as AssignmentStrategy) ?? "linear";

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Assignment</h1>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <section className="rounded-xl border border-zinc-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-zinc-500">Team Workload</h2>
            {workload.length === 0 ? (
              <p className="text-sm text-zinc-400">No active telecallers.</p>
            ) : (
              <div className="space-y-3">
                {workload.map(({ tc, count }) => (
                  <div key={tc.id}>
                    <div className="mb-1 flex items-center justify-between text-sm">
                      <span className="font-medium text-[#0D1B2A]">{tc.name}</span>
                      <span className="text-zinc-500">{count} leads</span>
                    </div>
                    <div className="h-2 overflow-hidden rounded-full bg-zinc-100">
                      <div
                        className="h-full rounded-full bg-[#0D1B2A]"
                        style={{ width: `${(count / maxLoad) * 100}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>

          <section className="rounded-xl border border-zinc-200 bg-white p-5">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-zinc-500">
                Unassigned Leads {unassigned && unassigned.length > 0 && `(${unassigned.length})`}
              </h2>
              <Link href="/leads" className="text-xs text-zinc-500 hover:underline">
                View all in Leads →
              </Link>
            </div>
            {!unassigned || unassigned.length === 0 ? (
              <p className="text-sm text-zinc-400">No unassigned leads — nice.</p>
            ) : (
              <ul className="divide-y divide-zinc-100">
                {unassigned.map((lead) => (
                  <li key={lead.id} className="flex items-center justify-between py-2.5 text-sm">
                    <div>
                      <Link href={`/leads/${lead.id}`} className="font-medium text-[#0D1B2A] hover:underline">
                        {lead.name}
                      </Link>
                      <p className="text-xs text-zinc-500">
                        {lead.phone} · {lead.city}
                      </p>
                    </div>
                    <LeadAssignSelect leadId={lead.id} assignedTo={null} telecallers={tcList} />
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>

        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-1 text-sm font-semibold text-zinc-500">Assignment Strategy</h2>
          <p className="mb-4 text-xs text-zinc-400">
            Controls how new leads from Meta/Sheets are auto-assigned.
          </p>
          <StrategySelector current={currentStrategy} />
        </section>
      </div>
    </div>
  );
}
