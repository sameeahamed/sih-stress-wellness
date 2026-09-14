# PROJECT_CONTEXT.md

**Permanent source of truth for the SIH 2026 prototype project.**
Read this file first. Update this file whenever a decision is finalized.
Do not let project history live only in chat conversations.

---

## 1. Problem Statement / Project Title

**AI-Based Predictive Personnel Stress and Welfare Monitoring System for CAPFs
and Uniformed Forces.**

The platform is intended for CAPFs and other uniformed forces. It uses
authorized personnel-related and wellness-related data to identify potential
stress-risk patterns. Possible input data:

- HR-related information
- Leave history
- Transfer frequency
- Duty hours
- Deployment duration / plans
- Workload
- Rest-related information
- Self-reported wellness / stress information
- Other authorized and relevant non-invasive wellness indicators

The system processes these inputs and predicts a stress-risk level:
**LOW / MEDIUM / HIGH**.

If a personnel record is predicted as **HIGH** risk, the system notifies /
shows the risk to an authorized welfare officer or commander through a secure
dashboard.

## 2. Project Objective

Build a working, demosable prototype (MVP) for Smart India Hackathon 2026 that
demonstrates the end-to-end flow:

personnel → mobile app → REST API → FastAPI backend → validation → ML
prediction (XGBoost) → stress-risk level → SHAP explanation → PostgreSQL →
authorized officer dashboard → human review / welfare recommendation.

The system is a **decision-support and early-intervention platform, NOT a
medical diagnosis system.**

## 3. Target Users and Roles

- **Personnel** — log in, complete wellness / self-assessment forms, submit
  relevant information, view their own results and recommendations.
- **Welfare Officer** — view overall risk status, identify high-risk cases,
  review contributing factors and recommendations, perform human review.
- **Commander** — same visibility/review responsibilities as welfare officer
  (authorized roles).
- **Administrator** — system administration; audit-log visibility.

## 4. Finalized Technology Stack

| Layer | Technology |
|---|---|
| Personnel mobile app | Flutter / Dart |
| Officer & commander dashboard | Next.js / React |
| Backend & API | Python, FastAPI, REST APIs |
| AI / ML | XGBoost, Pandas, NumPy, SHAP |
| Data layer | PostgreSQL |
| Security | JWT authentication, RBAC, data anonymization / pseudonymization |

## 5. Finalized Architecture Decisions

- **Monolith-with-in-process-ML:** the ML model lives inside the FastAPI
  process as a module (`backend/app/ml/`), not a separate microservice. Fewer
  moving parts for an SIH prototype.
- **Single PostgreSQL database** for app data, predictions, SHAP
  explanations, recommendations, and audit logs.
- **REST + JSON** API with FastAPI's auto-generated OpenAPI documentation.
- **Predictions persisted at submission time** (alongside a feature snapshot)
  so the dashboard never re-infers and history stays auditable.
- **Agent/organizer separation:**
  - `mobile/` = Flutter personnel application
  - `dashboard/` = Next.js + React officer/commander dashboard
  - `backend/` = FastAPI backend and API layer
  - `ml/` = training-side ML code and artifacts
  - `backend/app/ml/` = inference-side ML code used by FastAPI
  - `docs/` = project documentation
- **Model artifacts are versioned** by folder + metadata file; no MLflow/DVC
  in MVP (deliberate anti-over-engineering).
- **Testing/training split is temporal** (chronological), not random-shuffle,
  to avoid look-ahead leakage.
- **Mock-first integration between frontends and backend** — frontends build
  against a frozen API contract before the backend is complete.

## 6. Security and Privacy Decisions

- JWT authentication (OAuth2 password flow, short-lived access tokens).
- RBAC enforced per route with role guards (Personnel / Welfare Officer /
  Commander / Administrator).
- bcrypt (or argon2) password hashing — never plaintext.
- Data anonymization / pseudonymization: ML-facing features use opaque keys,
  not personal identifiers.
- **Minimum-necessary-data principle**: no endpoint returns the whole
  database; personnel only access their own data; officers are scope-limited.
- Append-only audit log for sensitive actions (login, submit, review, view).
- Pydantic validation with strict business-rule ranges.
- Secrets only in `.env` (git-ignored); `.env.example` holds placeholders only.
- Demo UIs show a visible **"SYNTHETIC DEMO DATA"** indicator where appropriate.
- No automated medical diagnosis; no automated disciplinary, career,
  promotion, or posting decisions.

## 7. ML Approach and Synthetic-Data Limitation

**ML approach (must be real ML, not a manual formula):**

- **Synthetic dataset:** deterministic, seedable generator producing realistic
  distributions for features such as duty hours (7-day / 30-day windows),
  sleep/rest hours, deployment periods and duration, transfer counts, leave
  taken vs. due, rest gaps, and self-reported wellness/stress scales.
- **Feature definition:** temporal windows and engineered ratios (e.g.,
  rest/duty ratio), documented in a single source of truth shared by training
  and inference.
- **Data preprocessing:** missing-value handling, scaling, encoding, saved
  with the artifact.
- **Train/validation/test strategy:** chronological split (~70/15/15).
- **Class imbalance handling:** XGBoost class weighting (+ SMOTE on training
  set only if needed).
- **XGBoost training:** multiclass (`softprob`), early stopping, fixed seed.
- **Evaluation metrics:** accuracy, macro-F1, per-class precision/recall,
  confusion matrix, ROC-AUC (one-vs-rest).
- **Risk prediction:** predict probability per class → risk level.
- **SHAP explanation:** TreeExplainer for per-record local contributing
  factors; global summary chart for the demo.
- **Model versioning / reproducibility:** artifacts + metadata.json
  (seed, data version, params, train date, metrics).

**Synthetic-data limitation:**

- The prototype runs on **synthetic/demo data only** — there is no real CAPF
  personnel data.
- Synthetic data does **not** represent real CAPF personnel. All claims and
  demo materials must clearly state this.
- A production system would require properly governed, validated, authorized,
  and privacy-preserving real-world data.

## 8. Human-in-the-Loop Approach

- A **HIGH-risk prediction is never an action** — it triggers human review by
  an authorized welfare officer / commander.
- AI output must not automatically make disciplinary, career, promotion,
  posting, or other personnel decisions.
- The review workflow records reviewer, status, note, and timestamps.

## 9. Prototype / MVP Scope

**Personnel side (mobile):**
- Login, basic profile, wellness/self-assessment, relevant workload/duty
  information, submit assessment, view personal result/recommendation.

**Officer side (dashboard):**
- Secure login, dashboard with total personnel and risk overview, LOW/MEDIUM/
  HIGH classification, high-risk personnel list, individual risk details,
  contributing factors (SHAP), recommendations, human-review workflow.

**AI:**
- Synthetic dataset, XGBoost model, prediction, risk level, SHAP explanation.

**Backend:**
- FastAPI REST endpoints, authentication/authorization, validation, ML
  prediction API, PostgreSQL integration.

**Explicitly deferred (not in MVP):**
- Wearables/sensor integration, real-time push alerts/WebSockets, offline
  mobile sync, OAuth SSO/2FA, MLflow/DVC/model registry, PDF reporting,
  advanced case management.

## 10. Important Decisions Made During Planning

- ML service lives **inside** FastAPI (in-process), not a microservice.
- Predictions + feature snapshots + SHAP values are **stored at prediction
  time** for auditability and dashboard speed.
- **Pull-based notifications** (dashboard refresh/badges) instead of push in
  MVP.
- One shared `features.py`-style definition is the **single source of truth**
  for feature engineering (training ↔ inference parity).
- Duplicate artifacts folders are intentional:
  - `ml/artifacts/` = authoritative training output,
  - `backend/app/ml/artifacts/` = deployed inference copy.
- Role enumeration finalized: Personnel, Welfare Officer, Commander,
  Administrator.

## 11. Project History / Decisions (Planning Conversation)

1. Problem statement provided by the team: AI-based predictive stress and
   welfare monitoring for CAPFs and uniformed forces (SIH 2026 prototype).
2. Full technical plan created in PLAN MODE covering architecture, folder
   structure, phases, team division, database, ML plan, security, integration,
   testing, demo flow, MVP vs future scope, risks, and roadmap. The plan was
   accepted by the team.
3. Structure initialization was requested with an explicit constraint set
   (no code, no dependencies, no app scaffolding) and with PROJECT_CONTEXT.md
   designated as the permanent project context. This step has now been
   executed.
4. No structural corrections were required — the requested structure was
   already consistent with the finalized architecture.
5. **Next.js Dashboard Foundation phase executed.** `dashboard/` was
   initialized in place (Node 24, npm 11) with Next.js 15.5 / React 19 /
   TypeScript 5 under the App Router. Landing, login placeholder, shared
   console layout, and placeholder pages for Dashboard, Personnel, and
   Reviews were created; every page carries visible PROTOTYPE / DEMO and
   SYNTHETIC DATA notices. `npm run dev` verified running on port 3000 with
   no startup errors. As decided, this phase deliberately excluded
   PostgreSQL, auth/JWT/RBAC, FastAPI integration, ML, real data, and
   production deployment.
6. **PostgreSQL + Database Foundation phase executed.** PostgreSQL database
   `sih_stress_wellness` created and connected. SQLAlchemy 2.0 models for
   User, Personnel, WellnessAssessment, DutyRecord, Prediction, and AuditLog
   defined. Alembic configured and initial migration
   (`bd7a13c80cbb_initial_schema`) applied. FastAPI DB session dependency
   and `/health` DB connectivity check added. 18 backend tests added and
   passing. Done deliberately excluded: JWT/OAuth2/RBAC, assessment APIs,
   ML/XGBoost/SHAP, prediction logic, Flutter/Next.js API integration, real
   CAPF data, notifications, production deployment. PostgreSQL 18.6 verified
   running locally with psycopg2 connectivity.
7. **Authentication + RBAC Security Foundation phase executed.** Implemented
   bcrypt password hashing and verification, JWT access-token creation and
   validation (PyJWT, HS256), FastAPI OAuth2 password flow
   (`POST /auth/token`), a minimal authenticated-user endpoint
   (`GET /auth/me`), and reusable dependencies for current-user resolution and
   role-based access control (`get_current_user`, `get_current_active_user`,
   `require_roles`, `require_admin`). Secrets come from environment
   configuration (`JWT_SECRET_KEY`, `JWT_ALGORITHM`,
   `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`) — nothing hard-coded. No database model
   change was required, so no new Alembic migration was created. 50 backend
   tests pass. Deliberately excluded: assessment/duty/prediction APIs,
   ML/XGBoost/SHAP, Flutter and Next.js integration, notifications,
   production deployment.
8. **Assessment + Duty REST APIs phase executed.** `POST/GET /assessments` and
   `POST/GET /duty-records` with Pydantic validation and a service layer.
   Duration safety (server-derived `duty_hours`), RBAC scoping on opaque keys,
   cross-personnel 404/403. Additive migration `c51826e301a9` added nullable
   duty start/end times. 73 backend tests passing.
9. **Synthetic Dataset + ML Training Pipeline phase executed.** Synthetic
   dataset (4,800 rows, seed 42, `SYN-*` keys), validation, 16-feature
   engineering (no leakage, personnel-disjoint split), XGBoost training
   (model artifact `v1`), evaluation, SHAP explainability. 39 ML tests
   passing. Kept separate from FastAPI at this stage.
10. **FastAPI + ML Inference Integration phase executed.** Automatic
    LOW/MEDIUM/HIGH stress-risk prediction on assessment submission. The
    trained `v1` artifact is loaded inside FastAPI (in-process, no
    microservice), features derived from assessment + duty records with
    explicit missing-data handling (never fabricated), SHAP contributing
    factors surfaced, Prediction rows persisted. `GET /predictions` and
    `GET /predictions/{id}` with the same RBAC rules. 87 backend tests
    passing.

## 11b. Database Foundation Decisions

- Single PostgreSQL database `sih_stress_wellness` (local dev), driver
  `psycopg2`, URL from environment (`DATABASE_URL`) — no hard-coded
  credentials. `DATABASE_URL` is a required setting; missing `.env` fails
  fast.
- Internal UUID primary keys on every table (PostgreSQL `uuid`), avoiding
  ID enumeration.
- **Pseudonymization:** `Personnel` exposes an opaque, unique `opaque_key`
  (UUID) for ML-facing features; no real personal identifiers are stored.
- `Personnel` stores only minimum-necessary data (`unit_code`, `is_active`,
  timestamps) — no names, no service numbers, no personal details.
- `Prediction` persists the feature snapshot and SHAP explanation alongside
  risk level and per-class probabilities at prediction time so history stays
  auditable and the dashboard never re-infers.
- Enums (`Role`, `RiskLevel`, `DutyType`, `ReviewStatus`) kept as Python
  enums mapped to `String` columns for migration simplicity.
- Human-review is a later phase; `Prediction.review_status` already exists
  (default `pending`) so review wiring can be added without a schema change.
- Append-only `AuditLog` (actor, subject, action, resource, JSON details)
  is ready for auth/API phases.
- Relationship map: `User` ↔ 0..1 `Personnel`; `Personnel` 1—N
  `WellnessAssessment`, 1—N `DutyRecord`, 1—N `Prediction`, 1—N `AuditLog`;
  `Prediction` N—1 `WellnessAssessment`.
- No seed script written. No real or synthetic personnel data is stored.
  Demo seeding, if ever added, must be clearly marked synthetic.
- Alembic: `alembic.ini` at `backend/`, `env.py` reads `DATABASE_URL` from
  Settings, version `bd7a13c80cbb` applied (`alembic upgrade head`). No
  destructive migrations; `downgrade` drops the initial tables only.

## 11c. Authentication + RBAC Foundation Decisions

- **Password hashing:** bcrypt directly (no passlib) — `hash_password` /
  `verify_password` in `app/core/security.py`. Passwords are never stored in
  plaintext and never logged. Empty/invalid hashes fail closed.
- **JWT:** PyJWT, HS256, claims `sub` (user UUID), `iat`, `exp`, `type:
  access`. Secrets come from env (`JWT_SECRET_KEY`, `JWT_ALGORITHM`,
  `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` default 30). No hard-coded secrets;
  `JWT_SECRET_KEY` is required (fails fast when missing). Tokens carry no
  role/personal data — authorization is always resolved from the database
  row, so role changes and deactivation take effect immediately.
- **OAuth2 password flow:** `POST /auth/token` accepts
  `OAuth2PasswordRequestForm` (username+password) and returns the standard
  `{"access_token": ..., "token_type": "bearer"}` body. `GET /auth/me`
  returns a minimal profile and, for personnel accounts, only the opaque
  pseudonymized key — never personal data.
- **RBAC:** reusable dependencies in `app/api/deps.py`
  (`get_current_user`, `get_current_active_user`, `require_roles(*roles)`,
  `require_admin`). Unauthenticated → 401; authenticated but wrong role →
  403. Guards are per-route via `Depends(require_roles(...))`.
- **Roles:** `Role` enum in `app/models/enums.py` —
  `personnel`, `welfare_officer`, `commander`, `administrator`.
- **Service layer:** `app/services/auth.py` (`get_user_by_username`,
  `authenticate_user`) — inactive accounts and hashed-password-less users
  never authenticate.
- **No migration needed:** the existing `users` table already has
  `username`, `hashed_password`, `role`, `is_active`; model unchanged.
  `alembic check` confirms models and migration are in sync.
- **Test users:** synthetic demo users (`demo_personnel`,
  `demo_welfare_officer`, `demo_commander`, `demo_admin`, shared demo
  password) are created and removed per test by the `demo_users` fixture in
  `backend/conftest.py`. No real CAPF data.
- **Merged a newer FastAPI/Starlette TestClient `httpx2` requirement** into
  the test dependencies.

## 12. Project Constraints

1. Privacy by design.
2. Security by design.
3. Human-in-the-loop.
4. Explainable AI (SHAP for contributing factors).
5. Minimum necessary data collection.
6. No automated medical diagnosis.
7. No automated disciplinary/career decisions.
8. Synthetic data for the initial prototype only.
9. MVP must stay achievable for an SIH prototype.
10. Architecture must stay professional and scalable.

---

## Current Development Status

**Stage: Foundation + PostgreSQL foundation + Authentication/RBAC security
foundation + Assessment & Duty REST APIs + Synthetic Dataset & ML Training
Pipeline + FastAPI + ML Inference Integration.** The architecture is
finalized. FastAPI backend, Flutter mobile app, and Next.js dashboard exist at
foundation level. PostgreSQL is complete with six SQLAlchemy models and an
applied Alembic migration chain. Authentication and RBAC (bcrypt hashing, JWT
access tokens, OAuth2 login, role-based route guards) are implemented and
tested. The wellness assessment and duty record REST APIs are implemented with
Pydantic validation, a service layer, and strict role scoping on opaque
personnel identifiers. A clearly synthetic ML training pipeline exists:
deterministic dataset, feature engineering, XGBoost classifier (v1 artifact),
evaluation, and SHAP explainability. Automatic stress-risk prediction is
integrated into the assessment submission flow inside FastAPI — the model
loads in-process, derives features from assessment + duty records, and
persists predictions with SHAP contributing factors in PostgreSQL. Frontend
ML integration (dashboard, Flutter), notifications, and real-data validation
are NOT implemented yet.

### Completed
- Problem understanding
- Solution planning
- Architecture planning
- Technology selection
- Folder structure planning
- Documentation skeleton — `docs/*.md` exist as placeholders describing
  planned content (api-contract, architecture, data-dictionary,
  ml-methodology, sih-demo-script)
- Root `.gitignore`, `.env.example`, `README.md`

### PostgreSQL + Database Foundation (implemented)
- PostgreSQL 18.6 running locally; database **`sih_stress_wellness`** created
- `DATABASE_URL` loaded from environment configuration (required setting,
  no hard-coded credentials); declared in `backend/.env` (git-ignored) and
  `backend/.env.example`
- SQLAlchemy 2.0 models for the six core entities:
  - `User` — dashboard/mobile account (auth wiring deferred)
  - `Personnel` — minimal data + opaque pseudonymized `opaque_key`
  - `WellnessAssessment` — self-reported wellness snapshot
  - `DutyRecord` — workload/duty data point
  - `Prediction` — persisted prediction + feature snapshot + SHAP
  - `AuditLog` — append-only action log
- Relationships wired: `User`↔`Personnel`, `Personnel`→`WellnessAssessment`,
  `Personnel`→`DutyRecord`, `Personnel`→`Prediction`, `Prediction`→
  `WellnessAssessment`, `Personnel`/`User`→`AuditLog`
- Alembic configured (`backend/alembic.ini`, `backend/alembic/env.py`,
  `backend/alembic/versions/bd7a13c80cbb_initial_schema.py`)
- **Migration status:** `c51826e301a9 (head)` applied via
  `alembic upgrade head` (chain: `bd7a13c80cbb` → `c51826e301a9`); all six
  tables + `alembic_version` present in PostgreSQL. No destructive
  migrations.
- DB connection: SQLAlchemy engine/session in `app/db/`, FastAPI
  `get_db` dependency; `GET /health` now reports `database: ok`
- **Database connection status:** connected (psycopg2, PostgreSQL 18.6,
  localhost:5432)
- Backend tests: 18 passing (`pytest tests/`), covering config loading,
  session connectivity, model/relationship registration, and Alembic setup
- No seed data written; no real or synthetic personnel data stored

### Authentication + RBAC Security Foundation (implemented)
- bcrypt password hashing and verification — no plain-text passwords
- JWT access tokens via PyJWT (HS256), with configurable
  `JWT_SECRET_KEY`, `JWT_ALGORITHM`, `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`
  (required from environment; no hard-coded secrets)
- `POST /auth/token` — standard OAuth2 password flow returning
  `{"access_token": ..., "token_type": "bearer"}`
- `GET /auth/me` — authenticated-user profile (returns opaque
  pseudonymized key for personnel, never personal data)
- Reusable FastAPI dependencies: `get_current_user`, `get_current_active_user`,
  `require_roles(*roles)`, `require_admin` — unauthenticated → 401,
  wrong role → 403
- `app/services/auth.py` — user lookup and credential verification; inactive
  accounts and users without a hashed password fail authentication
- Role enum: `personnel`, `welfare_officer`, `commander`, `administrator`
- **Migration required:** None — the existing `users` table schema already
  has `username`, `hashed_password`, `role`, `is_active`; `alembic check`
  confirms no new operations needed
- 50 backend tests passing (config, session, models, Alembic, hashing,
  token lifecycle, login success/failure, authenticated-user dependency,
  RBAC guards)
- Synthetic demo users (`demo_personnel`, `demo_welfare_officer`,
  `demo_commander`, `demo_admin`) created and cleaned up by tests; no
  real CAPF data stored

### Assessment + Duty REST APIs (implemented)
- **Wellness assessment API** (`app/api/routes/assessments.py`):
  - `POST /assessments` — PERSONNEL only, submits their own wellness snapshot
    (validated 1–10 for stress/workload scores, 0–24 h for 7-day rest/sleep
    averages, optional notes ≤ 2000 chars)
  - `GET /assessments?personnel_key=<opaque>` — list newest-first; PERSONNEL
    always see only their own, view-roles may scope to one personnel via its
    opaque key (unknown key → 404)
  - `GET /assessments/{assessment_id}` — detail; a PERSONNEL account reading
    another personnel's record gets 404 (no existence leak), view-roles may
    read any
- **Duty record API** (`app/api/routes/duty_records.py`):
  - `POST /duty-records` — PERSONNEL only
  - `GET /duty-records`, `GET /duty-records/{record_id}` — same scoping rules
    as assessments
- **Duration safety:** when `start_time`/`end_time` are supplied together the
  server derives `duty_hours = end - start` and ignores any client-supplied
  value; durations must land in (0, 24] h. When no clock times are available a
  self-reported `duty_hours` in (0, 24] is accepted. `record_date` cannot be
  in the future; `end_time` before `start_time` → 422.
- **Schema change (justified):** added nullable `start_time` / `end_time` to
  `duty_records` so the API can support the required duty start/end fields and
  derive duration server-side. Additive migration
  `c51826e301a9_add_duty_record_start_end_times` preserves all existing data.
  Named migration path is `duty_type` validated against the `DutyType` enum and
  `deployment_id` opaque ≤ 64 chars.
- **Privacy by design:** responses expose only the opaque `personnel_key` and
  never internal personnel IDs, hashes, or personal data.
- **Service layer:** `app/services/assessments.py`, `app/services/duty_records.py`
  (create/read + authorization), `app/services/scope.py` (role-based query
  scoping), `app/services/personnel.py` (opaque-key lookup helpers)
- **Schemas:** `app/schemas/assessment.py`, `app/schemas/duty.py`
- **Testing:** 73 backend tests passing, including 21 new API tests
  (auth 401s, validation 422s, duration derivation, own-history isolation,
  cross-personnel 404/403, officer/commander/admin access, unknown-key 404s)
- Live HTTP verification against a running uvicorn: login → 201 assessment →
  422 invalid → 201 duty (derived 8.0 h) → role-scoped lists → 401 without
  token; OpenAPI exposes all 7 paths

### Synthetic Dataset + ML Training Pipeline (implemented, SEPARATE from FastAPI)
- **Location:** `ml/` (own `ml/.venv` + `ml/requirements.txt`). Deliberately
  decoupled from the FastAPI inference path — prediction endpoints come later.
- **SYNTHETIC DATA NOTICE:** there is NO real CAPF personnel dataset. All data
  is generated (`ml/data/generate_synthetic.py`), clearly labeled synthetic
  (`SYN-*` opaque keys, no names/phones/addresses/real IDs), seed-fixed
  (`random_seed: 42`) and reproducible. Documented in
  `ml/data/SYNTHETIC_DATASET.md`.
- **Synthetic dataset v1:** 4,800 rows = 1,200 personnel × 4 weekly snapshots.
  Class mix LOW 42% / MEDIUM 33% / HIGH 25%.
  `ml/data/synthetic_risk_dataset_v1.csv` (git-ignored, regenerable).
- **Target classes:** `risk_label` ∈ {LOW, MEDIUM, HIGH}. Labels come from a
  documented weighted multi-factor heuristic + per-person latent term + noise
  (no single-feature cutoff, not trivially memorizable). Labels are NOT
  clinically validated stress diagnoses.
- **Data validation** (`ml/data/validate_synthetic.py`): missing values,
  ranges, dtypes, duplicates, class distribution, target validity — fails
  clearly (`ValidationError`) instead of training on bad data.
- **Features used by the model (16, ordered in `ml/features.py::FEATURE_NAMES`):**
  10 raw (duty_hours_7d, rest_hours_7d, sleep_hours_7d, workload_level,
  deployment_days_30d, leave_gap_days, leave_count_180d, transfers_12m,
  duty_intensity, self_report_stress) + 6 derived (duty_rest_ratio,
  sleep_deficit, deployment_intensity, leave_gap_weeks, recent_workload_trend,
  recent_duty_trend). No leakage: trends use only the same person's previous
  snapshot; split is personnel-disjoint.
- **Training** (`ml/train.py`): XGBoost (multi:softprob, balanced class
  weights, early stopping on validation, `tree_method: hist`, fixed seed),
  personnel-disjoint 70/15/15 split. Runs via `python -m ml.train`.
- **Evaluation** (`ml/evaluate.py`): accuracy, balanced accuracy, macro &
  weighted F1, per-class precision/recall/F1, confusion matrix, per-class
  PR-AUC; **HIGH-risk recall reported prominently**. Metrics are on the
  held-out synthetic test split ONLY — NOT deployment readiness.
- **Explainability** (`ml/explain.py`): SHAP TreeExplainer; local explanations
  (top contributing model factors per sample) + global mean |SHAP| per risk
  class. Framed as contributing model factors, NOT medical causes/diagnoses.
- **Artifacts** (`ml/artifacts/v1/`, mostly git-ignored): `model.json`,
  `features.json`, `label_classes.json`, `train_config.json`, `metadata.json`
  (model version, feature list/order, training config, dataset version),
  `evaluation.json`, `local_explanations.json`, `global_importance.json`.
- **Config:** `ml/config.yaml` (seed, target, dataset path/version, split
  fractions, model params, model version, artifact path) — nothing hard-coded.
- **Model version:** `v1`. **Synthetic evaluation results (v1):** accuracy
  0.588, balanced accuracy 0.585, macro F1 0.583, HIGH precision 0.579 /
  recall 0.632 / F1 0.605, PR-AUC LOW 0.803 / MEDIUM 0.438 / HIGH 0.634.
  GOOD SYNTHETIC PERFORMANCE IS NOT DEPLOYMENT READINESS — real-data
  validation remains pending.
- **Testing:** 39 ML tests pass (`ml/.venv\Scripts\python -m pytest` in
  `ml/`) — generator reproducibility, validation failures, feature
  engineering/leakage, artifact integrity, prediction format, valid
  LOW/MEDIUM/HIGH classes. No FastAPI/Flutter dependency.

### FastAPI + ML Inference Integration (implemented)
- **Automatic prediction on assessment submission:** `POST /assessments` returns
  an `AssessmentSubmitResponse` that extends `WellnessAssessmentRead` with
  `prediction: PredictionRead | null` and `prediction_skipped_reason: str | null`.
- **In-process ML:** the trained `v1` artifact is loaded inside FastAPI through
  `app.ml.inference` which reuses the shared training-side helpers
  (`ml.model_io.load_artifact`, `ml.features.compute_feature_frame`) as the
  single source of truth — the model logic is not duplicated.
- **Feature derivation:** the 10 raw model features are aggregated from the
  wellness assessment (rest/sleep/workload/stress) and the personnel's recent
  duty records (duty_hours_7d, deployment_days_30d, leave_gap_days,
  leave_count_180d, transfers_12m) via a deterministic replica of the
  generator's duty_intensity formula.
- **Missing duty data handling:** if a personnel member has no duty records in
  the last 30 days, the prediction is skipped with an explicit reason
  (`prediction_skipped_reason`). Nothing is silently fabricated — missing-data
  defaults are only used for `leave_gap_days` (365 when no LEAVE record
  exists) and are flagged in the stored feature snapshot.
- **Prediction persistence:** `Prediction` row written alongside the assessment
  within one transaction; stores risk_level, per-class probabilities,
  feature_snapshot (full 16-feature vector + raw inputs + defaults applied),
  and SHAP explanation (human-readable contributing factors).
- **SHAP contributing factors:** positive SHAP contributions toward the
  predicted class are surfaced as concise phrases (e.g. "elevated weekly duty
  hours"). Raw SHAP internals are never exposed in the API.
- **Prediction endpoints:** `GET /predictions` (newest first) and
  `GET /predictions/{id}` with the same RBAC rules as assessments: PERSONNEL
  see only their own; view-roles may scope to one personnel via opaque key.
- **Error handling:** model artifact load failure → 503; invalid features →
  422; unexpected errors → 500 with no stack traces; the assessment is not
  persisted when the model fails.
- **Config:** `ML_MODEL_VERSION` (default `v1`) and `ML_ARTIFACTS_DIR`
  (default `ml/artifacts` relative to the repository root) added to
  `app/core/config.py` and `.env.example`.
- **Backend ML deps:** numpy, pandas, xgboost, shap, scikit-learn, PyYAML
  added to `backend/requirements.txt` and installed in the backend venv.
- **No migration needed:** the Prediction schema already contained all
  required columns (model_version, probabilities, feature_snapshot,
  shap_explanation, assessment_id). `alembic check` remains clean.
- **Testing:** 14 new tests in `tests/test_predictions_api.py` covering
  automatic HIGH/MEDIUM/LOW prediction, skip on missing duty data, DB
  persistence, RBAC (own-scoped reads, cross-personnel 404/403,
  officer/commander/admin access, unknown key 404), and model-artifact
  failure safety (monkeypatched → 503, no assessment persisted).
- **Live HTTP verification:** assessment → HIGH prediction (0.913 probability)
  confirmed via running uvicorn; Prediction row verified in PostgreSQL via
  psql; contributing factors surfaced.

### FastAPI scaffolding (smoke-level)
- `backend/app/main.py` — FastAPI app + CORS middleware
- `backend/app/api/routes/health.py` — `GET /health` (status, app, version,
  environment, database connectivity)
- `backend/app/core/config.py` — settings via pydantic-settings (now
  includes `DATABASE_URL`)
- `backend/requirements.txt` (fastapi, uvicorn, pydantic, pydantic-settings,
  python-dotenv, sqlalchemy, alembic, psycopg2-binary, pytest) and
  `backend/.env.example`
- `backend/.venv` created locally

### Flutter scaffolding (smoke-level)
- Full `flutter create` scaffold in `mobile/` (android, ios, web, windows)
- `mobile/lib/main.dart` — minimal placeholder home screen only (app title,
  "SIH 2026 Prototype", "SYNTHETIC DEMO DATA" chip)
- `mobile/test/widget_test.dart` — smoke test for the placeholder screen
- Empty feature folders present: `mobile/lib/features/assessment`, `auth`,
  `profile`, `results`; plus empty `mobile/lib/core`, `widgets`

### Next.js dashboard foundation (initialized)
- `dashboard/package.json` — Next.js 15.5, React 19, TypeScript 5, all
  dependencies installed (`node_modules/` present)
- `dashboard/tsconfig.json` and `dashboard/next.config.mjs` — project
  configuration
- `dashboard/app/layout.tsx` — root layout with metadata
- `dashboard/app/globals.css` — minimal design tokens / base styles
- `dashboard/app/page.tsx` — landing page: project title, description,
  "SYNTHETIC DEMO DATA" / "PROTOTYPE" indicators, sign-in link, skip link
- `dashboard/app/login/page.tsx` — login placeholder (form present but
  disabled; auth not implemented)
- `dashboard/app/console-layout.tsx` — shared dashboard shell (header with
  project name and role badge, nav bar: Dashboard / Personnel / Reviews,
  footer with synthetic-data disclaimer)
- `dashboard/app/dashboard/page.tsx` — risk overview placeholder (LOW /
  MEDIUM / HIGH cards showing dashes; no real data)
- `dashboard/app/personnel/page.tsx` — personnel list placeholder
- `dashboard/app/reviews/page.tsx` — human-review queue placeholder
- `dashboard/components/`, `dashboard/lib/`, `dashboard/types/` — empty
  directories retained for future use
- All pages use the App Router convention; `npm run dev` starts on port
  3000 with no errors at foundation level
- All console pages display visible PROTOTYPE / DEMO and SYNTHETIC DATA
  notices per the project's security and privacy decisions
- **Not implemented in this phase:** PostgreSQL, authentication/JWT/RBAC,
  FastAPI integration, ML/XGBoost/SHAP, real personnel data, real
  predictions, notifications, complex charts, production deployment

### Not Started
- Frontend ML integration (dashboard prediction views, Flutter prediction
  display) — backend API contract ready
- Real-data validation / real CAPF data (authorized, governed) — pending
- Frontend-backend integration (API contract not frozen)
- Notifications, production deployment — pending

### Explicit implementation status
| Component | Status |
|---|---|
| Basic FastAPI foundation | Implemented (scaffold + config) |
| FastAPI `/health` endpoint | Implemented (includes database connectivity check) |
| PostgreSQL foundation | Implemented — `sih_stress_wellness` DB, SQLAlchemy models, Alembic migration `bd7a13c80cbb` applied, connection verified |
| Database entities (6 core tables) | Implemented — User, Personnel, WellnessAssessment, DutyRecord, Prediction, AuditLog |
| DB session dependency (`get_db`) | Implemented |
| Authentication foundation (bcrypt + JWT + OAuth2) | Implemented — `app/core/security.py`, `app/services/auth.py`, `app/api/routes/auth.py` |
| RBAC security dependencies | Implemented — `app/api/deps.py`: `get_current_user`, `get_current_active_user`, `require_roles`, `require_admin` |
| Wellness assessment API | Implemented — `POST/GET /assessments`, `GET /assessments/{id}`, PERSONNEL self-submit + view-role scoped reads on opaque keys; `POST` returns assessment + automatic prediction |
| Duty record API | Implemented — `POST/GET /duty-records`, `GET /duty-records/{id}`, server-derived duty duration, validation |
| Alembic migration chain | Implemented — `bd7a13c80cbb` → `c51826e301a9 (head)` (additive duty time columns); `alembic check` clean |
| Backend tests (DB + auth + RBAC + assessment/duty/prediction APIs) | Implemented — 87 passing |
| Synthetic stress-risk dataset (v1) | Implemented — 4,800 rows, seed-fixed, clearly labeled SYNTHETIC (`ml/data/generate_synthetic.py`); no real CAPF data |
| Dataset validation | Implemented — `ml/data/validate_synthetic.py` (missing/ranges/dupes/distribution/target) |
| Feature engineering | Implemented — `ml/features.py` (16 features, no leakage, personnel-disjoint split) |
| XGBoost training pipeline | Implemented — `ml/train.py`, `ml/config.yaml`, artifact **v1** in `ml/artifacts/v1` |
| Model evaluation | Implemented — `ml/evaluate.py` (accuracy, balanced acc, macro/weighted F1, per-class PR-AUC, confusion matrix; HIGH-risk recall highlighted) |
| SHAP explainability | Implemented — `ml/explain.py` (local + global, framed as model factors) |
| ML unit tests | Implemented — 39 passing (no FastAPI dependency) |
| Prediction endpoints / automatic prediction | Implemented — `POST /assessments` auto-generates risk prediction; `GET /predictions`, `GET /predictions/{id}` with RBAC scoping; 87 backend tests |
| Real-data validation | NOT implemented (pending authorized, governed data) |
| Basic Flutter scaffold | Implemented |
| Flutter minimal placeholder screen | Implemented |
| Next.js dashboard foundation | Implemented — app initialized, App Router pages, runs on port 3000 |
| Next.js login page | Placeholder only (form present, auth not wired) |
| FastAPI ↔ dashboard integration | NOT implemented |
| Flutter ↔ FastAPI integration | NOT implemented |
| Documentation files | Placeholders only |
| End-to-end testing | NOT started (backend `tests/` implements DB-layer + auth-layer + assessment/duty API tests; `ml/tests/` implements pipeline tests; Flutter has smoke test only) |
| Notifications / production deployment | NOT implemented |