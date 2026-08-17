import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { CITY_LABEL, FUTURE_TAG_LABEL } from "@/lib/constants";
import type { Lead, Profile, FutureTag } from "@/lib/types";

const TAGS: FutureTag[] = ["hot", "warm", "cool", "longTerm"];
const TAG_COLOR: Record<FutureTag, string> = {
  hot: "#EF4444",
  warm: "#F59E0B",
  cool: "#3B82F6",
  longTerm: "#6B7280",
};

export default async function FuturePipelinePage() {
  const supabase = await createClient();

  const [{ data: leads }, { data: telecallers }] = await Promise.all([
    supabase
      .from("leads")
      .select("*")
      .not("future_tag", "is", null)
      .order("followup_at", { ascending: true, nullsFirst: false })
      .returns<Lead[]>(),
    supabase
      .from("profiles")
      .select("id, name, email, role, city, phone, is_active")
      .returns<Profile[]>(),
  ]);

  const future = leads ?? [];
  const tcById = new Map((telecallers ?? []).map((t) => [t.id, t]));
  const counts = Object.fromEntries(TAGS.map((t) => [t, future.filter((l) => l.future_tag === t).length]));

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-[#0D1B2A]">Future Pipeline</h1>
        <Link href="/leads" className="text-sm text-zinc-500 hover:text-zinc-700">
          ← Back to Leads
        </Link>
      </div>

      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        {TAGS.map((t) => (
          <div key={t} className="rounded-xl border border-zinc-200 bg-white p-5">
            <div className="mb-1 flex items-center gap-2">
              <span className="h-2 w-2 rounded-full" style={{ backgroundColor: TAG_COLOR[t] }} />
              <p className="text-sm text-zinc-500">{FUTURE_TAG_LABEL[t]}</p>
            </div>
            <p className="text-2xl font-semibold text-[#0D1B2A]">{counts[t]}</p>
          </div>
        ))}
      </div>

      <div className="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">Phone</th>
              <th className="px-4 py-3">City</th>
              <th className="px-4 py-3">Timeline</th>
              <th className="px-4 py-3">Assigned To</th>
              <th className="px-4 py-3">Follow-up</th>
            </tr>
          </thead>
          <tbody>
            {future.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-zinc-400">
                  No future-pipeline leads.
                </td>
              </tr>
            ) : (
              future.map((lead) => (
                <tr key={lead.id} className="border-b border-zinc-100 last:border-0 hover:bg-zinc-50">
                  <td className="px-4 py-2.5 font-medium text-[#0D1B2A]">
                    <Link href={`/leads/${lead.id}`} className="hover:underline">
                      {lead.name}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">{lead.phone}</td>
                  <td className="px-4 py-2.5 text-zinc-600">{CITY_LABEL[lead.city]}</td>
                  <td className="px-4 py-2.5">
                    <span
                      className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium"
                      style={{
                        backgroundColor: `${TAG_COLOR[lead.future_tag!]}1F`,
                        color: TAG_COLOR[lead.future_tag!],
                      }}
                    >
                      {FUTURE_TAG_LABEL[lead.future_tag!]}
                    </span>
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {lead.assigned_to ? tcById.get(lead.assigned_to)?.name ?? "—" : "Unassigned"}
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {lead.followup_at ? new Date(lead.followup_at).toLocaleDateString() : "—"}
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
