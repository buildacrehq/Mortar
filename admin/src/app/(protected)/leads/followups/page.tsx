import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { StageBadge } from "@/components/stage-badge";
import { CITY_LABEL } from "@/lib/constants";
import { isOverdue } from "@/lib/analytics";
import type { Lead, Profile } from "@/lib/types";

export default async function FollowupsPage() {
  const supabase = await createClient();

  const [{ data: leads }, { data: telecallers }] = await Promise.all([
    supabase
      .from("leads")
      .select("*")
      .not("followup_at", "is", null)
      .not("stage", "in", "(lost,finalAgreement)")
      .order("followup_at", { ascending: true })
      .returns<Lead[]>(),
    supabase
      .from("profiles")
      .select("id, name, email, role, city, phone, is_active")
      .returns<Profile[]>(),
  ]);

  const tcById = new Map((telecallers ?? []).map((t) => [t.id, t]));
  const all = leads ?? [];
  const overdue = all.filter((l) => isOverdue(l.followup_at));
  const upcoming = all.filter((l) => !isOverdue(l.followup_at));

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-[#0D1B2A]">Follow-ups</h1>
        <Link href="/leads" className="text-sm text-zinc-500 hover:text-zinc-700">
          ← Back to Leads
        </Link>
      </div>

      {overdue.length > 0 && (
        <section className="mb-6">
          <h2 className="mb-3 flex items-center gap-2 text-sm font-semibold text-orange-600">
            <span>⏰</span> Overdue ({overdue.length})
          </h2>
          <FollowupTable leads={overdue} tcById={tcById} />
        </section>
      )}

      <section>
        <h2 className="mb-3 text-sm font-semibold text-zinc-500">
          Upcoming {upcoming.length > 0 && `(${upcoming.length})`}
        </h2>
        {upcoming.length === 0 ? (
          <p className="text-sm text-zinc-400">No upcoming follow-ups.</p>
        ) : (
          <FollowupTable leads={upcoming} tcById={tcById} />
        )}
      </section>
    </div>
  );
}

function FollowupTable({ leads, tcById }: { leads: Lead[]; tcById: Map<string, Profile> }) {
  return (
    <div className="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-500">
          <tr>
            <th className="px-4 py-3">Name</th>
            <th className="px-4 py-3">Phone</th>
            <th className="px-4 py-3">City</th>
            <th className="px-4 py-3">Stage</th>
            <th className="px-4 py-3">Assigned To</th>
            <th className="px-4 py-3">Follow-up</th>
          </tr>
        </thead>
        <tbody>
          {leads.map((lead) => (
            <tr key={lead.id} className="border-b border-zinc-100 last:border-0 hover:bg-zinc-50">
              <td className="px-4 py-2.5 font-medium text-[#0D1B2A]">
                <Link href={`/leads/${lead.id}`} className="hover:underline">
                  {lead.name}
                </Link>
              </td>
              <td className="px-4 py-2.5 text-zinc-600">{lead.phone}</td>
              <td className="px-4 py-2.5 text-zinc-600">{CITY_LABEL[lead.city]}</td>
              <td className="px-4 py-2.5">
                <StageBadge stage={lead.stage} />
              </td>
              <td className="px-4 py-2.5 text-zinc-600">
                {lead.assigned_to ? tcById.get(lead.assigned_to)?.name ?? "—" : "Unassigned"}
              </td>
              <td className="px-4 py-2.5 text-zinc-600">
                {lead.followup_at ? new Date(lead.followup_at).toLocaleString() : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
