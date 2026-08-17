"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { STAGE_ORDER, STAGE_LABEL, STAGE_COLOR, CITY_LABEL, SERVICE_TYPE_LABEL } from "@/lib/constants";
import { updateLeadStage, setMeetingStage } from "@/app/(protected)/leads/actions";
import { ScheduleMeetingModal } from "@/components/schedule-meeting-modal";
import { isOverdue } from "@/lib/analytics";
import type { Lead, Profile, LeadStage } from "@/lib/types";

const ACTIVE_STAGES: LeadStage[] = STAGE_ORDER.filter((s) => s !== "lost" && s !== "future");

export function KanbanBoard({ leads, telecallers }: { leads: Lead[]; telecallers: Profile[] }) {
  const router = useRouter();
  const [meetingModalLead, setMeetingModalLead] = useState<Lead | null>(null);

  async function moveNext(lead: Lead) {
    const idx = ACTIVE_STAGES.indexOf(lead.stage);
    if (idx === -1 || idx === ACTIVE_STAGES.length - 1) return;
    const nextStage = ACTIVE_STAGES[idx + 1];

    if (nextStage === "meetingAtOffice") {
      setMeetingModalLead(lead);
      return;
    }
    await updateLeadStage(lead.id, nextStage);
    router.refresh();
  }

  return (
    <div className="flex gap-4 overflow-x-auto pb-4">
      {ACTIVE_STAGES.map((stage) => {
        const stageLeads = leads.filter((l) => l.stage === stage);
        return (
          <div key={stage} className="w-72 shrink-0">
            <div className="mb-3 flex items-center gap-2 px-1">
              <span
                className="h-2.5 w-2.5 rounded-full"
                style={{ backgroundColor: STAGE_COLOR[stage] }}
              />
              <h2 className="text-sm font-semibold text-[#0D1B2A]">{STAGE_LABEL[stage]}</h2>
              <span className="text-xs text-zinc-400">{stageLeads.length}</span>
            </div>
            <div className="space-y-2">
              {stageLeads.map((lead) => (
                <KanbanCard key={lead.id} lead={lead} onMoveNext={() => moveNext(lead)} />
              ))}
              {stageLeads.length === 0 && (
                <p className="rounded-lg border border-dashed border-zinc-200 px-3 py-6 text-center text-xs text-zinc-400">
                  No leads
                </p>
              )}
            </div>
          </div>
        );
      })}

      {meetingModalLead && (
        <ScheduleMeetingModal
          telecallers={telecallers}
          currentAssignedTo={meetingModalLead.assigned_to}
          onCancel={() => setMeetingModalLead(null)}
          onConfirm={async (meetingAtIso, tcId) => {
            await setMeetingStage(meetingModalLead.id, meetingAtIso, tcId);
            setMeetingModalLead(null);
            router.refresh();
          }}
        />
      )}
    </div>
  );
}

function KanbanCard({ lead, onMoveNext }: { lead: Lead; onMoveNext: () => void }) {
  const overdue = isOverdue(lead.followup_at);
  const isLast = lead.stage === ACTIVE_STAGES[ACTIVE_STAGES.length - 1];

  return (
    <div
      className={`rounded-xl border bg-white p-3 shadow-sm ${overdue ? "border-orange-300" : "border-zinc-200"}`}
    >
      <div className="mb-2 flex items-center justify-between">
        <Link href={`/leads/${lead.id}`} className="text-sm font-semibold text-[#0D1B2A] hover:underline">
          {lead.name}
        </Link>
        {overdue && <span className="text-orange-500" title="Overdue follow-up">⏰</span>}
      </div>
      <div className="mb-2 flex flex-wrap gap-1.5">
        <Pill label={SERVICE_TYPE_LABEL[lead.service_type]} />
        <Pill label={CITY_LABEL[lead.city]} />
        {lead.area && <Pill label={lead.area} />}
      </div>
      {lead.budget && <p className="mb-2 text-xs text-zinc-500">₹{lead.budget}</p>}
      {!isLast && (
        <button
          onClick={onMoveNext}
          className="w-full rounded-md border border-zinc-200 py-1 text-xs text-zinc-600 hover:bg-zinc-50"
        >
          Move to next stage →
        </button>
      )}
    </div>
  );
}

function Pill({ label }: { label: string }) {
  return (
    <span className="rounded-full bg-zinc-100 px-2 py-0.5 text-[11px] text-zinc-600">{label}</span>
  );
}
