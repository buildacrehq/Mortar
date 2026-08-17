import { createClient } from "@/lib/supabase/server";
import { ProfileForm } from "@/components/profile-form";
import { ChangePasswordForm } from "@/components/change-password-form";

export default async function ProfilePage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, name, email, phone, role, city")
    .eq("id", user!.id)
    .single();

  if (!profile) return null;

  return (
    <div className="max-w-lg">
      <h1 className="mb-6 text-2xl font-semibold text-[#0D1B2A]">Profile</h1>

      <section className="mb-6 rounded-xl border border-zinc-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-zinc-500">Your Details</h2>
        <ProfileForm
          userId={profile.id}
          name={profile.name}
          email={profile.email}
          phone={profile.phone ?? ""}
          role={profile.role}
          city={profile.city}
        />
      </section>

      <section className="rounded-xl border border-zinc-200 bg-white p-5">
        <h2 className="mb-4 text-sm font-semibold text-zinc-500">Change Password</h2>
        <ChangePasswordForm email={profile.email} />
      </section>
    </div>
  );
}
