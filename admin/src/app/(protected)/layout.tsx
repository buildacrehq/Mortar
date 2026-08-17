import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { SignOutButton } from "@/components/sign-out-button";

const NAV_GROUPS = [
  {
    label: null,
    items: [{ href: "/", label: "Dashboard" }],
  },
  {
    label: "Leads",
    items: [
      { href: "/leads", label: "All Leads" },
      { href: "/leads/kanban", label: "Kanban" },
      { href: "/queue", label: "Today's Queue" },
      { href: "/leads/followups", label: "Follow-ups" },
      { href: "/leads/lost", label: "Lost Leads" },
      { href: "/leads/future", label: "Future Pipeline" },
      { href: "/leads/import", label: "Bulk Import" },
    ],
  },
  {
    label: "Analytics",
    items: [
      { href: "/city-analytics", label: "City Analytics" },
      { href: "/performance", label: "Performance" },
      { href: "/reports", label: "Reports" },
    ],
  },
  {
    label: "Team",
    items: [
      { href: "/assignment", label: "Assignment" },
      { href: "/team", label: "Team" },
    ],
  },
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
      <aside className="flex w-56 shrink-0 flex-col justify-between overflow-y-auto bg-[#0D1B2A] px-4 py-6">
        <div>
          <div className="mb-6 px-2">
            <p className="text-lg font-semibold text-white">Mortar</p>
            <p className="text-xs text-zinc-400">Admin</p>
          </div>
          <nav className="flex flex-col gap-4">
            {NAV_GROUPS.map((group, i) => (
              <div key={i}>
                {group.label && (
                  <p className="mb-1 px-3 text-[10px] font-semibold uppercase tracking-wider text-zinc-500">
                    {group.label}
                  </p>
                )}
                <div className="flex flex-col gap-0.5">
                  {group.items.map((item) => (
                    <Link
                      key={item.href}
                      href={item.href}
                      className="rounded-md px-3 py-1.5 text-sm text-zinc-300 transition-colors hover:bg-white/10 hover:text-white"
                    >
                      {item.label}
                    </Link>
                  ))}
                </div>
              </div>
            ))}
          </nav>
        </div>
        <div className="px-2">
          <Link href="/profile" className="mb-2 block text-sm text-zinc-300 hover:text-white hover:underline">
            {profile.name}
          </Link>
          <SignOutButton />
        </div>
      </aside>
      <main className="flex-1 overflow-y-auto bg-zinc-50 p-8">{children}</main>
    </div>
  );
}
