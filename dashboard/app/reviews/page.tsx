"use client";
import { useEffect, useMemo, useState } from "react";
import DashboardLayout from "../console-layout";
import RiskBadge from "../../components/risk-badge";
import PageState from "../../components/page-state";
import { fetchPredictions, isTruncated, CONSOLE_PAGE_SIZE } from "../../lib/api";
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

  const queue = useMemo(() => {
    // One card per person: a person is followed up on their most recent
    // HIGH result, not on every historical one.
    const latest = new Map<string, Prediction>();
    for (const p of predictions ?? []) {
      if (p.risk_level !== "high") continue;
      const seen = latest.get(p.personnel_key);
      if (
        !seen ||
        +new Date(p.created_at) > +new Date(seen.created_at)
      ) {
        latest.set(p.personnel_key, p);
      }
    }
    return [...latest.values()].sort(
      (a, b) => +new Date(b.created_at) - +new Date(a.created_at),
    );
  }, [predictions]);

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
          HIGH-risk results
        </h2>
        <p style={{ margin: "0 0 16px", color: "var(--text-muted)", fontSize: "14px" }}>
          Predictions the model placed in the HIGH band, newest first. This
          console is read-only in this build: nothing here is dispatched,
          assigned, or escalated automatically. Scores are uncalibrated model
          outputs from synthetic training data, not clinical probabilities.
        </p>

        <PageState loading={loading} error={error}>
          {isTruncated(predictions ?? []) ? (
            <p
              style={{
                margin: "0 0 12px",
                padding: "8px 12px",
                borderRadius: "8px",
                border: "1px solid var(--border)",
                background: "var(--bg)",
                fontSize: "12px",
                color: "var(--text-muted)",
              }}
            >
              Showing the {CONSOLE_PAGE_SIZE} most recent predictions. Older
              records are not listed in this build.
            </p>
          ) : null}
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
              No HIGH-risk predictions recorded.
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
                      Model scores (v{p.model_version})
                    </div>
                    <div style={{ fontSize: "13px" }}>
                      LOW {p.probability_low.toFixed(2)} · MEDIUM{" "}
                      {p.probability_medium.toFixed(2)} · HIGH{" "}
                      {p.probability_high.toFixed(2)}
                    </div>
                  </div>
                  <div>
                    <div style={{ fontSize: "12px", color: "var(--text-muted)", marginBottom: "4px" }}>
                      Strongest model factors
                    </div>
                    {p.contributing_factors.length > 0 ? (
                      <ul style={{ margin: 0, paddingLeft: "18px", fontSize: "13px" }}>
                        {p.contributing_factors.map((f, i) => (
                          <li key={i}>{f}</li>
                        ))}
                      </ul>
                    ) : (
                      <span style={{ color: "var(--text-muted)", fontSize: "13px" }}>
                        No model factors recorded.
                      </span>
                    )}
                    <p style={{ margin: "6px 0 0", fontSize: "11px", color: "var(--text-muted)" }}>
                      {p.disclaimer ??
                        "These are feature associations the model weighted most, not medical causes and not a diagnosis."}
                    </p>
                  </div>
                </div>
              </div>
            ))
          )}
        </PageState>

        <p style={{ margin: "16px 0 0", fontSize: "12px", color: "var(--text-muted)" }}>
          Decision-support only, shown on SYNTHETIC prototype data. A HIGH flag
          is never an automated decision, and this console records no actions
          in this build.
        </p>
      </section>
    </DashboardLayout>
  );
}