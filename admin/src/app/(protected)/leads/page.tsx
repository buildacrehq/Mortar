import Link from "next/link";
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
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-[#0D1B2A]">Leads</h1>
        <div className="flex gap-2">
          <Link
            href="/leads/kanban"
            className="rounded-md border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-50"
          >
            Kanban View
          </Link>
          <Link
            href="/leads/new"
            className="rounded-md bg-[#0D1B2A] px-4 py-2 text-sm font-medium text-white hover:bg-[#1B2E45]"
          >
            + Add Lead
          </Link>
        </div>
      </div>
      <LeadsTable telecallers={profiles ?? []} />
    </div>
  );
}
