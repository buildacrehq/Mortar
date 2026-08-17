import { createClient } from "@/lib/supabase/server";
import { PerformanceView } from "@/components/performance-view";
import type { LeadSummary, CallLogSummary, Profile } from "@/lib/types";

export default async function PerformancePage() {
  const supabase = await createClient();

  const [{ data: leadsData }, { data: logsData }, { data: telecallersData }] = await Promise.all([
    supabase
      .from("leads")
      .select("id, assigned_to, stage, source, service_type, city, created_at, followup_at")
      .returns<LeadSummary[]>(),
    supabase
      .from("call_logs")
      .select("lead_id, called_by, called_at, duration_seconds, outcome")
      .returns<CallLogSummary[]>(),
    supabase
      .from("profiles")
      .select("id, name, email, role, city, phone, is_active")
      .eq("role", "telecaller")
      .returns<Profile[]>(),
  ]);

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Telecaller Performance</h1>
      <PerformanceView leads={leadsData ?? []} logs={logsData ?? []} telecallers={telecallersData ?? []} />
    </div>
  );
}
