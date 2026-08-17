import { STAGE_COLOR, STAGE_LABEL } from "@/lib/constants";
import type { LeadStage } from "@/lib/types";

export function StageBadge({ stage }: { stage: LeadStage }) {
  const color = STAGE_COLOR[stage];
  return (
    <span
      className="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium"
      style={{ backgroundColor: `${color}1F`, color }}
    >
      {STAGE_LABEL[stage]}
    </span>
  );
}
