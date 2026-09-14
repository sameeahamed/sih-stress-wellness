import Link from "next/link";
import type { ReactNode } from "react";

const NAV_ITEMS = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/personnel", label: "Personnel" },
  { href: "/reviews", label: "Reviews" },
];

interface DashboardLayoutProps {
  children: ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
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
            Welfare Officer (demo)
          </span>
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
        {NAV_ITEMS.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            style={{
              padding: "6px 14px",
              borderRadius: "8px",
              color: "var(--text)",
              textDecoration: "none",
              fontSize: "14px",
            }}
          >
            {item.label}
          </Link>
        ))}
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