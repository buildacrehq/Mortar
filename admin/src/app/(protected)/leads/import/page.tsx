import { createClient } from "@/lib/supabase/server";
import { BulkImportForm } from "@/components/bulk-import-form";
import type { Profile } from "@/lib/types";

export default async function BulkImportPage() {
  const supabase = await createClient();

  const [{ data: leads }, { data: telecallers }] = await Promise.all([
    supabase.from("leads").select("phone"),
    supabase
      .from("profiles")
      .select("id, name, email, role, city, phone, is_active")
      .eq("role", "telecaller")
      .eq("is_active", true)
      .order("name")
      .returns<Profile[]>(),
  ]);

  const existingPhones = (leads ?? []).map((l) => (l.phone as string).replace(/\D/g, ""));

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Bulk Import Leads</h1>
      <BulkImportForm existingPhones={existingPhones} telecallers={telecallers ?? []} />
    </div>
  );
}
