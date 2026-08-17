"use client";

import { useState } from "react";
import { STRATEGY_ORDER, STRATEGY_LABEL, STRATEGY_DESCRIPTION } from "@/lib/constants";
import { setAssignmentStrategy } from "@/app/(protected)/assignment/actions";
import type { AssignmentStrategy } from "@/lib/types";

export function StrategySelector({ current }: { current: AssignmentStrategy }) {
  const [selected, setSelected] = useState(current);
  const [pending, setPending] = useState(false);

  async function handleSelect(strategy: AssignmentStrategy) {
    setSelected(strategy);
    setPending(true);
    await setAssignmentStrategy(strategy);
    setPending(false);
  }

  return (
    <div className="space-y-2">
      {STRATEGY_ORDER.map((s) => (
        <button
          key={s}
          disabled={pending}
          onClick={() => handleSelect(s)}
          className={`w-full rounded-lg border px-3 py-2 text-left text-sm transition-colors disabled:opacity-50 ${
            selected === s
              ? "border-[#F5A623] bg-[#F5A623]/10"
              : "border-zinc-200 hover:bg-zinc-50"
          }`}
        >
          <span className="font-medium text-[#0D1B2A]">{STRATEGY_LABEL[s]}</span>
          <p className="mt-0.5 text-xs text-zinc-500">{STRATEGY_DESCRIPTION[s]}</p>
        </button>
      ))}
    </div>
  );
}
