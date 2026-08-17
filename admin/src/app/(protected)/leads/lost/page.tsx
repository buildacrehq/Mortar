import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { CITY_LABEL, SOURCE_LABEL, LOST_REASON_LABEL } from "@/lib/constants";
import type { Lead, Profile, LeadSource } from "@/lib/types";

export default async function LostLeadsPage() {
  const supabase = await createClient();

  const [{ data: leads }, { data: telecallers }] = await Promise.all([
    supabase
      .from("leads")
      .select("*")
      .eq("stage", "lost")
      .order("last_contacted_at", { ascending: false, nullsFirst: false })
      .returns<Lead[]>(),
    supabase
      .from("profiles")
      .select("id, name, email, role, city, phone, is_active")
      .returns<Profile[]>(),
  ]);

  const lost = leads ?? [];
  const tcById = new Map((telecallers ?? []).map((t) => [t.id, t]));

  const bySource = new Map<LeadSource, number>();
  for (const l of lost) bySource.set(l.source, (bySource.get(l.source) ?? 0) + 1);
  const topSource = [...bySource.entries()].sort((a, b) => b[1] - a[1])[0];

  const byCity = { bangalore: 0, mysore: 0 };
  for (const l of lost) byCity[l.city]++;

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-[#0D1B2A]">Lost Leads</h1>
        <Link href="/leads" className="text-sm text-zinc-500 hover:text-zinc-700">
          ← Back to Leads
        </Link>
      </div>

      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatCard label="Total Lost" value={lost.length} />
        <StatCard label="Top Loss Source" value={topSource ? SOURCE_LABEL[topSource[0]] : "—"} />
        <StatCard label="Bangalore" value={byCity.bangalore} />
        <StatCard label="Mysore" value={byCity.mysore} />
      </div>

      <div className="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">Phone</th>
              <th className="px-4 py-3">City</th>
              <th className="px-4 py-3">Source</th>
              <th className="px-4 py-3">Assigned To</th>
              <th className="px-4 py-3">Lost Reason</th>
              <th className="px-4 py-3">Last Contact</th>
            </tr>
          </thead>
          <tbody>
            {lost.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-zinc-400">
                  No lost leads.
                </td>
              </tr>
            ) : (
              lost.map((lead) => (
                <tr key={lead.id} className="border-b border-zinc-100 last:border-0 hover:bg-zinc-50">
                  <td className="px-4 py-2.5 font-medium text-[#0D1B2A]">
                    <Link href={`/leads/${lead.id}`} className="hover:underline">
                      {lead.name}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">{lead.phone}</td>
                  <td className="px-4 py-2.5 text-zinc-600">{CITY_LABEL[lead.city]}</td>
                  <td className="px-4 py-2.5 text-zinc-600">{SOURCE_LABEL[lead.source]}</td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {lead.assigned_to ? tcById.get(lead.assigned_to)?.name ?? "—" : "Unassigned"}
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {lead.lost_reason ? LOST_REASON_LABEL[lead.lost_reason] : "—"}
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {lead.last_contacted_at
                      ? new Date(lead.last_contacted_at).toLocaleDateString()
                      : new Date(lead.created_at).toLocaleDateString()}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-5">
      <p className="text-sm text-zinc-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-[#0D1B2A]">{value}</p>
    </div>
  );
}
