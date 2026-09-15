"use client";
import { useEffect, useMemo, useState } from "react";
import DashboardLayout from "../console-layout";
import RiskBadge from "../../components/risk-badge";
import PageState from "../../components/page-state";
import { fetchPredictions } from "../../lib/api";
import type { Prediction, RiskLevel } from "../../types";

const RISK_LEVELS: RiskLevel[] = ["low", "medium", "high"];

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString();
}

export default function DashboardPage() {
  const [predictions, setPredictions] = useState<Prediction[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchPredictions()
      .then((data) => setPredictions(data))
      .catch((e) => setError(e instanceof Error ? e.message : "Failed to load"))
      .finally(() => setLoading(false));
  }, []);

  const overview = useMemo(() => {
    const latestByPersonnel = new Map<string, Prediction>();
    for (const p of predictions ?? []) {
      if (!latestByPersonnel.has(p.personnel_key)) {
        latestByPersonnel.set(p.personnel_key, p);
      }
    }
    const counts: Record<RiskLevel, number> = { low: 0, medium: 0, high: 0 };
    for (const p of latestByPersonnel.values()) {
      counts[p.risk_level] += 1;
    }
    return { counts, total: latestByPersonnel.size };
  }, [predictions]);

  const recentHighRisk = useMemo(
    () => (predictions ?? []).filter((p) => p.risk_level === "high").slice(0, 5),
    [predictions],
  );

  return (
    <DashboardLayout>
      <section
        style={{
          maxWidth: "960px",
          padding: "24px",
          border: "1px solid var(--border)",
          borderRadius: "12px",
          background: "var(--surface)",
        }}
      >
        <h2 style={{ margin: "0 0 8px", fontSize: "18px" }}>
          Risk overview
        </h2>
        <p style={{ margin: "0 0 16px", color: "var(--text-muted)", fontSize: "14px" }}>
          Latest predicted stress-risk per personnel from synthetic model v1.
        </p>

        <PageState loading={loading} error={error}>
          <div
            style={{
              display: "flex",
              gap: "12px",
              flexWrap: "wrap",
              marginBottom: "24px",
            }}
          >
            {RISK_LEVELS.map((level) => {
              const count = overview.counts[level];
              const s = {
                low: { c: "var(--risk-low)", bg: "var(--risk-low-bg)", border: "var(--risk-low-border)" },
                medium: { c: "var(--risk-medium)", bg: "var(--risk-medium-bg)", border: "var(--risk-medium-border)" },
                high: { c: "var(--risk-high)", bg: "var(--risk-high-bg)", border: "var(--risk-high-border)" },
              }[level];
              return (
                <div
                  key={level}
                  style={{
                    flex: 1,
                    minWidth: "140px",
                    padding: "16px",
                    borderRadius: "8px",
                    border: `1px solid ${s.border}`,
                    background: s.bg,
                    textAlign: "center",
                  }}
                >
                  <div style={{ fontSize: "13px", color: "var(--text-muted)", textTransform: "uppercase", fontWeight: 600 }}>
                    {level}
                  </div>
                  <div style={{ fontSize: "28px", fontWeight: 700, marginTop: "4px", color: s.c }}>
                    {count}
                  </div>
                  <div style={{ fontSize: "12px", color: "var(--text-muted)" }}>
                    latest per personnel
                  </div>
                </div>
              );
            })}
          </div>
        </PageState>

        {predictions && overview.total > 0 && (
          <div>
            <h3 style={{ margin: "0 0 8px", fontSize: "15px" }}>
              Recent HIGH-risk predictions
            </h3>
            {recentHighRisk.length === 0 ? (
              <p style={{ color: "var(--text-muted)", fontSize: "13px" }}>
                No HIGH-risk predictions yet.
              </p>
            ) : (
              <table
                style={{
                  width: "100%",
                  borderCollapse: "collapse",
                  fontSize: "13px",
                }}
              >
                <thead>
                  <tr>
                    <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                      Risk
                    </th>
                    <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                      Personnel key
                    </th>
                    <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                      Predicted at
                    </th>
                    <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                      Review
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {recentHighRisk.map((p) => (
                    <tr key={p.id}>
                      <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                        <RiskBadge risk={p.risk_level} probability={p.probability_high} />
                      </td>
                      <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)", fontFamily: "monospace" }}>
                        {p.personnel_key.slice(0, 8)}…
                      </td>
                      <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                        {formatDateTime(p.created_at)}
                      </td>
                      <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)", textTransform: "capitalize" }}>
                        {p.review_status}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}

        <p style={{ margin: "16px 0 0", fontSize: "12px", color: "var(--text-muted)" }}>
          SYNTHETIC demo data — counts reflect latest predictions from the FastAPI
          backend (model v1), not real CAPF personnel.
        </p>
      </section>
    </DashboardLayout>
  );
}