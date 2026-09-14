import DashboardLayout from "../console-layout";

export default function ReviewsPage() {
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
        <h2 style={{ margin: "0 0 8px", fontSize: "18px" }}>Human review</h2>
        <p style={{ margin: "0 0 16px", color: "var(--text-muted)", fontSize: "14px" }}>
          Placeholder for the welfare-officer review queue (human-in-the-loop).
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
          The human-review workflow (reviewer, status, note, timestamps) is not
          implemented yet — a HIGH-risk prediction will never auto-decide, it
          always triggers human review.
        </div>
      </section>
    </DashboardLayout>
  );
}