import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { LeadSource } from "./types";

type Rule = { assignee_ids: string[] };

// Prefers a source+campaign rule over a source-only rule for the same source.
async function findMatchingRule(
  supabase: SupabaseClient,
  source: LeadSource,
  campaign: string | null,
): Promise<Rule | null> {
  if (campaign) {
    const { data } = await supabase
      .from("assignment_rules")
      .select("assignee_ids")
      .eq("source", source)
      .eq("campaign", campaign)
      .eq("is_active", true)
      .maybeSingle();
    if (data) return data;
  }

  const { data } = await supabase
    .from("assignment_rules")
    .select("assignee_ids")
    .eq("source", source)
    .is("campaign", null)
    .eq("is_active", true)
    .maybeSingle();
  return data;
}

async function currentLoadCounts(
  supabase: SupabaseClient,
  assigneeIds: string[],
): Promise<Map<string, number>> {
  const counts = await Promise.all(
    assigneeIds.map(async (id) => {
      const { count } = await supabase
        .from("leads")
        .select("id", { count: "exact", head: true })
        .eq("assigned_to", id);
      return [id, count ?? 0] as const;
    }),
  );
  return new Map(counts);
}

// Finds the best-matching active rule for a single lead and returns who it
// should go to (round-robin: whoever in the rule's pool currently has the
// fewest total assigned leads). Returns null if no rule matches — caller
// should fall back to whatever it was already doing (leaving unassigned, etc).
export async function pickAssigneeForNewLead(
  supabase: SupabaseClient,
  source: LeadSource,
  campaign: string | null,
): Promise<string | null> {
  const rule = await findMatchingRule(supabase, source, campaign);
  if (!rule || rule.assignee_ids.length === 0) return null;
  if (rule.assignee_ids.length === 1) return rule.assignee_ids[0];

  const counts = await currentLoadCounts(supabase, rule.assignee_ids);
  return [...counts.entries()].sort((a, b) => a[1] - b[1])[0][0];
}

// Same idea, but for a whole batch (bulk import) — querying live DB counts
// per-lead-in-a-loop would have every lead see the same "currently lowest"
// person, since nothing's been inserted yet. Instead, fetch starting counts
// once and simulate the rotation in memory as each lead in the batch is
// assigned, so the batch itself distributes evenly.
export async function pickAssigneesForBatch(
  supabase: SupabaseClient,
  source: LeadSource,
  campaign: string | null,
  count: number,
): Promise<(string | null)[]> {
  const rule = await findMatchingRule(supabase, source, campaign);
  if (!rule || rule.assignee_ids.length === 0) return new Array(count).fill(null);
  if (rule.assignee_ids.length === 1) return new Array(count).fill(rule.assignee_ids[0]);

  const counts = await currentLoadCounts(supabase, rule.assignee_ids);
  const result: string[] = [];
  for (let i = 0; i < count; i++) {
    const nextId = [...counts.entries()].sort((a, b) => a[1] - b[1])[0][0];
    result.push(nextId);
    counts.set(nextId, (counts.get(nextId) ?? 0) + 1);
  }
  return result;
}
