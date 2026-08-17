"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { STAGE_ORDER, STAGE_LABEL } from "@/lib/constants";
import {
  updateLeadStage,
  reassignLead,
  setMeetingStage,
  markAsJunk,
} from "@/app/(protected)/leads/actions";
import { ScheduleMeetingModal } from "@/components/schedule-meeting-modal";
import type { LeadStage, Profile } from "@/lib/types";

export function LeadStageSelect({
  leadId,
  stage,
  assignedTo,
  telecallers,
}: {
  leadId: string;
  stage: LeadStage;
  assignedTo: string | null;
  telecallers: Profile[];
}) {
  const router = useRouter();
  const [showMeetingModal, setShowMeetingModal] = useState(false);

  return (
    <>
      <select
        value={stage}
        onChange={async (e) => {
          const newStage = e.target.value as LeadStage;
          if (newStage === "meetingAtOffice") {
            setShowMeetingModal(true);
            return;
          }
          await updateLeadStage(leadId, newStage);
          router.refresh();
        }}
        className="rounded-md border border-zinc-300 bg-white px-2 py-1.5 text-sm text-zinc-900"
      >
        {STAGE_ORDER.map((s) => (
          <option key={s} value={s}>
            {STAGE_LABEL[s]}
          </option>
        ))}
      </select>

      {showMeetingModal && (
        <ScheduleMeetingModal
          telecallers={telecallers}
          currentAssignedTo={assignedTo}
          onCancel={() => setShowMeetingModal(false)}
          onConfirm={async (meetingAtIso, tcId) => {
            await setMeetingStage(leadId, meetingAtIso, tcId);
            setShowMeetingModal(false);
            router.refresh();
          }}
        />
      )}
    </>
  );
}

export function LeadAssignSelect({
  leadId,
  assignedTo,
  telecallers,
}: {
  leadId: string;
  assignedTo: string | null;
  telecallers: Profile[];
}) {
  const router = useRouter();
  return (
    <select
      defaultValue={assignedTo ?? ""}
      onChange={async (e) => {
        if (!e.target.value) return;
        await reassignLead(leadId, e.target.value);
        router.refresh();
      }}
      className="rounded-md border border-zinc-300 bg-white px-2 py-1.5 text-sm text-zinc-900"
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
  );
}

export function MarkAsJunkButton({ leadId, leadName }: { leadId: string; leadName: string }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);

  return (
    <button
      disabled={pending}
      onClick={async () => {
        if (!confirm(`Mark "${leadName}" as junk (spam/duplicate/wrong number)?`)) return;
        setPending(true);
        await markAsJunk(leadId);
        router.refresh();
        setPending(false);
      }}
      className="w-full rounded-md border border-zinc-300 py-1.5 text-sm text-zinc-600 hover:bg-zinc-50 disabled:opacity-50"
    >
      {pending ? "Marking…" : "Mark as Junk"}
    </button>
  );
}
