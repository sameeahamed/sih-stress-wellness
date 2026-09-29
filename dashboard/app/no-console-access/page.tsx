"use client";
import { useEffect, useState } from "react";
import { getStoredUser } from "../../components/officer-only-gate";

/**
 * Landing page for a PERSONNEL account that signed in to the dashboard.
 *
 * The backend scopes a personnel token to that person's own records, so this
 * is about correct framing rather than data access: a service member should
 * not be dropped into officer console chrome.
 */
export default function NoConsoleAccessPage() {
  const [username, setUsername] = useState<string | null>(null);

  useEffect(() => {
    setUsername(getStoredUser()?.username ?? null);
  }, []);

  function signOut() {
    localStorage.removeItem("access_token");
    localStorage.removeItem("current_user");
    window.location.href = "/login";
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "24px",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: "560px",
          padding: "32px",
          border: "1px solid var(--border)",
          borderRadius: "12px",
          background: "var(--surface)",
        }}
      >
        <h1 style={{ margin: "0 0 12px", fontSize: "20px" }}>
          This console is for welfare officers and commanders
        </h1>
        <p
          style={{
            margin: "0 0 12px",
            color: "var(--text-muted)",
            fontSize: "14px",
            lineHeight: 1.5,
          }}
        >
          {username
            ? `You are signed in as ${username} with the personnel role, which does not have access to the monitoring console.`
            : "Your account does not have access to the monitoring console."}
        </p>
        <p
          style={{
            margin: "0 0 20px",
            color: "var(--text-muted)",
            fontSize: "14px",
            lineHeight: 1.5,
          }}
        >
          The console shows duty and wellness information about other
          personnel. No other person&apos;s records are visible to you here.
          Your own wellness results are in the mobile app, and if you need
          support you can speak to your welfare officer or medical officer.
        </p>
        <button
          type="button"
          onClick={signOut}
          style={{
            padding: "8px 16px",
            borderRadius: "8px",
            border: "1px solid var(--border)",
            background: "var(--bg)",
            color: "var(--text)",
            cursor: "pointer",
            fontSize: "14px",
          }}
        >
          Sign out
        </button>
        <p
          style={{
            margin: "20px 0 0",
            fontSize: "12px",
            color: "var(--text-muted)",
          }}
        >
          SYNTHETIC DEMO DATA ONLY — this prototype contains no real CAPF
          personnel data and is not a medical diagnosis system.
        </p>
      </section>
    </main>
  );
}
