"use client";

import { useState } from "react";
import { SOURCE_LABEL } from "@/lib/constants";
import {
  createAssignmentRule,
  updateAssignmentRule,
  deleteAssignmentRule,
  toggleAssignmentRule,
} from "@/app/(protected)/assignment/actions";
import type { AssignmentRule, LeadSource, Profile } from "@/lib/types";

const SOURCES: LeadSource[] = ["facebook", "instagram", "website", "phone", "whatsapp", "referral"];

export function AssignmentRulesManager({
  rules,
  telecallers,
}: {
  rules: AssignmentRule[];
  telecallers: Profile[];
}) {
  const [showForm, setShowForm] = useState(false);
  const [editingRule, setEditingRule] = useState<AssignmentRule | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);

  const tcById = new Map(telecallers.map((t) => [t.id, t]));

  async function handleDelete(id: string) {
    if (!confirm("Delete this rule? New leads matching it will fall back to the generic strategy.")) return;
    setPendingId(id);
    await deleteAssignmentRule(id);
    setPendingId(null);
  }

  async function handleToggle(id: string, isActive: boolean) {
    setPendingId(id);
    await toggleAssignmentRule(id, !isActive);
    setPendingId(null);
  }

  function startEdit(rule: AssignmentRule) {
    setError(null);
    setShowForm(false);
    setEditingRule(rule);
  }

  return (
    <section className="rounded-xl border border-zinc-200 bg-white p-5">
      <div className="mb-1 flex items-center justify-between">
        <h2 className="text-sm font-semibold text-zinc-500">Assignment Rules</h2>
        <button
          onClick={() => {
            setEditingRule(null);
            setError(null);
            setShowForm((v) => !v);
          }}
          className="rounded-md border border-zinc-300 bg-white px-3 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
        >
          {showForm ? "Cancel" : "+ Add Rule"}
        </button>
      </div>
      <p className="mb-4 text-xs text-zinc-400">
        Routes new leads to specific people by source (and campaign, if known) — checked before the
        generic strategy above. Applies to leads from the Google Form sync and to manually/bulk-added
        leads left unassigned.
      </p>

      {error && (
        <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-600">
          {error}
        </div>
      )}

      {showForm && (
        <RuleForm
          telecallers={telecallers}
          onDone={() => setShowForm(false)}
          onError={setError}
        />
      )}

      {editingRule && (
        <RuleForm
          telecallers={telecallers}
          initial={editingRule}
          onDone={() => setEditingRule(null)}
          onError={setError}
        />
      )}

      {rules.length === 0 ? (
        <p className="text-sm text-zinc-400">
          No rules yet — new leads use the generic Assignment Strategy above.
        </p>
      ) : (
        <ul className="space-y-2">
          {rules.map((rule) => (
            <li
              key={rule.id}
              className={`flex items-center justify-between rounded-lg border px-3 py-2 text-sm ${
                rule.is_active ? "border-zinc-200" : "border-zinc-100 opacity-50"
              }`}
            >
              <div>
                <span className="font-medium text-[#0D1B2A]">{SOURCE_LABEL[rule.source]}</span>
                {rule.campaign && (
                  <span className="ml-1.5 rounded-full bg-zinc-100 px-2 py-0.5 text-xs text-zinc-500">
                    {rule.campaign}
                  </span>
                )}
                <span className="ml-2 text-xs text-zinc-500">
                  →{" "}
                  {rule.assignee_ids.map((id) => tcById.get(id)?.name ?? "?").join(", ")}
                </span>
              </div>
              <div className="flex items-center gap-3 text-xs">
                <button
                  disabled={pendingId === rule.id}
                  onClick={() => startEdit(rule)}
                  className="text-zinc-500 hover:text-zinc-700 disabled:opacity-50"
                >
                  Edit
                </button>
                <button
                  disabled={pendingId === rule.id}
                  onClick={() => handleToggle(rule.id, rule.is_active)}
                  className="text-zinc-500 hover:text-zinc-700 disabled:opacity-50"
                >
                  {rule.is_active ? "Disable" : "Enable"}
                </button>
                <button
                  disabled={pendingId === rule.id}
                  onClick={() => handleDelete(rule.id)}
                  className="text-red-500 hover:text-red-700 disabled:opacity-50"
                >
                  Delete
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function RuleForm({
  telecallers,
  initial,
  onDone,
  onError,
}: {
  telecallers: Profile[];
  initial?: AssignmentRule;
  onDone: () => void;
  onError: (msg: string | null) => void;
}) {
  const [source, setSource] = useState<LeadSource>(initial?.source ?? "website");
  const [campaign, setCampaign] = useState(initial?.campaign ?? "");
  const [selectedIds, setSelectedIds] = useState<string[]>(initial?.assignee_ids ?? []);
  const [pending, setPending] = useState(false);

  function toggleTc(id: string) {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    onError(null);
    if (selectedIds.length === 0) {
      onError("Pick at least one telecaller");
      return;
    }
    setPending(true);
    try {
      if (initial) {
        await updateAssignmentRule(initial.id, source, campaign.trim() || null, selectedIds);
      } else {
        await createAssignmentRule(source, campaign.trim() || null, selectedIds);
      }
      onDone();
    } catch (err) {
      onError(err instanceof Error ? err.message : "Failed to save rule");
    } finally {
      setPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="mb-4 space-y-3 rounded-lg border border-zinc-200 p-4">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div>
          <label className="mb-1 block text-xs font-medium text-zinc-700">Source</label>
          <select
            value={source}
            onChange={(e) => setSource(e.target.value as LeadSource)}
            className="w-full rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
          >
            {SOURCES.map((s) => (
              <option key={s} value={s}>
                {SOURCE_LABEL[s]}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1 block text-xs font-medium text-zinc-700">
            Campaign <span className="text-zinc-400">(optional — leave blank to match all {SOURCE_LABEL[source]} leads)</span>
          </label>
          <input
            value={campaign}
            onChange={(e) => setCampaign(e.target.value)}
            placeholder="e.g. campaign 23"
            className="w-full rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
          />
        </div>
      </div>

      <div>
        <label className="mb-1 block text-xs font-medium text-zinc-700">
          Assign to (pick multiple to round-robin between them)
        </label>
        <div className="flex flex-wrap gap-2">
          {telecallers.map((t) => (
            <button
              type="button"
              key={t.id}
              onClick={() => toggleTc(t.id)}
              className={`rounded-md border px-3 py-1.5 text-sm ${
                selectedIds.includes(t.id)
                  ? "border-[#0D1B2A] bg-[#0D1B2A] text-white"
                  : "border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
              }`}
            >
              {t.name}
            </button>
          ))}
        </div>
      </div>

      <button
        type="submit"
        disabled={pending}
        className="rounded-md bg-[#0D1B2A] px-4 py-2 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50"
      >
        {pending ? "Saving…" : initial ? "Update Rule" : "Save Rule"}
      </button>
    </form>
  );
}
