import type { RiskLevel } from "../types";

const STYLES: Record<RiskLevel, { bg: string; border: string; fg: string }> = {
  low: {
    bg: "var(--risk-low-bg)",
    border: "var(--risk-low-border)",
    fg: "var(--risk-low)",
  },
  medium: {
    bg: "var(--risk-medium-bg)",
    border: "var(--risk-medium-border)",
    fg: "var(--risk-medium)",
  },
  high: {
    bg: "var(--risk-high-bg)",
    border: "var(--risk-high-border)",
    fg: "var(--risk-high)",
  },
};

export default function RiskBadge({
  risk,
  probability,
}: {
  risk: RiskLevel;
  probability?: number;
}) {
  const s = STYLES[risk];
  // Labelled "score", not a percentage: this is an uncalibrated model output
  // from a synthetic-data model, and "HIGH (91%)" reads as a clinical
  // probability of a condition, which it is not.
  const score =
    probability !== undefined
      ? ` · score ${probability.toFixed(2)}`
      : "";
  return (
    <span
      style={{
        display: "inline-block",
        padding: "3px 10px",
        borderRadius: "999px",
        background: s.bg,
        border: `1px solid ${s.border}`,
        color: s.fg,
        fontSize: "12px",
        fontWeight: 700,
        textTransform: "uppercase",
        whiteSpace: "nowrap",
      }}
    >
      {risk}
      {score}
    </span>
  );
}