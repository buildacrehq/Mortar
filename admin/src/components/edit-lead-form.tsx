"use client";

import { useRouter } from "next/navigation";
import { LeadForm } from "@/components/lead-form";
import { updateLeadFull } from "@/app/(protected)/leads/actions";
import type { LeadFormInput } from "@/lib/types";

export function EditLeadForm({
  leadId,
  initial,
}: {
  leadId: string;
  initial: Partial<LeadFormInput>;
}) {
  const router = useRouter();

  async function handleSubmit(fields: LeadFormInput) {
    await updateLeadFull(leadId, fields);
    router.push(`/leads/${leadId}`);
  }

  return <LeadForm initial={initial} onSubmit={handleSubmit} submitLabel="Save Changes" />;
}
