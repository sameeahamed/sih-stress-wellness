export default function PageState({
  loading,
  error,
  children,
}: {
  loading: boolean;
  error: string | null;
  children: React.ReactNode;
}) {
  if (loading) {
    return (
      <div style={{ color: "var(--text-muted)", fontSize: "14px" }}>Loading…</div>
    );
  }
  if (error) {
    return (
      <div
        style={{
          padding: "14px 16px",
          borderRadius: "8px",
          background: "var(--risk-high-bg)",
          border: "1px solid var(--risk-high-border)",
          color: "var(--risk-high)",
          fontSize: "13px",
        }}
      >
        {error}
      </div>
    );
  }
  return <>{children}</>;
}