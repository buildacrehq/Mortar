"use client";

import { useState } from "react";
import { OUTCOME_LABEL, FUTURE_TAG_LABEL } from "@/lib/constants";
import type { CallOutcome, FutureTag } from "@/lib/types";

const OUTCOMES: CallOutcome[] = ["interested", "notInterested", "callback", "notReachable", "future"];
const FUTURE_TAGS: FutureTag[] = ["hot", "warm", "cool", "longTerm"];
const DURATIONS = [0, 1, 2, 3, 5, 7, 10, 15, 20, 30];

function addDays(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

const SHORTCUTS: { label: string; date: string }[] = [
  { label: "Tomorrow", date: addDays(1) },
  { label: "3 Days", date: addDays(3) },
  { label: "1 Week", date: addDays(7) },
  { label: "2 Weeks", date: addDays(14) },
];

export function LogCallModal({
  onCancel,
  onConfirm,
}: {
  onCancel: () => void;
  onConfirm: (
    outcome: CallOutcome,
    durationSeconds: number,
    notes: string | null,
    followupAt: string | null,
    futureTag: FutureTag | null,
  ) => Promise<void>;
}) {
  const [outcome, setOutcome] = useState<CallOutcome | null>(null);
  const [futureTag, setFutureTag] = useState<FutureTag | null>(null);
  const [durationMinutes, setDurationMinutes] = useState(0);
  const [followupDate, setFollowupDate] = useState("");
  const [followupTime, setFollowupTime] = useState("10:00");
  const [notes, setNotes] = useState("");
  const [pending, setPending] = useState(false);

  async function handleSave() {
    if (!outcome) return;
    setPending(true);
    await onConfirm(
      outcome,
      durationMinutes * 60,
      notes.trim() || null,
      followupDate ? new Date(`${followupDate}T${followupTime || "10:00"}`).toISOString() : null,
      futureTag,
    );
    setPending(false);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
      <div className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-xl bg-white p-6 shadow-xl">
        <h2 className="mb-4 text-lg font-semibold text-[#0D1B2A]">Log Call Outcome</h2>

        <p className="mb-2 text-sm font-medium text-zinc-700">What happened on this call?</p>
        <div className="mb-4 flex flex-wrap gap-2">
          {OUTCOMES.map((o) => (
            <button
              key={o}
              onClick={() => {
                setOutcome(o);
                if (o !== "future") setFutureTag(null);
              }}
              className={`rounded-md border px-3 py-1.5 text-sm ${
                outcome === o
                  ? "border-[#0D1B2A] bg-[#0D1B2A] text-white"
                  : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
              }`}
            >
              {OUTCOME_LABEL[o]}
            </button>
          ))}
        </div>

        {outcome === "future" && (
          <div className="mb-4">
            <p className="mb-2 text-sm font-medium text-zinc-700">Timeline</p>
            <div className="flex flex-wrap gap-2">
              {FUTURE_TAGS.map((t) => (
                <button
                  key={t}
                  onClick={() => setFutureTag(t)}
                  className={`rounded-md border px-3 py-1.5 text-sm ${
                    futureTag === t
                      ? "border-[#F5A623] bg-[#F5A623] text-white"
                      : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
                  }`}
                >
                  {FUTURE_TAG_LABEL[t]}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="mb-4">
          <p className="mb-2 text-sm font-medium text-zinc-700">Call Duration</p>
          <div className="flex flex-wrap gap-2">
            {DURATIONS.map((min) => (
              <button
                key={min}
                onClick={() => setDurationMinutes(min)}
                className={`rounded-md border px-3 py-1.5 text-sm ${
                  durationMinutes === min
                    ? "border-[#0D1B2A] bg-[#0D1B2A] text-white"
                    : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
                }`}
              >
                {min === 0 ? "Not set" : `${min}m`}
              </button>
            ))}
          </div>
        </div>

        <div className="mb-4">
          <p className="mb-2 text-sm font-medium text-zinc-700">Follow-up Date &amp; Time</p>
          <div className="mb-2 flex flex-wrap gap-2">
            {SHORTCUTS.map((s) => (
              <button
                key={s.label}
                onClick={() => setFollowupDate(followupDate === s.date ? "" : s.date)}
                className={`rounded-md border px-3 py-1.5 text-sm ${
                  followupDate === s.date
                    ? "border-[#0D1B2A] bg-[#0D1B2A] text-white"
                    : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
                }`}
              >
                {s.label}
              </button>
            ))}
          </div>
          <div className="flex gap-2">
            <input
              type="date"
              value={followupDate}
              onChange={(e) => setFollowupDate(e.target.value)}
              className="flex-1 rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
            />
            <input
              type="time"
              value={followupTime}
              onChange={(e) => setFollowupTime(e.target.value)}
              className="rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
            />
          </div>
        </div>

        <div className="mb-6">
          <p className="mb-2 text-sm font-medium text-zinc-700">Notes</p>
          <textarea
            rows={2}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className="w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
          />
        </div>

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
            disabled={pending || !outcome}
            className="rounded-md bg-[#0D1B2A] px-4 py-2 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50"
          >
            {pending ? "Saving…" : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}
