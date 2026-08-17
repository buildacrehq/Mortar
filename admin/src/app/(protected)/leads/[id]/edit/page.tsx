import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { EditLeadForm } from "@/components/edit-lead-form";
import type { Lead } from "@/lib/types";

export default async function EditLeadPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: lead } = await supabase.from("leads").select("*").eq("id", id).returns<Lead[]>().single();
  if (!lead) notFound();

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Edit Lead</h1>
      <EditLeadForm
        leadId={lead.id}
        initial={{
          name: lead.name,
          phone: lead.phone,
          email: lead.email ?? "",
          source: lead.source,
          service_type: lead.service_type,
          city: lead.city,
          area: lead.area ?? "",
          plot_size: lead.plot_size ?? "",
          budget: lead.budget ?? "",
          notes: lead.notes ?? "",
          khata_type: lead.khata_type ?? "",
          planning_timeline: lead.planning_timeline ?? "",
        }}
      />
    </div>
  );
}
