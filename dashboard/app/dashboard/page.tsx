"use client";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import DashboardLayout from "../console-layout";
import RiskBadge from "../../components/risk-badge";
import PageState from "../../components/page-state";
import { fetchPredictions, isTruncated, CONSOLE_PAGE_SIZE } from "../../lib/api";
import type { Prediction, RiskLevel } from "../../types";

const RISK_LEVELS: RiskLevel[] = ["low", "medium", "high"];

const TONE: Record<
  RiskLevel,
  { c: string; bg: string; border: string; label: string }
> = {
  low: {
    c: "var(--risk-low)",
    bg: "var(--risk-low-bg)",
    border: "var(--risk-low-border)",
    label: "LOW",
  },
  medium: {
    c: "var(--risk-medium)",
    bg: "var(--risk-medium-bg)",
    border: "var(--risk-medium-border)",
    label: "MEDIUM",
  },
  high: {
    c: "var(--risk-high)",
    bg: "var(--risk-high-bg)",
    border: "var(--risk-high-border)",
    label: "HIGH",
  },
};

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

  // Latest prediction per personnel. The API returns newest-first, so the
  // first row seen for a key is that personnel's current status. Every count
  // below comes from this real data - nothing is estimated or filled in.
  const { counts, total, latestHigh } = useMemo(() => {
    const latestByPersonnel = new Map<string, Prediction>();
    for (const p of predictions ?? []) {
      if (!latestByPersonnel.has(p.personnel_key)) {
        latestByPersonnel.set(p.personnel_key, p);
      }
    }
    const next: Record<RiskLevel, number> = { low: 0, medium: 0, high: 0 };
    for (const p of latestByPersonnel.values()) {
      next[p.risk_level] += 1;
    }
    const high = [...latestByPersonnel.values()]
      .filter((p) => p.risk_level === "high")
      .sort((a, b) => b.created_at.localeCompare(a.created_at));
    return { counts: next, total: latestByPersonnel.size, latestHigh: high };
  }, [predictions]);

  return (
    <DashboardLayout>
      <div style={{ maxWidth: "1080px" }}>
        <header style={{ marginBottom: "20px" }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              marginBottom: "8px",
            }}
          >
            <h1 style={{ margin: 0, fontSize: "22px", letterSpacing: "-0.01em" }}>
              Personnel Welfare Monitoring
            </h1>
            <span
              style={{
                fontSize: "11px",
                fontWeight: 700,
                letterSpacing: "0.06em",
                padding: "3px 8px",
                borderRadius: "999px",
                border: "1px solid var(--risk-medium-border)",
                background: "var(--risk-medium-bg)",
                color: "var(--risk-medium)",
                whiteSpace: "nowrap",
              }}
            >
              PROTOTYPE
            </span>
          </div>
          <p
            style={{
              margin: 0,
              color: "var(--text-muted)",
              fontSize: "14px",
              maxWidth: "72ch",
            }}
          >
            Decision-support overview of the latest model assessment for each
            personnel record. A HIGH result is a signal for human welfare
            review - it is never an automated action.
          </p>
        </header>

        <PageState loading={loading} error={error}>
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
              gap: "12px",
              marginBottom: "20px",
            }}
          >
            <div
              style={{
                padding: "16px",
                borderRadius: "12px",
                border: "1px solid var(--border)",
                background: "var(--surface)",
              }}
            >
              <div
                style={{
                  fontSize: "12px",
                  color: "var(--text-muted)",
                  textTransform: "uppercase",
                  letterSpacing: "0.05em",
                  fontWeight: 700,
                }}
              >
                Total personnel
              </div>
              <div style={{ fontSize: "30px", fontWeight: 700, marginTop: "6px" }}>
                {total}
              </div>
              <div style={{ fontSize: "12px", color: "var(--text-muted)" }}>
                with a model assessment
              </div>
            </div>
            {RISK_LEVELS.map((level) => {
              const t = TONE[level];
              return (
                <div
                  key={level}
                  style={{
                    padding: "16px",
                    borderRadius: "12px",
                    border: `1px solid ${t.border}`,
                    background: t.bg,
                  }}
                >
                  <div
                    style={{
                      fontSize: "12px",
                      color: "var(--text-muted)",
                      textTransform: "uppercase",
                      letterSpacing: "0.05em",
                      fontWeight: 700,
                    }}
                  >
                    {t.label}
                  </div>
                  <div
                    style={{ fontSize: "30px", fontWeight: 700, marginTop: "6px", color: t.c }}
                  >
                    {counts[level]}
                  </div>
                  <div style={{ fontSize: "12px", color: "var(--text-muted)" }}>
                    latest per personnel
                  </div>
                </div>
              );
            })}
          </div>

          <section
            style={{
              padding: "20px",
              border: "1px solid var(--border)",
              borderRadius: "12px",
              background: "var(--surface)",
            }}
          >
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "baseline",
                gap: "12px",
                flexWrap: "wrap",
                marginBottom: "4px",
              }}
            >
              <h2 style={{ margin: 0, fontSize: "16px" }}>
                Personnel requiring attention
              </h2>
              <Link
                href="/reviews"
                style={{ fontSize: "13px", color: "var(--text-muted)" }}
              >
                View all HIGH results →
              </Link>
            </div>
            <p
              style={{
                margin: "0 0 16px",
                fontSize: "13px",
                color: "var(--text-muted)",
              }}
            >
              Latest HIGH model assessment per personnel.{" "}
              <strong style={{ color: "var(--text-primary)" }}>
                Model-generated signal — requires human review.
              </strong>
            </p>

            {latestHigh.length === 0 ? (
              <div
                style={{
                  padding: "28px",
                  textAlign: "center",
                  border: "1px dashed var(--border)",
                  borderRadius: "10px",
                  color: "var(--text-muted)",
                  fontSize: "13px",
                }}
              >
                No personnel currently hold a HIGH model assessment.
              </div>
            ) : (
              <div style={{ display: "grid", gap: "12px" }}>
                {latestHigh.map((p) => (
                  <article
                    key={p.id}
                    style={{
                      padding: "14px",
                      borderRadius: "10px",
                      border: "1px solid var(--risk-high-border)",
                      background: "var(--risk-high-bg)",
                    }}
                  >
                    <div
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        gap: "12px",
                        flexWrap: "wrap",
                        alignItems: "center",
                      }}
                    >
                      <div
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: "10px",
                          flexWrap: "wrap",
                        }}
                      >
                        <RiskBadge risk={p.risk_level} probability={p.probability_high} />
                        <span
                          style={{
                            fontFamily: "monospace",
                            fontSize: "13px",
                            color: "var(--text-primary)",
                          }}
                        >
                          {p.personnel_key.slice(0, 8)}…
                        </span>
                      </div>
                      <span style={{ fontSize: "12px", color: "var(--text-muted)" }}>
                        Assessed {formatDateTime(p.created_at)}
                      </span>
                    </div>
                    {p.contributing_factors.length > 0 && (
                      <p
                        style={{
                          margin: "10px 0 0",
                          fontSize: "13px",
                          color: "var(--text-primary)",
                        }}
                      >
                        <strong>Contributing model factors: </strong>
                        {p.contributing_factors.slice(0, 3).join(" · ")}
                      </p>
                    )}
                  </article>
                ))}
              </div>
            )}

            <p
              style={{
                margin: "16px 0 0",
                fontSize: "12px",
                color: "var(--text-muted)",
              }}
            >
              Model-generated decision support. Not a medical diagnosis, and
              not an automatic personnel decision. Final welfare decisions
              remain with authorized personnel.
            </p>
          </section>
        </PageState>

        {predictions && isTruncated(predictions) && (
          <p style={{ margin: "12px 0 0", fontSize: "12px", color: "var(--text-muted)" }}>
            Showing the {CONSOLE_PAGE_SIZE} most recent predictions. Older
            records are not listed in this build.
          </p>
        )}

        <p style={{ margin: "12px 0 0", fontSize: "12px", color: "var(--text-muted)" }}>
          SYNTHETIC demo data — counts reflect latest predictions from the
          FastAPI backend (model v1), not real CAPF personnel.
        </p>
      </div>
    </DashboardLayout>
  );
}
