"use client";

import { useRouter } from "next/navigation";
import { LeadForm } from "@/components/lead-form";
import { createLead } from "@/app/(protected)/leads/actions";
import type { Profile, LeadFormInput } from "@/lib/types";

export function NewLeadForm({ telecallers }: { telecallers: Profile[] }) {
  const router = useRouter();

  async function handleSubmit(fields: LeadFormInput, assignedTo: string | null) {
    const { id } = await createLead(fields, assignedTo);
    router.push(`/leads/${id}`);
  }

  return <LeadForm telecallers={telecallers} onSubmit={handleSubmit} submitLabel="Create Lead" />;
}
