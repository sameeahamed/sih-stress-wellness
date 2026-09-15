"use client";
import { useEffect, useMemo, useState } from "react";
import DashboardLayout from "../console-layout";
import RiskBadge from "../../components/risk-badge";
import PageState from "../../components/page-state";
import { fetchAssessments, fetchPredictions } from "../../lib/api";
import type { Prediction, WellnessAssessment } from "../../types";

function shortKey(key: string): string {
  return `${key.slice(0, 8)}…${key.slice(-4)}`;
}

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString();
}

export default function PersonnelPage() {
  const [predictions, setPredictions] = useState<Prediction[] | null>(null);
  const [assessments, setAssessments] = useState<WellnessAssessment[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([fetchPredictions(), fetchAssessments()])
      .then(([preds, ass]) => {
        setPredictions(preds);
        setAssessments(ass);
      })
      .catch((e) => setError(e instanceof Error ? e.message : "Failed to load"))
      .finally(() => setLoading(false));
  }, []);

  const rows = useMemo(() => {
    const predByKey = new Map<string, Prediction[]>();
    for (const p of predictions ?? []) {
      const arr = predByKey.get(p.personnel_key) ?? [];
      arr.push(p);
      predByKey.set(p.personnel_key, arr);
    }
    const assByKey = new Map<string, WellnessAssessment>();
    for (const a of assessments ?? []) {
      if (!assByKey.has(a.personnel_key)) assByKey.set(a.personnel_key, a);
    }
    const keys = new Set([...predByKey.keys(), ...assByKey.keys()]);
    return [...keys]
      .map((key) => {
        const latestPred = (predByKey.get(key) ?? []).sort(
          (a, b) => +new Date(b.created_at) - +new Date(a.created_at),
        )[0];
        const latestAss = assByKey.get(key);
        return {
          key,
          latestPred,
          latestAss,
          predictionCount: predByKey.get(key)?.length ?? 0,
        };
      })
      .sort((a, b) => {
        const at = a.latestPred?.created_at ?? a.latestAss?.submitted_at ?? "";
        const bt = b.latestPred?.created_at ?? b.latestAss?.submitted_at ?? "";
        return +new Date(bt) - +new Date(at);
      });
  }, [predictions, assessments]);

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
        <h2 style={{ margin: "0 0 8px", fontSize: "18px" }}>Personnel</h2>
        <p style={{ margin: "0 0 16px", color: "var(--text-muted)", fontSize: "14px" }}>
          Per-personnel snapshot from synthetic assessments and predictions.
        </p>

        <PageState loading={loading} error={error}>
          {rows.length === 0 ? (
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
              No personnel records available. Make sure the FastAPI backend is
              running and seeded (see README).
            </div>
          ) : (
            <table
              style={{ width: "100%", borderCollapse: "collapse", fontSize: "13px" }}
            >
              <thead>
                <tr>
                  <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                    Personnel key (opaque)
                  </th>
                  <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                    Latest risk
                  </th>
                  <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                    Last assessment
                  </th>
                  <th align="left" style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                    Predictions
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.key}>
                    <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)", fontFamily: "monospace" }}>
                      {shortKey(r.key)}
                    </td>
                    <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                      {r.latestPred ? (
                        <RiskBadge
                          risk={r.latestPred.risk_level}
                          probability={
                            {
                              low: r.latestPred.probability_low,
                              medium: r.latestPred.probability_medium,
                              high: r.latestPred.probability_high,
                            }[r.latestPred.risk_level]
                          }
                        />
                      ) : (
                        <span style={{ color: "var(--text-muted)" }}>— (skipped)</span>
                      )}
                    </td>
                    <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                      {r.latestAss ? (
                        <>
                          <span style={{ fontWeight: 600 }}>
                            stress {r.latestAss.stress_level_self_report}/10
                          </span>{" "}
                          <span style={{ color: "var(--text-muted)" }}>
                            · {formatDateTime(r.latestAss.submitted_at)}
                          </span>
                        </>
                      ) : (
                        <span style={{ color: "var(--text-muted)" }}>—</span>
                      )}
                    </td>
                    <td style={{ padding: "6px 8px", borderBottom: "1px solid var(--border)" }}>
                      {r.predictionCount}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </PageState>

        <p style={{ margin: "16px 0 0", fontSize: "12px", color: "var(--text-muted)" }}>
          Personnel are shown as opaque pseudonymized keys only — no personal
          data is ever exposed.
        </p>
      </section>
    </DashboardLayout>
  );
}