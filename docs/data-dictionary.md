# data-dictionary.md

Placeholder — intended final content: the PostgreSQL schema and field-level
dictionary for the prototype.

Planned sections:
- Table list: users, personnel_profiles, leave_records, transfer_records,
  deployments, duty_records, wellness_assessments, predictions,
  shap_explanations, recommendations, review_workflow, audit_logs
- Per-table columns, types, constraints, indexes
- Enum values (role, risk level, review status)
- Pseudonymization notes (opaque keys for ML-facing data)
- Feature snapshot (jsonb) on predictions for reproducibility