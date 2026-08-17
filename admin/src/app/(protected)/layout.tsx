import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { SignOutButton } from "@/components/sign-out-button";

const NAV = [
  { href: "/", label: "Dashboard" },
  { href: "/leads", label: "Leads" },
  { href: "/leads/followups", label: "Follow-ups" },
  { href: "/assignment", label: "Assignment" },
  { href: "/team", label: "Team" },
];

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // proxy.ts already redirects unauthenticated requests, but Server Components
  // can't rely on that alone — verify again close to the data source.
  if (!user) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("name, role")
    .eq("id", user.id)
    .single();

  if (!profile || profile.role === "telecaller") {
    await supabase.auth.signOut();
    redirect("/login");
  }

  return (
    <div className="flex min-h-screen flex-1">
      <aside className="flex w-56 flex-col justify-between bg-[#0D1B2A] px-4 py-6">
        <div>
          <div className="mb-8 px-2">
            <p className="text-lg font-semibold text-white">Mortar</p>
            <p className="text-xs text-zinc-400">Admin</p>
          </div>
          <nav className="flex flex-col gap-1">
            {NAV.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="rounded-md px-3 py-2 text-sm text-zinc-300 transition-colors hover:bg-white/10 hover:text-white"
              >
                {item.label}
              </Link>
            ))}
          </nav>
        </div>
        <div className="px-2">
          <p className="mb-2 text-sm text-zinc-300">{profile.name}</p>
          <SignOutButton />
        </div>
      </aside>
      <main className="flex-1 bg-zinc-50 p-8">{children}</main>
    </div>
  );
}
