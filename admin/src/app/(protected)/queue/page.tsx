import { createClient } from "@/lib/supabase/server";
import { QueueView } from "@/components/queue-view";
import type { Lead, Profile } from "@/lib/types";

export default async function QueuePage() {
  const supabase = await createClient();

  const [{ data: leadsData }, { data: callLogLeadIds }, { data: telecallers }] = await Promise.all([
    supabase.from("leads").select("*").not("stage", "in", "(lost,finalAgreement)").returns<Lead[]>(),
    supabase.from("call_logs").select("lead_id"),
    supabase
      .from("profiles")
      .select("id, name, email, role, city, phone, is_active")
      .eq("role", "telecaller")
      .order("name")
      .returns<Profile[]>(),
  ]);

  const calledLeadIds = new Set((callLogLeadIds ?? []).map((c) => c.lead_id as string));

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Today&apos;s Queue</h1>
      <QueueView
        leads={leadsData ?? []}
        calledLeadIds={[...calledLeadIds]}
        telecallers={telecallers ?? []}
      />
    </div>
  );
}
