"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { StageBadge } from "@/components/stage-badge";
import { ScheduleMeetingModal } from "@/components/schedule-meeting-modal";
import { STAGE_ORDER, STAGE_LABEL, CITY_LABEL, OUTCOME_LABEL, PAGE_SIZE } from "@/lib/constants";
import type { Lead, Profile, LeadStage } from "@/lib/types";
import {
  updateLeadStage,
  reassignLead,
  bulkUpdateStage,
  bulkReassignLeads,
  setMeetingStage,
} from "@/app/(protected)/leads/actions";

type SortColumn = "created_at" | "name" | "followup_at";

export function LeadsTable({ telecallers }: { telecallers: Profile[] }) {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);

  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [stageFilter, setStageFilter] = useState<string>("");
  const [cityFilter, setCityFilter] = useState<string>("");
  const [assignedFilter, setAssignedFilter] = useState<string>("");
  const [sortColumn, setSortColumn] = useState<SortColumn>("created_at");
  const [sortAsc, setSortAsc] = useState(false);
  const [page, setPage] = useState(0);

  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulkPending, setBulkPending] = useState(false);
  const [meetingModalLead, setMeetingModalLead] = useState<Lead | null>(null);

  useEffect(() => {
    const t = setTimeout(() => {
      setDebouncedSearch(search);
      setPage(0);
    }, 300);
    return () => clearTimeout(t);
  }, [search]);

  const fetchLeads = useCallback(async () => {
    setLoading(true);
    const supabase = createClient();
    let query = supabase.from("leads").select("*", { count: "exact" });

    if (debouncedSearch) {
      query = query.or(`name.ilike.%${debouncedSearch}%,phone.ilike.%${debouncedSearch}%`);
    }
    if (stageFilter) query = query.eq("stage", stageFilter);
    if (cityFilter) query = query.eq("city", cityFilter);
    if (assignedFilter === "unassigned") query = query.is("assigned_to", null);
    else if (assignedFilter) query = query.eq("assigned_to", assignedFilter);

    query = query
      .order(sortColumn, { ascending: sortAsc, nullsFirst: false })
      .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1);

    const { data, count } = await query;
    setLeads(data ?? []);
    setTotalCount(count ?? 0);
    setLoading(false);
  }, [debouncedSearch, stageFilter, cityFilter, assignedFilter, sortColumn, sortAsc, page]);

  useEffect(() => {
    // Table data is driven entirely by filter/sort/page state, so an effect (rather than
    // an event handler) is the correct trigger here — this isn't a derivable-in-render value.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    fetchLeads();
  }, [fetchLeads]);

  function toggleSort(col: SortColumn) {
    if (sortColumn === col) setSortAsc(!sortAsc);
    else {
      setSortColumn(col);
      setSortAsc(false);
    }
  }

  function toggleSelected(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleSelectAllOnPage() {
    setSelected((prev) => {
      const allSelected = leads.every((l) => prev.has(l.id));
      const next = new Set(prev);
      if (allSelected) leads.forEach((l) => next.delete(l.id));
      else leads.forEach((l) => next.add(l.id));
      return next;
    });
  }

  async function handleBulkStage(stage: LeadStage) {
    setBulkPending(true);
    await bulkUpdateStage([...selected], stage);
    setSelected(new Set());
    await fetchLeads();
    setBulkPending(false);
  }

  async function handleBulkAssign(tcId: string) {
    setBulkPending(true);
    await bulkReassignLeads([...selected], tcId);
    setSelected(new Set());
    await fetchLeads();
    setBulkPending(false);
  }

  async function handleRowStage(leadId: string, stage: LeadStage) {
    if (stage === "meetingAtOffice") {
      const lead = leads.find((l) => l.id === leadId);
      if (lead) setMeetingModalLead(lead);
      return;
    }
    await updateLeadStage(leadId, stage);
    fetchLeads();
  }

  async function handleRowAssign(leadId: string, tcId: string) {
    await reassignLead(leadId, tcId);
    fetchLeads();
  }

  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center gap-2">
        <input
          type="text"
          placeholder="Search name or phone…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-64 rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
        />
        <select
          value={stageFilter}
          onChange={(e) => {
            setStageFilter(e.target.value);
            setPage(0);
          }}
          className="rounded-md border border-zinc-300 bg-white px-2 py-1.5 text-sm text-zinc-900"
        >
          <option value="">All stages</option>
          {STAGE_ORDER.map((s) => (
            <option key={s} value={s}>
              {STAGE_LABEL[s]}
            </option>
          ))}
        </select>
        <select
          value={cityFilter}
          onChange={(e) => {
            setCityFilter(e.target.value);
            setPage(0);
          }}
          className="rounded-md border border-zinc-300 bg-white px-2 py-1.5 text-sm text-zinc-900"
        >
          <option value="">All cities</option>
          <option value="bangalore">Bangalore</option>
          <option value="mysore">Mysore</option>
        </select>
        <select
          value={assignedFilter}
          onChange={(e) => {
            setAssignedFilter(e.target.value);
            setPage(0);
          }}
          className="rounded-md border border-zinc-300 bg-white px-2 py-1.5 text-sm text-zinc-900"
        >
          <option value="">Everyone</option>
          <option value="unassigned">Unassigned</option>
          {telecallers.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>
        <span className="ml-auto text-sm text-zinc-500">{totalCount} leads</span>
      </div>

      {selected.size > 0 && (
        <div className="mb-3 flex items-center gap-3 rounded-lg border border-[#F5A623]/40 bg-[#F5A623]/10 px-4 py-2 text-sm">
          <span className="font-medium text-[#0D1B2A]">{selected.size} selected</span>
          <select
            disabled={bulkPending}
            defaultValue=""
            onChange={(e) => e.target.value && handleBulkStage(e.target.value as LeadStage)}
            className="rounded-md border border-zinc-300 bg-white px-2 py-1 text-sm text-zinc-900"
          >
            <option value="" disabled>
              Change stage to…
            </option>
            {STAGE_ORDER.map((s) => (
              <option key={s} value={s}>
                {STAGE_LABEL[s]}
              </option>
            ))}
          </select>
          <select
            disabled={bulkPending}
            defaultValue=""
            onChange={(e) => e.target.value && handleBulkAssign(e.target.value)}
            className="rounded-md border border-zinc-300 bg-white px-2 py-1 text-sm text-zinc-900"
          >
            <option value="" disabled>
              Reassign to…
            </option>
            {telecallers.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
          <button
            onClick={() => setSelected(new Set())}
            className="ml-auto text-zinc-500 hover:text-zinc-700"
          >
            Clear
          </button>
        </div>
      )}

      <div className="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="w-10 px-4 py-3">
                <input
                  type="checkbox"
                  checked={leads.length > 0 && leads.every((l) => selected.has(l.id))}
                  onChange={toggleSelectAllOnPage}
                />
              </th>
              <th className="cursor-pointer px-4 py-3" onClick={() => toggleSort("name")}>
                Name {sortColumn === "name" && (sortAsc ? "↑" : "↓")}
              </th>
              <th className="px-4 py-3">Phone</th>
              <th className="px-4 py-3">City</th>
              <th className="px-4 py-3">Stage</th>
              <th className="px-4 py-3">Assigned To</th>
              <th className="px-4 py-3">Last Outcome</th>
              <th className="cursor-pointer px-4 py-3" onClick={() => toggleSort("followup_at")}>
                Follow-up {sortColumn === "followup_at" && (sortAsc ? "↑" : "↓")}
              </th>
              <th className="cursor-pointer px-4 py-3" onClick={() => toggleSort("created_at")}>
                Created {sortColumn === "created_at" && (sortAsc ? "↑" : "↓")}
              </th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={9} className="px-4 py-8 text-center text-zinc-400">
                  Loading…
                </td>
              </tr>
            ) : leads.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-4 py-8 text-center text-zinc-400">
                  No leads match these filters.
                </td>
              </tr>
            ) : (
              leads.map((lead) => (
                <tr key={lead.id} className="border-b border-zinc-100 last:border-0 hover:bg-zinc-50">
                  <td className="px-4 py-2.5">
                    <input
                      type="checkbox"
                      checked={selected.has(lead.id)}
                      onChange={() => toggleSelected(lead.id)}
                    />
                  </td>
                  <td className="px-4 py-2.5 font-medium text-[#0D1B2A]">
                    <Link href={`/leads/${lead.id}`} className="hover:underline">
                      {lead.name}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">{lead.phone}</td>
                  <td className="px-4 py-2.5 text-zinc-600">{CITY_LABEL[lead.city]}</td>
                  <td className="px-4 py-2.5">
                    <select
                      value={lead.stage}
                      onChange={(e) => handleRowStage(lead.id, e.target.value as LeadStage)}
                      className="rounded-md border-none bg-transparent text-xs text-zinc-900"
                    >
                      {STAGE_ORDER.map((s) => (
                        <option key={s} value={s}>
                          {STAGE_LABEL[s]}
                        </option>
                      ))}
                    </select>
                    <div className="mt-1">
                      <StageBadge stage={lead.stage} />
                    </div>
                  </td>
                  <td className="px-4 py-2.5">
                    <select
                      value={lead.assigned_to ?? ""}
                      onChange={(e) => handleRowAssign(lead.id, e.target.value)}
                      className="rounded-md border border-zinc-200 bg-white px-1.5 py-1 text-xs text-zinc-900"
                    >
                      <option value="" disabled>
                        Unassigned
                      </option>
                      {telecallers.map((t) => (
                        <option key={t.id} value={t.id}>
                          {t.name}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {lead.last_outcome ? OUTCOME_LABEL[lead.last_outcome] : "—"}
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {lead.followup_at ? new Date(lead.followup_at).toLocaleDateString() : "—"}
                  </td>
                  <td className="px-4 py-2.5 text-zinc-600">
                    {new Date(lead.created_at).toLocaleDateString()}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="mt-4 flex items-center justify-between text-sm text-zinc-500">
        <span>
          Page {page + 1} of {totalPages}
        </span>
        <div className="flex gap-2">
          <button
            disabled={page === 0}
            onClick={() => setPage((p) => p - 1)}
            className="rounded-md border border-zinc-300 px-3 py-1 disabled:opacity-40"
          >
            Previous
          </button>
          <button
            disabled={page >= totalPages - 1}
            onClick={() => setPage((p) => p + 1)}
            className="rounded-md border border-zinc-300 px-3 py-1 disabled:opacity-40"
          >
            Next
          </button>
        </div>
      </div>

      {meetingModalLead && (
        <ScheduleMeetingModal
          telecallers={telecallers}
          currentAssignedTo={meetingModalLead.assigned_to}
          onCancel={() => setMeetingModalLead(null)}
          onConfirm={async (meetingAtIso, tcId) => {
            await setMeetingStage(meetingModalLead.id, meetingAtIso, tcId);
            setMeetingModalLead(null);
            await fetchLeads();
          }}
        />
      )}
    </div>
  );
}
