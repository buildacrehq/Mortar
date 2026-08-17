"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { CITY_LABEL } from "@/lib/constants";
import type { City } from "@/lib/types";

const ROLE_LABEL: Record<string, string> = { telecaller: "Telecaller", manager: "Manager", admin: "Admin" };

export function ProfileForm({
  userId,
  name: initialName,
  email,
  phone: initialPhone,
  role,
  city,
}: {
  userId: string;
  name: string;
  email: string;
  phone: string;
  role: string;
  city: City | null;
}) {
  const router = useRouter();
  const [name, setName] = useState(initialName);
  const [phone, setPhone] = useState(initialPhone);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setSaved(false);
    const supabase = createClient();
    await supabase.from("profiles").update({ name: name.trim(), phone: phone.trim() || null }).eq("id", userId);
    setSaving(false);
    setSaved(true);
    router.refresh();
  }

  const inputClass =
    "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none";

  return (
    <form onSubmit={handleSave} className="space-y-4">
      <div>
        <label className="mb-1 block text-sm font-medium text-zinc-700">Name</label>
        <input value={name} onChange={(e) => setName(e.target.value)} required className={inputClass} />
      </div>
      <div>
        <label className="mb-1 block text-sm font-medium text-zinc-700">Phone</label>
        <input value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClass} />
      </div>
      <div className="grid grid-cols-2 gap-4 text-sm text-zinc-500">
        <div>
          <p className="text-xs text-zinc-400">Email</p>
          <p>{email}</p>
        </div>
        <div>
          <p className="text-xs text-zinc-400">Role</p>
          <p>
            {ROLE_LABEL[role] ?? role} {city && `· ${CITY_LABEL[city]}`}
          </p>
        </div>
      </div>
      <div className="flex items-center gap-3">
        <button
          type="submit"
          disabled={saving}
          className="rounded-md bg-[#0D1B2A] px-4 py-2 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50"
        >
          {saving ? "Saving…" : "Save"}
        </button>
        {saved && <span className="text-sm text-emerald-600">Saved</span>}
      </div>
    </form>
  );
}
