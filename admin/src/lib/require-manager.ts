import "server-only";
import { createClient } from "@/lib/supabase/server";

export async function requireManager() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data: profile } = await supabase
    .from("profiles")
    .select("name, role")
    .eq("id", user.id)
    .single();
  if (!profile || profile.role === "telecaller") {
    throw new Error("Not authorized");
  }
  return { supabase, userId: user.id, name: profile.name as string };
}
