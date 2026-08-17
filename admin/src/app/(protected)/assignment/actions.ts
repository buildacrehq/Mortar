"use server";

import { revalidatePath } from "next/cache";
import { requireManager } from "@/lib/require-manager";
import type { AssignmentStrategy } from "@/lib/types";

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
