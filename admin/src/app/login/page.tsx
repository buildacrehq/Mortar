"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setPending(true);

    const supabase = createClient();
    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      setError(signInError.message);
      setPending(false);
      return;
    }

    // Managers/admins only — telecallers use the Flutter app.
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", data.user.id)
      .single();

    if (profile?.role === "telecaller") {
      await supabase.auth.signOut();
      setError("This account is set up for the mobile app, not the admin site.");
      setPending(false);
      return;
    }

    router.replace("/");
    router.refresh();
  }

  return (
    <div className="flex flex-1 items-center justify-center bg-[#0D1B2A]">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm rounded-xl bg-white p-8 shadow-lg"
      >
        <h1 className="mb-1 text-xl font-semibold text-[#0D1B2A]">Mortar Admin</h1>
        <p className="mb-6 text-sm text-zinc-500">Sign in with your manager/admin account</p>

        <label className="mb-1 block text-sm font-medium text-zinc-700">Email</label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mb-4 w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
        />

        <label className="mb-1 block text-sm font-medium text-zinc-700">Password</label>
        <input
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-4 w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-[#F5A623] focus:outline-none"
        />

        {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

        <button
          type="submit"
          disabled={pending}
          className="w-full rounded-md bg-[#0D1B2A] py-2 text-sm font-medium text-white transition-colors hover:bg-[#1B2E45] disabled:opacity-50"
        >
          {pending ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </div>
  );
}
