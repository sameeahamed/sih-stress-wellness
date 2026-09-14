import DashboardLayout from "../console-layout";

export default function DashboardPage() {
  return (
    <DashboardLayout>
      <section
        style={{
          maxWidth: "720px",
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
          Placeholder for the personnel stress-risk overview (LOW / MEDIUM /
          HIGH). No real data is displayed.
        </p>

        <div
          style={{
            display: "flex",
            gap: "12px",
            flexWrap: "wrap",
          }}
        >
          {["LOW", "MEDIUM", "HIGH"].map((level) => (
            <div
              key={level}
              style={{
                flex: 1,
                minWidth: "140px",
                padding: "16px",
                borderRadius: "8px",
                border: "1px solid var(--border)",
                background: "var(--bg)",
                textAlign: "center",
              }}
            >
              <div style={{ fontSize: "13px", color: "var(--text-muted)" }}>
                {level}
              </div>
              <div style={{ fontSize: "24px", fontWeight: 700, marginTop: "4px" }}>
                —
              </div>
              <div style={{ fontSize: "12px", color: "var(--text-muted)" }}>
                pending integration
              </div>
            </div>
          ))}
        </div>

        <p
          style={{
            margin: "16px 0 0",
            fontSize: "12px",
            color: "var(--text-muted)",
          }}
        >
          DEMO/SYNTHETIC placeholder — counts will come from the FastAPI
          backend in a future phase.
        </p>
      </section>
    </DashboardLayout>
  );
}