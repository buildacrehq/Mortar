"use server";

import { revalidatePath } from "next/cache";
import { requireManager } from "@/lib/require-manager";
import type { LeadStage, LeadFormInput, CallOutcome, FutureTag } from "@/lib/types";

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

// Mirrors Flutter's addLead — new leads start at enquiryReceived, optionally
// pre-assigned to a telecaller (admin/manager pick one explicitly, since unlike
// the mobile app there's no "current user is a telecaller" to default to).
export async function createLead(fields: LeadFormInput, assignedTo: string | null) {
  const { supabase } = await requireManager();
  const { data, error } = await supabase
    .from("leads")
    .insert({
      name: fields.name,
      phone: fields.phone,
      email: fields.email || null,
      source: fields.source,
      service_type: fields.service_type,
      city: fields.city,
      area: fields.area || null,
      plot_size: fields.plot_size || null,
      budget: fields.budget || null,
      notes: fields.notes || null,
      khata_type: fields.khata_type || null,
      planning_timeline: fields.planning_timeline || null,
      assigned_to: assignedTo,
      stage: "enquiryReceived",
    })
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
  return { id: data.id as string };
}

export async function updateLeadFull(leadId: string, fields: LeadFormInput) {
  const { supabase } = await requireManager();
  const { error } = await supabase
    .from("leads")
    .update({
      name: fields.name,
      phone: fields.phone,
      email: fields.email || null,
      source: fields.source,
      service_type: fields.service_type,
      city: fields.city,
      area: fields.area || null,
      plot_size: fields.plot_size || null,
      budget: fields.budget || null,
      notes: fields.notes || null,
      khata_type: fields.khata_type || null,
      planning_timeline: fields.planning_timeline || null,
    })
    .eq("id", leadId);
  if (error) throw new Error(error.message);
  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
}

// Mirrors Flutter's LeadsNotifier.logCall — inserts the call record and
// updates the lead's outcome/contact time together, auto-advancing stage
// the same way the mobile app does (interested -> called, notInterested ->
// lost, future -> future; callback/notReachable leave stage untouched).
export async function logCall(
  leadId: string,
  outcome: CallOutcome,
  durationSeconds: number,
  notes: string | null,
  followupAt: string | null,
  futureTag: FutureTag | null,
) {
  const { supabase, userId } = await requireManager();

  const { error: logError } = await supabase.from("call_logs").insert({
    lead_id: leadId,
    called_by: userId,
    called_at: new Date().toISOString(),
    duration_seconds: durationSeconds,
    outcome,
    notes,
  });
  if (logError) throw new Error(logError.message);

  const stageByOutcome: Partial<Record<CallOutcome, LeadStage>> = {
    interested: "telecallerCallDone",
    notInterested: "lost",
    future: "future",
  };

  const { error: leadError } = await supabase
    .from("leads")
    .update({
      last_outcome: outcome,
      last_contacted_at: new Date().toISOString(),
      followup_at: followupAt,
      future_tag: futureTag,
      ...(stageByOutcome[outcome] ? { stage: stageByOutcome[outcome] } : {}),
    })
    .eq("id", leadId);
  if (leadError) throw new Error(leadError.message);

  revalidatePath("/leads");
  revalidatePath(`/leads/${leadId}`);
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
