import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { StageBadge } from "@/components/stage-badge";
import { LeadStageSelect, LeadAssignSelect } from "@/components/lead-detail-controls";
import { AddNoteForm } from "@/components/add-note-form";
import {
  CITY_LABEL,
  SOURCE_LABEL,
  SERVICE_TYPE_LABEL,
  OUTCOME_LABEL,
  FUTURE_TAG_LABEL,
  LOST_REASON_LABEL,
  KHATA_LABEL,
  PLANNING_LABEL,
} from "@/lib/constants";
import type { Lead, Profile, CallLog, LeadNote } from "@/lib/types";

export default async function LeadDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: lead }, { data: callLogs }, { data: notes }, { data: telecallers }] =
    await Promise.all([
      supabase.from("leads").select("*").eq("id", id).returns<Lead[]>().single(),
      supabase
        .from("call_logs")
        .select("id, lead_id, called_by, called_at, duration_seconds, outcome, notes")
        .eq("lead_id", id)
        .order("called_at", { ascending: false })
        .returns<CallLog[]>(),
      supabase
        .from("lead_notes")
        .select("id, lead_id, author_name, text, created_at")
        .eq("lead_id", id)
        .order("created_at", { ascending: false })
        .returns<LeadNote[]>(),
      supabase
        .from("profiles")
        .select("id, name, email, role, city, phone, is_active")
        .eq("role", "telecaller")
        .order("name")
        .returns<Profile[]>(),
    ]);

  if (!lead) notFound();

  return (
    <div>
      <Link href="/leads" className="mb-4 inline-block text-sm text-zinc-500 hover:text-zinc-700">
        ← Back to Leads
      </Link>

      <div className="mb-6 flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-[#0D1B2A]">{lead.name}</h1>
          <p className="mt-1 text-sm text-zinc-500">
            {lead.phone} {lead.email ? `· ${lead.email}` : ""}
          </p>
        </div>
        <StageBadge stage={lead.stage} />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <section className="rounded-xl border border-zinc-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-zinc-500">Lead Details</h2>
            <dl className="grid grid-cols-2 gap-y-3 text-sm">
              <Field label="City" value={CITY_LABEL[lead.city]} />
              <Field label="Source" value={SOURCE_LABEL[lead.source]} />
              <Field label="Service" value={SERVICE_TYPE_LABEL[lead.service_type]} />
              <Field label="Area" value={lead.area ?? "—"} />
              <Field label="Plot Size" value={lead.plot_size ?? "—"} />
              <Field label="Budget" value={lead.budget ?? "—"} />
              <Field
                label="Khata Type"
                value={lead.khata_type ? KHATA_LABEL[lead.khata_type] : "—"}
              />
              <Field
                label="Planning Timeline"
                value={lead.planning_timeline ? PLANNING_LABEL[lead.planning_timeline] : "—"}
              />
              <Field
                label="Last Outcome"
                value={lead.last_outcome ? OUTCOME_LABEL[lead.last_outcome] : "—"}
              />
              <Field
                label="Follow-up"
                value={lead.followup_at ? new Date(lead.followup_at).toLocaleString() : "—"}
              />
              {lead.future_tag && (
                <Field label="Future Tag" value={FUTURE_TAG_LABEL[lead.future_tag]} />
              )}
              {lead.lost_reason && (
                <Field label="Lost Reason" value={LOST_REASON_LABEL[lead.lost_reason]} />
              )}
            </dl>
            {lead.notes && (
              <div className="mt-4 border-t border-zinc-100 pt-4">
                <p className="mb-1 text-xs font-medium text-zinc-400">Notes</p>
                <p className="text-sm text-zinc-700">{lead.notes}</p>
              </div>
            )}
          </section>

          <section className="rounded-xl border border-zinc-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-zinc-500">Call History</h2>
            {!callLogs || callLogs.length === 0 ? (
              <p className="text-sm text-zinc-400">No calls logged yet.</p>
            ) : (
              <ul className="divide-y divide-zinc-100">
                {callLogs.map((log: CallLog) => (
                  <li key={log.id} className="flex items-center justify-between py-2.5 text-sm">
                    <div>
                      <span className="font-medium text-[#0D1B2A]">
                        {OUTCOME_LABEL[log.outcome]}
                      </span>
                      {log.notes && <span className="ml-2 text-zinc-500">{log.notes}</span>}
                    </div>
                    <div className="text-right text-zinc-400">
                      <div>{new Date(log.called_at).toLocaleString()}</div>
                      <div>
                        {Math.floor(log.duration_seconds / 60)}m {log.duration_seconds % 60}s
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section className="rounded-xl border border-zinc-200 bg-white p-5">
            <h2 className="mb-4 text-sm font-semibold text-zinc-500">Internal Notes</h2>
            <div className="mb-4">
              <AddNoteForm leadId={lead.id} />
            </div>
            {!notes || notes.length === 0 ? (
              <p className="text-sm text-zinc-400">No notes yet.</p>
            ) : (
              <ul className="space-y-3">
                {notes.map((note: LeadNote) => (
                  <li key={note.id} className="text-sm">
                    <div className="flex items-baseline justify-between">
                      <span className="font-medium text-[#0D1B2A]">{note.author_name}</span>
                      <span className="text-xs text-zinc-400">
                        {new Date(note.created_at).toLocaleString()}
                      </span>
                    </div>
                    <p className="mt-0.5 text-zinc-600">{note.text}</p>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>

        <div className="space-y-6">
          <section className="rounded-xl border border-zinc-200 bg-white p-5">
            <h2 className="mb-3 text-sm font-semibold text-zinc-500">Stage</h2>
            <LeadStageSelect
              leadId={lead.id}
              stage={lead.stage}
              assignedTo={lead.assigned_to}
              telecallers={telecallers ?? []}
            />
          </section>
          <section className="rounded-xl border border-zinc-200 bg-white p-5">
            <h2 className="mb-3 text-sm font-semibold text-zinc-500">Assigned To</h2>
            <LeadAssignSelect
              leadId={lead.id}
              assignedTo={lead.assigned_to}
              telecallers={telecallers ?? []}
            />
          </section>
        </div>
      </div>
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-zinc-400">{label}</dt>
      <dd className="text-zinc-700">{value}</dd>
    </div>
  );
}
