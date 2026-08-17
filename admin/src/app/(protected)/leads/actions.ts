"use server";

import { revalidatePath } from "next/cache";
import { requireManager } from "@/lib/require-manager";
import type { LeadStage } from "@/lib/types";

export async function updateLeadStage(leadId: string, stage: LeadStage) {
  const { supabase } = await requireManager();
  const { error } = await supabase.from("leads").update({ stage }).eq("id", leadId);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
}

export async function reassignLead(leadId: string, assignedTo: string) {
  const { supabase } = await requireManager();
  const { error } = await supabase
    .from("leads")
    .update({ assigned_to: assignedTo })
    .eq("id", leadId);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
}

// Moving a lead to "Meeting" needs a meeting time and a confirmed owner —
// written together so the lead never sits in Meeting stage with a stale/empty follow-up.
export async function setMeetingStage(leadId: string, meetingAt: string, assignedTo: string) {
  const { supabase } = await requireManager();
  const { error } = await supabase
    .from("leads")
    .update({ stage: "meetingAtOffice", followup_at: meetingAt, assigned_to: assignedTo })
    .eq("id", leadId);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
}

export async function bulkUpdateStage(leadIds: string[], stage: LeadStage) {
  const { supabase } = await requireManager();
  const { error } = await supabase.from("leads").update({ stage }).in("id", leadIds);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
}

// Junk leads (spam/duplicate/wrong number) reuse the existing lost + invalidLead
// taxonomy rather than a new stage value — adding a new stage would need a Postgres
// CHECK-constraint migration, which isn't necessary when this maps cleanly already.
export async function markAsJunk(leadId: string) {
  const { supabase } = await requireManager();
  const { error } = await supabase
    .from("leads")
    .update({ stage: "lost", lost_reason: "invalidLead" })
    .eq("id", leadId);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
}

export async function bulkMarkAsJunk(leadIds: string[]) {
  const { supabase } = await requireManager();
  const { error } = await supabase
    .from("leads")
    .update({ stage: "lost", lost_reason: "invalidLead" })
    .in("id", leadIds);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
}

export async function bulkReassignLeads(leadIds: string[], assignedTo: string) {
  const { supabase } = await requireManager();
  const { error } = await supabase
    .from("leads")
    .update({ assigned_to: assignedTo })
    .in("id", leadIds);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
}

export async function addLeadNote(leadId: string, text: string) {
  const { supabase, userId, name } = await requireManager();
  const { error } = await supabase.from("lead_notes").insert({
    lead_id: leadId,
    author_id: userId,
    author_name: name,
    text,
  });
  if (error) throw new Error(error.message);
  revalidatePath(`/leads/${leadId}`);
}
