"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

const NAV_ITEMS = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/personnel", label: "Personnel" },
  { href: "/reviews", label: "Reviews" },
];

interface DashboardLayoutProps {
  children: ReactNode;
}

function getCurrentUser(): { username: string; role: string } | null {
  if (typeof window === "undefined") return null;
  const raw = localStorage.getItem("current_user");
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const pathname = usePathname();
  const user = getCurrentUser();

  function handleSignOut() {
    localStorage.removeItem("access_token");
    localStorage.removeItem("current_user");
    window.location.href = "/login";
  }

  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
      <header
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: "16px",
          padding: "12px 24px",
          borderBottom: "1px solid var(--border)",
          background: "var(--surface)",
        }}
      >
        <div>
          <strong style={{ fontSize: "15px" }}>
            Stress &amp; Welfare Monitoring Dashboard
          </strong>
          <div style={{ fontSize: "12px", color: "var(--text-muted)" }}>
            SIH 2026 prototype — authorized officers &amp; commanders
          </div>
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "8px",
            fontSize: "13px",
          }}
        >
          <span
            style={{
              padding: "4px 10px",
              borderRadius: "999px",
              background: "#fffbeb",
              border: "1px solid #fde68a",
              color: "#92400e",
              fontWeight: 600,
            }}
          >
            PROTOTYPE / DEMO
          </span>
          <span style={{ color: "var(--text-muted)" }}>Signed in as</span>
          <span
            style={{
              padding: "4px 10px",
              borderRadius: "999px",
              background: "var(--accent-soft)",
              border: "1px solid #c7d2fe",
              fontWeight: 600,
            }}
          >
            {user ? `${user.username} (${user.role})` : "…"}
          </span>
          <button
            type="button"
            onClick={handleSignOut}
            style={{
              padding: "4px 10px",
              borderRadius: "8px",
              border: "1px solid var(--border)",
              background: "var(--bg)",
              color: "var(--text)",
              cursor: "pointer",
              fontSize: "13px",
            }}
          >
            Sign out
          </button>
        </div>
      </header>

      <nav
        style={{
          display: "flex",
          gap: "4px",
          padding: "8px 24px",
          borderBottom: "1px solid var(--border)",
          background: "var(--surface)",
        }}
      >
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              style={{
                padding: "6px 14px",
                borderRadius: "8px",
                color: active ? "#ffffff" : "var(--text)",
                background: active ? "var(--accent)" : "transparent",
                textDecoration: "none",
                fontSize: "14px",
                fontWeight: active ? 600 : 400,
              }}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>

      <main style={{ flex: 1, padding: "24px" }}>{children}</main>

      <footer
        style={{
          padding: "12px 24px",
          borderTop: "1px solid var(--border)",
          background: "var(--surface)",
          fontSize: "12px",
          color: "var(--text-muted)",
        }}
      >
        SYNTHETIC DEMO DATA ONLY — this prototype contains no real CAPF
        personnel data and is not a medical diagnosis system.
      </footer>
    </div>
  );
}