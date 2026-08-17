import { createClient } from "@/lib/supabase/server";
import { NewLeadForm } from "@/components/new-lead-form";
import type { Profile } from "@/lib/types";

export default async function NewLeadPage() {
  const supabase = await createClient();

  const { data: telecallers } = await supabase
    .from("profiles")
    .select("id, name, email, role, city, phone, is_active")
    .eq("role", "telecaller")
    .eq("is_active", true)
    .order("name")
    .returns<Profile[]>();

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">New Lead</h1>
      <NewLeadForm telecallers={telecallers ?? []} />
    </div>
  );
}
