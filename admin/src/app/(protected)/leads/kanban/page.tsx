import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { KanbanBoard } from "@/components/kanban-board";
import type { Lead, Profile } from "@/lib/types";

const ACTIVE_STAGES = [
  "enquiryReceived",
  "telecallerCallDone",
  "meetingAtOffice",
  "siteVisit",
  "quotationSent",
  "negotiation",
  "finalAgreement",
];

export default async function KanbanPage() {
  const supabase = await createClient();

  const [{ data: leads }, { data: telecallers }] = await Promise.all([
    supabase.from("leads").select("*").in("stage", ACTIVE_STAGES).returns<Lead[]>(),
    supabase
      .from("profiles")
      .select("id, name, email, role, city, phone, is_active")
      .eq("role", "telecaller")
      .order("name")
      .returns<Profile[]>(),
  ]);

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-[#0D1B2A]">Kanban</h1>
        <Link href="/leads" className="text-sm text-zinc-500 hover:text-zinc-700">
          ← Back to Leads
        </Link>
      </div>
      <KanbanBoard leads={leads ?? []} telecallers={telecallers ?? []} />
    </div>
  );
}
