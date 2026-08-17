"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { BACKEND_URL, CITY_LABEL } from "@/lib/constants";
import type { Profile, UserRole, City } from "@/lib/types";

const ROLE_LABEL: Record<UserRole, string> = {
  telecaller: "Telecaller",
  manager: "Manager",
  admin: "Admin",
};

export function TeamManager({
  members,
  currentUserId,
}: {
  members: Profile[];
  currentUserId: string;
}) {
  const router = useRouter();
  const [showForm, setShowForm] = useState(false);
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function authHeader() {
    const supabase = createClient();
    const {
      data: { session },
    } = await supabase.auth.getSession();
    return `Bearer ${session?.access_token ?? ""}`;
  }

  async function handleDeactivate(id: string) {
    if (!confirm("Deactivate this member? They will no longer be able to log in.")) return;
    setPendingId(id);
    setError(null);
    try {
      const res = await fetch(`${BACKEND_URL}/team/remove-member/${id}`, {
        method: "DELETE",
        headers: { Authorization: await authHeader() },
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.error ?? "Failed to deactivate member");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to deactivate member");
    } finally {
      setPendingId(null);
    }
  }

  async function handleResetPassword(email: string) {
    const supabase = createClient();
    const { error } = await supabase.auth.resetPasswordForEmail(email);
    if (error) setError(error.message);
    else alert(`Password reset email sent to ${email}`);
  }

  return (
    <div>
      {error && (
        <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-600">
          {error}
        </div>
      )}

      <div className="mb-4 flex justify-end">
        <button
          onClick={() => setShowForm((v) => !v)}
          className="rounded-md bg-[#0D1B2A] px-4 py-2 text-sm font-medium text-white hover:bg-[#1B2E45]"
        >
          {showForm ? "Cancel" : "+ Add Member"}
        </button>
      </div>

      {showForm && (
        <AddMemberForm
          onDone={() => {
            setShowForm(false);
            router.refresh();
          }}
          onError={setError}
          authHeader={authHeader}
        />
      )}

      <div className="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-500">
            <tr>
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">Email</th>
              <th className="px-4 py-3">Role</th>
              <th className="px-4 py-3">City</th>
              <th className="px-4 py-3">Phone</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {members.map((m) => (
              <tr key={m.id} className="border-b border-zinc-100 last:border-0">
                <td className="px-4 py-2.5 font-medium text-[#0D1B2A]">{m.name}</td>
                <td className="px-4 py-2.5 text-zinc-600">{m.email}</td>
                <td className="px-4 py-2.5 text-zinc-600">{ROLE_LABEL[m.role]}</td>
                <td className="px-4 py-2.5 text-zinc-600">{m.city ? CITY_LABEL[m.city] : "—"}</td>
                <td className="px-4 py-2.5 text-zinc-600">{m.phone ?? "—"}</td>
                <td className="px-4 py-2.5">
                  <span
                    className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                      m.is_active ? "bg-emerald-50 text-emerald-600" : "bg-zinc-100 text-zinc-500"
                    }`}
                  >
                    {m.is_active ? "Active" : "Inactive"}
                  </span>
                </td>
                <td className="px-4 py-2.5 text-right">
                  <button
                    onClick={() => handleResetPassword(m.email)}
                    className="mr-3 text-xs text-zinc-500 hover:text-[#0D1B2A]"
                  >
                    Reset password
                  </button>
                  {m.id !== currentUserId && m.is_active && (
                    <button
                      onClick={() => handleDeactivate(m.id)}
                      disabled={pendingId === m.id}
                      className="text-xs text-red-500 hover:text-red-700 disabled:opacity-50"
                    >
                      Deactivate
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function AddMemberForm({
  onDone,
  onError,
  authHeader,
}: {
  onDone: () => void;
  onError: (msg: string | null) => void;
  authHeader: () => Promise<string>;
}) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<UserRole>("telecaller");
  const [city, setCity] = useState<City>("bangalore");
  const [pending, setPending] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setPending(true);
    onError(null);
    try {
      const res = await fetch(`${BACKEND_URL}/team/create-member`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: await authHeader(),
        },
        body: JSON.stringify({
          name,
          email: email.toLowerCase(),
          phone: phone || null,
          password,
          role,
          city,
        }),
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.error ?? "Failed to create member");
      onDone();
    } catch (err) {
      onError(err instanceof Error ? err.message : "Failed to create member");
    } finally {
      setPending(false);
    }
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="mb-4 grid grid-cols-2 gap-3 rounded-xl border border-zinc-200 bg-white p-5 sm:grid-cols-3"
    >
      <input
        placeholder="Name"
        required
        value={name}
        onChange={(e) => setName(e.target.value)}
        className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
      />
      <input
        placeholder="Email"
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
      />
      <input
        placeholder="Phone (optional)"
        value={phone}
        onChange={(e) => setPhone(e.target.value)}
        className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
      />
      <input
        placeholder="Initial password"
        type="password"
        required
        minLength={6}
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
      />
      <select
        value={role}
        onChange={(e) => setRole(e.target.value as UserRole)}
        className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
      >
        <option value="telecaller">Telecaller</option>
        <option value="manager">Manager</option>
        <option value="admin">Admin</option>
      </select>
      <select
        value={city}
        onChange={(e) => setCity(e.target.value as City)}
        className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900"
      >
        <option value="bangalore">Bangalore</option>
        <option value="mysore">Mysore</option>
      </select>
      <button
        type="submit"
        disabled={pending}
        className="col-span-2 rounded-md bg-[#0D1B2A] py-2 text-sm font-medium text-white hover:bg-[#1B2E45] disabled:opacity-50 sm:col-span-3"
      >
        {pending ? "Creating…" : "Create Member"}
      </button>
    </form>
  );
}
