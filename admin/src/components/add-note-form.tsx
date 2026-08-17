"use client";

import { useRef, useState } from "react";
import { addLeadNote } from "@/app/(protected)/leads/actions";

export function AddNoteForm({ leadId }: { leadId: string }) {
  const [pending, setPending] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);

  async function handleSubmit(formData: FormData) {
    const text = (formData.get("text") as string)?.trim();
    if (!text) return;
    setPending(true);
    await addLeadNote(leadId, text);
    formRef.current?.reset();
    setPending(false);
  }

  return (
    <form ref={formRef} action={handleSubmit} className="flex gap-2">
      <input
        name="text"
        placeholder="Add a note…"
        required
        className="flex-1 rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
      />
      <button
        type="submit"
        disabled={pending}
        className="rounded-md bg-[#0D1B2A] px-3 py-1.5 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50"
      >
        Add
      </button>
    </form>
  );
}
