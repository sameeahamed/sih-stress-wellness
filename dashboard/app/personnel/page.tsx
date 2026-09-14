import DashboardLayout from "../console-layout";

export default function PersonnelPage() {
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
        <h2 style={{ margin: "0 0 8px", fontSize: "18px" }}>Personnel</h2>
        <p style={{ margin: "0 0 16px", color: "var(--text-muted)", fontSize: "14px" }}>
          Placeholder for the personnel list and per-personnel risk details.
        </p>

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
          No personnel records are shown — the personnel directory and risk
          details will be populated by the FastAPI backend in a future phase.
        </div>
      </section>
    </DashboardLayout>
  );
}