"use client";

import { useState } from "react";
import {
  SOURCE_LABEL,
  SERVICE_TYPE_LABEL,
  CITY_LABEL,
  KHATA_LABEL,
  PLANNING_LABEL,
} from "@/lib/constants";
import type { LeadFormInput, LeadSource, ServiceType, City, KhataType, PlanningTimeline, Profile } from "@/lib/types";

const SOURCES: LeadSource[] = ["facebook", "instagram", "website", "phone", "whatsapp", "referral"];
const SERVICE_TYPES: ServiceType[] = ["construction", "renovation", "interiors"];
const CITIES: City[] = ["bangalore", "mysore"];
const KHATA_TYPES: KhataType[] = ["aKhata", "bKhata", "bda", "bmrda", "panchayat", "other"];
const PLANNING_TIMELINES: PlanningTimeline[] = ["immediate", "within3Months", "within6Months", "withinYear"];

const EMPTY: LeadFormInput = {
  name: "",
  phone: "",
  email: "",
  source: "phone",
  service_type: "construction",
  city: "bangalore",
  area: "",
  plot_size: "",
  budget: "",
  notes: "",
  khata_type: "",
  planning_timeline: "",
};

const inputClass =
  "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none";
const labelClass = "mb-1 block text-sm font-medium text-zinc-700";

export function LeadForm({
  initial,
  telecallers,
  onSubmit,
  submitLabel,
}: {
  initial?: Partial<LeadFormInput>;
  telecallers?: Profile[];
  // Resolves normally on success (server action returns data, doesn't redirect
  // itself) so the caller can navigate — keeps redirect() out of a try/catch,
  // which Next.js explicitly warns against since redirect() always throws.
  onSubmit: (fields: LeadFormInput, assignedTo: string | null) => Promise<void>;
  submitLabel: string;
}) {
  const [fields, setFields] = useState<LeadFormInput>({ ...EMPTY, ...initial });
  const [assignedTo, setAssignedTo] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function set<K extends keyof LeadFormInput>(key: K, value: LeadFormInput[K]) {
    setFields((f) => ({ ...f, [key]: value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!fields.name.trim() || !fields.phone.trim()) {
      setError("Name and phone are required");
      return;
    }
    setError(null);
    setPending(true);
    try {
      await onSubmit(fields, telecallers ? assignedTo || null : null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save lead");
      setPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="max-w-2xl space-y-6">
      {error && (
        <div className="rounded-md border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-600">
          {error}
        </div>
      )}

      <section className="rounded-xl border border-zinc-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-zinc-500">Contact Info</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className={labelClass}>Name *</label>
            <input
              required
              value={fields.name}
              onChange={(e) => set("name", e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Phone *</label>
            <input
              required
              value={fields.phone}
              onChange={(e) => set("phone", e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Email</label>
            <input
              type="email"
              value={fields.email}
              onChange={(e) => set("email", e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Source</label>
            <select
              value={fields.source}
              onChange={(e) => set("source", e.target.value as LeadSource)}
              className={inputClass}
            >
              {SOURCES.map((s) => (
                <option key={s} value={s}>
                  {SOURCE_LABEL[s]}
                </option>
              ))}
            </select>
          </div>
        </div>
      </section>

      <section className="rounded-xl border border-zinc-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-zinc-500">Project Details</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className={labelClass}>Service Type</label>
            <select
              value={fields.service_type}
              onChange={(e) => set("service_type", e.target.value as ServiceType)}
              className={inputClass}
            >
              {SERVICE_TYPES.map((s) => (
                <option key={s} value={s}>
                  {SERVICE_TYPE_LABEL[s]}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className={labelClass}>City</label>
            <select
              value={fields.city}
              onChange={(e) => set("city", e.target.value as City)}
              className={inputClass}
            >
              {CITIES.map((c) => (
                <option key={c} value={c}>
                  {CITY_LABEL[c]}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className={labelClass}>Area</label>
            <input value={fields.area} onChange={(e) => set("area", e.target.value)} className={inputClass} />
          </div>
          <div>
            <label className={labelClass}>Plot Size</label>
            <input
              value={fields.plot_size}
              onChange={(e) => set("plot_size", e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>Budget</label>
            <input value={fields.budget} onChange={(e) => set("budget", e.target.value)} className={inputClass} />
          </div>
          <div>
            <label className={labelClass}>Khata Type</label>
            <select
              value={fields.khata_type}
              onChange={(e) => set("khata_type", e.target.value as KhataType | "")}
              className={inputClass}
            >
              <option value="">Not set</option>
              {KHATA_TYPES.map((k) => (
                <option key={k} value={k}>
                  {KHATA_LABEL[k]}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className={labelClass}>Planning Timeline</label>
            <select
              value={fields.planning_timeline}
              onChange={(e) => set("planning_timeline", e.target.value as PlanningTimeline | "")}
              className={inputClass}
            >
              <option value="">Not set</option>
              {PLANNING_TIMELINES.map((p) => (
                <option key={p} value={p}>
                  {PLANNING_LABEL[p]}
                </option>
              ))}
            </select>
          </div>
        </div>
        <div className="mt-4">
          <label className={labelClass}>Notes</label>
          <textarea
            rows={3}
            value={fields.notes}
            onChange={(e) => set("notes", e.target.value)}
            className={inputClass}
          />
        </div>
      </section>

      {telecallers && (
        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-4 text-sm font-semibold text-zinc-500">Assignment</h2>
          <label className={labelClass}>Assign To</label>
          <select value={assignedTo} onChange={(e) => setAssignedTo(e.target.value)} className={inputClass}>
            <option value="">Unassigned</option>
            {telecallers.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
        </section>
      )}

      <button
        type="submit"
        disabled={pending}
        className="rounded-md bg-[#0D1B2A] px-6 py-2.5 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50"
      >
        {pending ? "Saving…" : submitLabel}
      </button>
    </form>
  );
}
