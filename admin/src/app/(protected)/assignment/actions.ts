"use server";

import { revalidatePath } from "next/cache";
import { requireManager } from "@/lib/require-manager";
import type { AssignmentStrategy, LeadSource } from "@/lib/types";

export async function setAssignmentStrategy(strategy: AssignmentStrategy) {
  const { supabase } = await requireManager();

  // Mirrors the Flutter app's team_settings_provider: read the existing singleton
  // row (if any) and update it by id, since upsert() without a matching id would
  // insert a new row rather than overwrite the existing settings.
  const { data: existing } = await supabase.from("team_settings").select("id").limit(1).single();

  const { error } = existing
    ? await supabase
        .from("team_settings")
        .update({ assignment_strategy: strategy, updated_at: new Date().toISOString() })
        .eq("id", existing.id)
    : await supabase
        .from("team_settings")
        .insert({ assignment_strategy: strategy, updated_at: new Date().toISOString() });

  if (error) throw new Error(error.message);
  revalidatePath("/assignment");
}

// Routes new leads by source (and optionally campaign) to a pool of
// telecallers instead of the generic strategy above — e.g. "all Website
// leads go to Priya" or "Facebook campaign 23 rotates between Ravi and Divya".
export async function createAssignmentRule(
  source: LeadSource,
  campaign: string | null,
  assigneeIds: string[],
) {
  const { supabase } = await requireManager();
  if (assigneeIds.length === 0) throw new Error("Pick at least one telecaller");

  const { error } = await supabase.from("assignment_rules").insert({
    source,
    campaign: campaign || null,
    assignee_ids: assigneeIds,
  });
  if (error) {
    if (error.message.includes("assignment_rules_source_campaign_key")) {
      throw new Error(
        campaign
          ? `A rule for ${source} + "${campaign}" already exists — delete it first to replace it.`
          : `A source-only rule for ${source} already exists — delete it first to replace it.`,
      );
    }
    throw new Error(error.message);
  }
  revalidatePath("/assignment");
}

export async function updateAssignmentRule(
  id: string,
  source: LeadSource,
  campaign: string | null,
  assigneeIds: string[],
) {
  const { supabase } = await requireManager();
  if (assigneeIds.length === 0) throw new Error("Pick at least one telecaller");

  const { error } = await supabase
    .from("assignment_rules")
    .update({ source, campaign: campaign || null, assignee_ids: assigneeIds })
    .eq("id", id);
  if (error) {
    if (error.message.includes("assignment_rules_source_campaign_key")) {
      throw new Error(
        campaign
          ? `A rule for ${source} + "${campaign}" already exists — pick a different combination.`
          : `A source-only rule for ${source} already exists — pick a different combination.`,
      );
    }
    throw new Error(error.message);
  }
  revalidatePath("/assignment");
}

export async function deleteAssignmentRule(id: string) {
  const { supabase } = await requireManager();
  const { error } = await supabase.from("assignment_rules").delete().eq("id", id);
  if (error) throw new Error(error.message);
  revalidatePath("/assignment");
}

export async function toggleAssignmentRule(id: string, isActive: boolean) {
  const { supabase } = await requireManager();
  const { error } = await supabase.from("assignment_rules").update({ is_active: isActive }).eq("id", id);
  if (error) throw new Error(error.message);
  revalidatePath("/assignment");
}
