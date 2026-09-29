"use client";
import type { ReactNode } from "react";
import type { CurrentUser } from "../types";

export function getStoredUser(): CurrentUser | null {
  if (typeof window === "undefined") return null;
  const raw = localStorage.getItem("current_user");
  if (!raw) return null;
  try {
    return JSON.parse(raw) as CurrentUser;
  } catch {
    return null;
  }
}

/** Roles that staff the monitoring console. */
const OFFICER_ROLES = ["welfare_officer", "commander", "administrator"];

export function isOfficerRole(role: string | undefined): boolean {
  return !!role && OFFICER_ROLES.includes(role);
}

/**
 * Blocks the officer console for a PERSONNEL account.
 *
 * The backend already scopes a personnel token to that person's own records,
 * so this is not a data-exposure fix. It is a role-framing fix: a service
 * member who signs in here would otherwise land in chrome reading
 * "authorized officers & commanders" and see their own HIGH prediction inside
 * a panel implying someone else is waiting to review them.
 */
export default function OfficerOnlyGate({ children }: { children: ReactNode }) {
  const user = getStoredUser();

  if (user && user.role === "personnel") {
    return (
      <section
        style={{
          maxWidth: "640px",
          margin: "48px auto",
          padding: "24px",
          border: "1px solid var(--border)",
          borderRadius: "12px",
          background: "var(--surface)",
        }}
      >
        <h2 style={{ margin: "0 0 8px", fontSize: "18px" }}>
          This console is for welfare officers and commanders
        </h2>
        <p
          style={{
            margin: "0 0 12px",
            color: "var(--text-muted)",
            fontSize: "14px",
          }}
        >
          You are signed in as {user.username} with the personnel role, which
          does not have access to the monitoring console. No other
          personnel&apos;s records are shown here.
        </p>
        <p style={{ margin: "0", color: "var(--text-muted)", fontSize: "14px" }}>
          Your own wellness results are available in the mobile app. If you
          need support, speak to your welfare officer or medical officer.
        </p>
      </section>
    );
  }

  return <>{children}</>;
}
