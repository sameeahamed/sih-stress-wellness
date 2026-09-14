import Link from "next/link";

export default function LandingPage() {
  return (
    <main
      style={{
        minHeight: "100vh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "24px",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: "560px",
          padding: "40px",
          border: "1px solid var(--border)",
          borderRadius: "12px",
          background: "var(--surface)",
        }}
      >
        <div
          style={{
            display: "inline-block",
            padding: "4px 10px",
            borderRadius: "999px",
            background: "#fffbeb",
            border: "1px solid #fde68a",
            color: "#92400e",
            fontSize: "12px",
            fontWeight: 600,
            marginBottom: "16px",
          }}
        >
          PROTOTYPE / DEMO — SYNTHETIC DATA ONLY
        </div>

        <h1 style={{ margin: "0 0 8px", fontSize: "24px" }}>
          AI-Based Predictive Personnel Stress &amp; Welfare Monitoring
        </h1>
        <p style={{ margin: "0 0 24px", color: "var(--text-muted)" }}>
          Officer &amp; commander dashboard for SIH 2026 prototype.
          This interface uses synthetic demo data only and does not contain
          real personnel information.
        </p>

        <div
          style={{
            padding: "12px",
            borderRadius: "8px",
            background: "var(--accent-soft)",
            border: "1px solid #c7d2fe",
            marginBottom: "24px",
          }}
        >
          <strong>Not logged in.</strong>{" "}
          <a href="/login">Sign in to the demo console</a> to explore the
          placeholder console pages.
        </div>

        <div style={{ display: "flex", gap: "12px" }}>
          <Link
            href="/login"
            style={{
              flex: 1,
              textAlign: "center",
              padding: "10px 16px",
              borderRadius: "8px",
              background: "var(--accent)",
              border: "none",
              color: "#ffffff",
              cursor: "pointer",
            }}
          >
            Sign in
          </Link>
          <a
            href="/dashboard"
            style={{
              flex: 1,
              textAlign: "center",
              padding: "10px 16px",
              borderRadius: "8px",
              background: "var(--surface)",
              border: "1px solid var(--border)",
              color: "var(--text)",
              textDecoration: "none",
            }}
          >
            Skip to demo dashboard
          </a>
        </div>

        <p style={{ margin: "24px 0 0", fontSize: "12px", color: "var(--text-muted)" }}>
          SIH 2026 — decision-support prototype. Not a medical diagnosis system;
          outputs never automatically drive personnel decisions.
        </p>
      </div>
    </main>
  );
}