"use client";
import { useState, type FormEvent } from "react";
import { login, getMe } from "../../lib/api";

export default function LoginPage() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const { access_token } = await login(username, password);
      localStorage.setItem("access_token", access_token);
      const me = await getMe();
      localStorage.setItem("current_user", JSON.stringify(me));
      window.location.href = "/dashboard";
    } catch (err: unknown) {
      const msg =
        err instanceof Error ? err.message : "Login failed";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

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
          Officer &amp; commander dashboard (synthetic demo data).
        </p>

        {error && (
          <div
            style={{
              padding: "10px 14px",
              borderRadius: "8px",
              background: "var(--risk-high-bg)",
              border: "1px solid var(--risk-high-border)",
              color: "var(--risk-high)",
              fontSize: "13px",
              marginBottom: "16px",
            }}
          >
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} style={{ display: "grid", gap: "16px" }}>
          <div style={{ display: "grid", gap: "6px" }}>
            <label htmlFor="username" style={{ fontSize: "14px" }}>
              Username
            </label>
            <input
              id="username"
              name="username"
              autoComplete="off"
              placeholder="seed_welfare_officer"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
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
              placeholder="demo-password-123"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={{
                padding: "10px 12px",
                borderRadius: "8px",
                border: "1px solid var(--border)",
                fontSize: "14px",
              }}
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            style={{
              padding: "10px 16px",
              borderRadius: "8px",
              background: loading ? "var(--text-muted)" : "var(--accent)",
              border: "none",
              color: "#ffffff",
              cursor: loading ? "not-allowed" : "pointer",
              fontSize: "14px",
              fontWeight: 600,
            }}
          >
            {loading ? "Signing in…" : "Sign in"}
          </button>
        </form>

        <p
          style={{
            margin: "20px 0 0",
            fontSize: "13px",
            color: "var(--text-muted)",
          }}
        >
          Demo credentials: <strong>seed_welfare_officer</strong> /{" "}
          <strong>demo-password-123</strong> (or <strong>seed_admin</strong>,
          <strong>seed_commander</strong>). All data is synthetic.
        </p>
      </div>
    </main>
  );
}
