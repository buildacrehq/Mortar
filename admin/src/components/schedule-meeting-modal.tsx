"use client";

import { useState } from "react";
import type { Profile } from "@/lib/types";

export function ScheduleMeetingModal({
  telecallers,
  currentAssignedTo,
  onCancel,
  onConfirm,
}: {
  telecallers: Profile[];
  currentAssignedTo: string | null;
  onCancel: () => void;
  onConfirm: (meetingAtIso: string, assignedTo: string) => Promise<void>;
}) {
  const [dateTime, setDateTime] = useState("");
  const [assignedTo, setAssignedTo] = useState(currentAssignedTo ?? "");
  const [pending, setPending] = useState(false);

  async function handleSave() {
    if (!dateTime || !assignedTo) return;
    setPending(true);
    await onConfirm(new Date(dateTime).toISOString(), assignedTo);
    setPending(false);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
      <div className="w-full max-w-sm rounded-xl bg-white p-6 shadow-xl">
        <h2 className="mb-1 text-lg font-semibold text-[#0D1B2A]">Schedule Meeting</h2>
        <p className="mb-4 text-sm text-zinc-500">
          Set the meeting time and who&apos;s managing this client.
        </p>

        <label className="mb-1 block text-sm font-medium text-zinc-700">Meeting Date &amp; Time</label>
        <input
          type="datetime-local"
          value={dateTime}
          onChange={(e) => setDateTime(e.target.value)}
          className="mb-4 w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
        />

        <label className="mb-1 block text-sm font-medium text-zinc-700">Managed By</label>
        <select
          value={assignedTo}
          onChange={(e) => setAssignedTo(e.target.value)}
          className="mb-6 w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900"
        >
          <option value="" disabled>
            Select telecaller…
          </option>
          {telecallers.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>

        <div className="flex justify-end gap-2">
          <button
            onClick={onCancel}
            disabled={pending}
            className="rounded-md border border-zinc-300 px-4 py-2 text-sm text-zinc-600 hover:bg-zinc-50 disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={pending || !dateTime || !assignedTo}
            className="rounded-md bg-[#0D1B2A] px-4 py-2 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50"
          >
            {pending ? "Saving…" : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}
