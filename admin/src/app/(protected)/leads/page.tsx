import { createClient } from "@/lib/supabase/server";
import { LeadsTable } from "@/components/leads-table";

export default async function LeadsPage() {
  const supabase = await createClient();

  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, name, email, role, city, phone, is_active")
    .eq("role", "telecaller")
    .order("name");

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Leads</h1>
      <LeadsTable telecallers={profiles ?? []} />
    </div>
  );
}
