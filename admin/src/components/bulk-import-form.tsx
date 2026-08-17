"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { SOURCE_LABEL, SERVICE_TYPE_LABEL, CITY_LABEL } from "@/lib/constants";
import { bulkImportLeads } from "@/app/(protected)/leads/actions";
import type { LeadSource, ServiceType, City, Profile } from "@/lib/types";

type ParsedLead = { name: string; phone: string; isDuplicate: boolean };

const SOURCES: LeadSource[] = ["facebook", "instagram", "website", "phone", "whatsapp", "referral"];
const SERVICE_TYPES: ServiceType[] = ["construction", "renovation", "interiors"];
const CITIES: City[] = ["bangalore", "mysore"];

function parseLeads(text: string, existingPhones: Set<string>): ParsedLead[] {
  const lines = text.trim().split("\n");
  const parsed: ParsedLead[] = [];

  for (const line of lines) {
    if (!line.trim()) continue;
    const parts = line.split(/[,\t]/).map((p) => p.trim());

    let name = "";
    let phone = "";

    if (parts.length >= 2) {
      const firstDigits = parts[0].replace(/\D/g, "");
      if (firstDigits.length >= 10) {
        phone = firstDigits;
        name = parts[1];
      } else {
        name = parts[0];
        phone = parts[1].replace(/\D/g, "");
      }
    } else {
      phone = parts[0].replace(/\D/g, "");
    }

    if (phone.length < 10) continue;
    if (phone.length > 10) phone = phone.slice(-10);

    parsed.push({
      name: name || `Lead ${phone}`,
      phone,
      isDuplicate: existingPhones.has(phone),
    });
  }

  return parsed;
}

export function BulkImportForm({
  existingPhones,
  telecallers,
}: {
  existingPhones: string[];
  telecallers: Profile[];
}) {
  const router = useRouter();
  const [text, setText] = useState("");
  const [source, setSource] = useState<LeadSource>("facebook");
  const [serviceType, setServiceType] = useState<ServiceType>("construction");
  const [city, setCity] = useState<City>("bangalore");
  const [assignedTo, setAssignedTo] = useState("");
  const [parsed, setParsed] = useState<ParsedLead[] | null>(null);
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState<{ imported: number; duplicates: number } | null>(null);

  const existingSet = new Set(existingPhones);

  function handleParse() {
    setParsed(parseLeads(text, existingSet));
    setResult(null);
  }

  async function handleImport() {
    if (!parsed) return;
    const toImport = parsed.filter((l) => !l.isDuplicate);
    if (toImport.length === 0) return;
    setImporting(true);
    await bulkImportLeads(toImport, source, serviceType, city, assignedTo || null);
    setResult({ imported: toImport.length, duplicates: parsed.length - toImport.length });
    setImporting(false);
    setParsed(null);
    setText("");
    router.refresh();
  }

  const inputClass =
    "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none";

  return (
    <div className="max-w-2xl space-y-6">
      <section className="rounded-xl border border-zinc-200 bg-white p-5">
        <h2 className="mb-2 text-sm font-semibold text-zinc-500">Paste Leads</h2>
        <p className="mb-3 text-xs text-zinc-400">
          One per line — &quot;Name, Phone&quot;, &quot;Phone, Name&quot;, or just a phone number.
        </p>
        <textarea
          rows={8}
          value={text}
          onChange={(e) => {
            setText(e.target.value);
            setParsed(null);
          }}
          placeholder={"Ravi Kumar, 9876543210\n9845012345, Priya Shah\n9900011122"}
          className={`${inputClass} font-mono`}
        />
        <button
          onClick={handleParse}
          disabled={!text.trim()}
          className="mt-3 rounded-md border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
        >
          Parse
        </button>
      </section>

      {parsed && (
        <section className="rounded-xl border border-zinc-200 bg-white p-5">
          <h2 className="mb-3 text-sm font-semibold text-zinc-500">
            Preview — {parsed.length} row{parsed.length === 1 ? "" : "s"} (
            {parsed.filter((l) => l.isDuplicate).length} duplicate
            {parsed.filter((l) => l.isDuplicate).length === 1 ? "" : "s"} skipped)
          </h2>
          <div className="max-h-64 overflow-y-auto rounded-lg border border-zinc-100">
            <table className="w-full text-left text-sm">
              <tbody>
                {parsed.map((l, i) => (
                  <tr key={i} className={`border-b border-zinc-50 last:border-0 ${l.isDuplicate ? "opacity-40" : ""}`}>
                    <td className="px-3 py-1.5">{l.name}</td>
                    <td className="px-3 py-1.5 text-zinc-500">{l.phone}</td>
                    <td className="px-3 py-1.5 text-xs">
                      {l.isDuplicate ? (
                        <span className="text-red-500">Duplicate</span>
                      ) : (
                        <span className="text-emerald-600">New</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section className="rounded-xl border border-zinc-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-zinc-500">Apply To All Imported Leads</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="mb-1 block text-sm font-medium text-zinc-700">Source</label>
            <select value={source} onChange={(e) => setSource(e.target.value as LeadSource)} className={inputClass}>
              {SOURCES.map((s) => (
                <option key={s} value={s}>
                  {SOURCE_LABEL[s]}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-zinc-700">Service Type</label>
            <select
              value={serviceType}
              onChange={(e) => setServiceType(e.target.value as ServiceType)}
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
            <label className="mb-1 block text-sm font-medium text-zinc-700">City</label>
            <select value={city} onChange={(e) => setCity(e.target.value as City)} className={inputClass}>
              {CITIES.map((c) => (
                <option key={c} value={c}>
                  {CITY_LABEL[c]}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-zinc-700">Assign To</label>
            <select value={assignedTo} onChange={(e) => setAssignedTo(e.target.value)} className={inputClass}>
              <option value="">Unassigned</option>
              {telecallers.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          </div>
        </div>
      </section>

      {result && (
        <div className="rounded-md border border-emerald-200 bg-emerald-50 px-4 py-2 text-sm text-emerald-700">
          Imported {result.imported} lead{result.imported === 1 ? "" : "s"}
          {result.duplicates > 0 && ` — skipped ${result.duplicates} duplicate${result.duplicates === 1 ? "" : "s"}`}
        </div>
      )}

      <button
        onClick={handleImport}
        disabled={!parsed || parsed.filter((l) => !l.isDuplicate).length === 0 || importing}
        className="rounded-md bg-[#0D1B2A] px-6 py-2.5 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50"
      >
        {importing ? "Importing…" : `Import ${parsed ? parsed.filter((l) => !l.isDuplicate).length : ""} Leads`}
      </button>
    </div>
  );
}
