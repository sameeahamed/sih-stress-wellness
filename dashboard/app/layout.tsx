import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SIH 2026 — Stress & Welfare Monitoring Dashboard",
  description:
    "Prototype dashboard for the AI-based predictive personnel stress and welfare monitoring system (POC / demo only).",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}