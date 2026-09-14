import Link from "next/link";

export default function LoginPage() {
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
          maxWidth: "420px",
          padding: "32px",
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

        <h1 style={{ margin: "0 0 4px", fontSize: "20px" }}>Sign in</h1>
        <p style={{ margin: "0 0 24px", color: "var(--text-muted)", fontSize: "14px" }}>
          Officer &amp; commander dashboard (placeholder — authentication is not
          implemented yet in this phase).
        </p>

        <form style={{ display: "grid", gap: "16px" }}>
          <div style={{ display: "grid", gap: "6px" }}>
            <label htmlFor="username" style={{ fontSize: "14px" }}>
              Username
            </label>
            <input
              id="username"
              name="username"
              autoComplete="off"
              placeholder="demo-officer"
              style={{
                padding: "10px 12px",
                borderRadius: "8px",
                border: "1px solid var(--border)",
                fontSize: "14px",
              }}
            />
          </div>
          <div style={{ display: "grid", gap: "6px" }}>
            <label htmlFor="password" style={{ fontSize: "14px" }}>
              Password
            </label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="off"
              placeholder="••••••••"
              style={{
                padding: "10px 12px",
                borderRadius: "8px",
                border: "1px solid var(--border)",
                fontSize: "14px",
              }}
            />
          </div>
          <button
            type="button"
            style={{
              padding: "10px 16px",
              borderRadius: "8px",
              background: "var(--accent)",
              border: "none",
              color: "#ffffff",
              cursor: "pointer",
              fontSize: "14px",
            }}
          >
            Sign in (disabled — future phase)
          </button>
        </form>

        <p
          style={{
            margin: "20px 0 0",
            fontSize: "13px",
            color: "var(--text-muted)",
          }}
        >
          Login form is a placeholder. Use{" "}
          <Link href="/dashboard">Skip to demo dashboard</Link> to view the
          prototype console.
        </p>
      </div>
    </main>
  );
}