import { createClient } from "@/lib/supabase/server";
import { TeamManager } from "@/components/team-manager";
import type { Profile } from "@/lib/types";

export default async function TeamPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, name, email, role, city, phone, is_active")
    .order("name")
    .returns<Profile[]>();

  return (
    <div>
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Team</h1>
      <TeamManager members={profiles ?? []} currentUserId={user?.id ?? ""} />
    </div>
  );
}
