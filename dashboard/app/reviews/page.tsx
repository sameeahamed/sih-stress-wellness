"use client";
import { useEffect, useMemo, useState } from "react";
import DashboardLayout from "../console-layout";
import RiskBadge from "../../components/risk-badge";
import PageState from "../../components/page-state";
import { fetchPredictions } from "../../lib/api";
import type { Prediction } from "../../types";

function shortKey(key: string): string {
  return `${key.slice(0, 8)}…${key.slice(-4)}`;
}

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString();
}

export default function ReviewsPage() {
  const [predictions, setPredictions] = useState<Prediction[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchPredictions()
      .then((data) => setPredictions(data))
      .catch((e) => setError(e instanceof Error ? e.message : "Failed to load"))
      .finally(() => setLoading(false));
  }, []);

  const queue = useMemo(
    () =>
      (predictions ?? [])
        .filter((p) => p.risk_level === "high")
        .sort((a, b) => +new Date(b.created_at) - +new Date(a.created_at)),
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
          Human review queue
        </h2>
        <p style={{ margin: "0 0 16px", color: "var(--text-muted)", fontSize: "14px" }}>
          HIGH-risk predictions flagged by the model, awaiting a welfare
          officer&apos;s human review. Marking-as-reviewed is a future phase.
        </p>

        <PageState loading={loading} error={error}>
          {queue.length === 0 ? (
            <div
              style={{
                padding: "16px",
                borderRadius: "8px",
                border: "1px dashed var(--border)",
                background: "var(--bg)",
                fontSize: "13px",
                color: "var(--text-muted)",
              }}
            >
              No HIGH-risk predictions in the queue.
            </div>
          ) : (
            queue.map((p) => (
              <div
                key={p.id}
                style={{
                  padding: "16px",
                  borderRadius: "8px",
                  border: "1px solid var(--border)",
                  background: "var(--bg)",
                  marginBottom: "12px",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: "12px",
                    flexWrap: "wrap",
                    marginBottom: "8px",
                  }}
                >
                  <RiskBadge risk={p.risk_level} probability={p.probability_high} />
                  <span style={{ fontFamily: "monospace", fontSize: "13px" }}>
                    {shortKey(p.personnel_key)}
                  </span>
                  <span style={{ color: "var(--text-muted)", fontSize: "12px" }}>
                    {formatDateTime(p.created_at)}
                  </span>
                  <span
                    style={{
                      padding: "2px 8px",
                      borderRadius: "999px",
                      background: "var(--pending-bg)",
                      border: "1px solid var(--border)",
                      color: "var(--pending)",
                      fontSize: "11px",
                      textTransform: "capitalize",
                    }}
                  >
                    {p.review_status}
                  </span>
                </div>
                <div
                  style={{
                    display: "grid",
                    gap: "12px",
                    gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
                  }}
                >
                  <div>
                    <div style={{ fontSize: "12px", color: "var(--text-muted)", marginBottom: "4px" }}>
                      Probabilities (model v{p.model_version})
                    </div>
                    <div style={{ fontSize: "13px" }}>
                      LOW {p.probability_low.toFixed(2)} · MEDIUM{" "}
                      {p.probability_medium.toFixed(2)} · HIGH{" "}
                      {p.probability_high.toFixed(2)}
                    </div>
                  </div>
                  <div>
                    <div style={{ fontSize: "12px", color: "var(--text-muted)", marginBottom: "4px" }}>
                      Contributing factors (SHAP)
                    </div>
                    {p.contributing_factors.length > 0 ? (
                      <ul style={{ margin: 0, paddingLeft: "18px", fontSize: "13px" }}>
                        {p.contributing_factors.map((f, i) => (
                          <li key={i}>{f}</li>
                        ))}
                      </ul>
                    ) : (
                      <span style={{ color: "var(--text-muted)", fontSize: "13px" }}>
                        No contributing factors recorded.
                      </span>
                    )}
                  </div>
                </div>
              </div>
            ))
          )}
        </PageState>

        <p style={{ margin: "16px 0 0", fontSize: "12px", color: "var(--text-muted)" }}>
          Decision-support only: a HIGH-risk flag never auto-decides — it always
          requires human review by an authorized welfare officer or commander.
        </p>
      </section>
    </DashboardLayout>
  );
}