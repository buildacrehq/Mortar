"use client";

import { useState } from "react";
import Link from "next/link";
import { CITY_LABEL } from "@/lib/constants";
import type { Lead, Profile } from "@/lib/types";

export function QueueView({
  leads,
  calledLeadIds,
  telecallers,
}: {
  leads: Lead[];
  calledLeadIds: string[];
  telecallers: Profile[];
}) {
  const [tcFilter, setTcFilter] = useState("");
  const calledSet = new Set(calledLeadIds);

  const scoped = tcFilter ? leads.filter((l) => l.assigned_to === tcFilter) : leads;

  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayEnd = new Date(todayStart.getTime() + 86400000 - 1000);

  const overdue = scoped
    .filter((l) => l.followup_at && new Date(l.followup_at) < todayStart)
    .sort((a, b) => new Date(a.followup_at!).getTime() - new Date(b.followup_at!).getTime());

  const dueToday = scoped
    .filter((l) => l.followup_at && new Date(l.followup_at) >= todayStart && new Date(l.followup_at) <= todayEnd)
    .sort((a, b) => new Date(a.followup_at!).getTime() - new Date(b.followup_at!).getTime());

  const uncalled = scoped
    .filter((l) => !calledSet.has(l.id))
    .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

  const tcById = new Map(telecallers.map((t) => [t.id, t]));

  return (
    <div>
      <div className="mb-6">
        <select
          value={tcFilter}
          onChange={(e) => setTcFilter(e.target.value)}
          className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
        >
          <option value="">All Telecallers</option>
          {telecallers.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>
      </div>

      <div className="mb-6 grid grid-cols-3 gap-4">
        <StatCard label="Overdue" value={overdue.length} accent="warn" />
        <StatCard label="Due Today" value={dueToday.length} />
        <StatCard label="Uncalled" value={uncalled.length} />
      </div>

      <QueueSection title="Overdue" leads={overdue} tcById={tcById} showAssigned={!tcFilter} />
      <QueueSection title="Due Today" leads={dueToday} tcById={tcById} showAssigned={!tcFilter} />
      <QueueSection title="Uncalled" leads={uncalled} tcById={tcById} showAssigned={!tcFilter} />
    </div>
  );
}

function StatCard({ label, value, accent }: { label: string; value: number; accent?: "warn" }) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-4">
      <p className="text-xs text-zinc-500">{label}</p>
      <p className={`mt-1 text-2xl font-semibold ${accent === "warn" ? "text-amber-600" : "text-[#0D1B2A]"}`}>
        {value}
      </p>
    </div>
  );
}

function QueueSection({
  title,
  leads,
  tcById,
  showAssigned,
}: {
  title: string;
  leads: Lead[];
  tcById: Map<string, Profile>;
  showAssigned: boolean;
}) {
  return (
    <section className="mb-6">
      <h2 className="mb-3 text-sm font-semibold text-zinc-500">
        {title} {leads.length > 0 && `(${leads.length})`}
      </h2>
      {leads.length === 0 ? (
        <p className="text-sm text-zinc-400">Nothing here.</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-500">
              <tr>
                <th className="px-4 py-2.5">Name</th>
                <th className="px-4 py-2.5">Phone</th>
                <th className="px-4 py-2.5">City</th>
                {showAssigned && <th className="px-4 py-2.5">Assigned To</th>}
                <th className="px-4 py-2.5">Follow-up</th>
              </tr>
            </thead>
            <tbody>
              {leads.map((lead) => (
                <tr key={lead.id} className="border-b border-zinc-100 last:border-0 hover:bg-zinc-50">
                  <td className="px-4 py-2 font-medium text-[#0D1B2A]">
                    <Link href={`/leads/${lead.id}`} className="hover:underline">
                      {lead.name}
                    </Link>
                  </td>
                  <td className="px-4 py-2 text-zinc-600">{lead.phone}</td>
                  <td className="px-4 py-2 text-zinc-600">{CITY_LABEL[lead.city]}</td>
                  {showAssigned && (
                    <td className="px-4 py-2 text-zinc-600">
                      {lead.assigned_to ? tcById.get(lead.assigned_to)?.name ?? "—" : "Unassigned"}
                    </td>
                  )}
                  <td className="px-4 py-2 text-zinc-600">
                    {lead.followup_at ? new Date(lead.followup_at).toLocaleString() : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
