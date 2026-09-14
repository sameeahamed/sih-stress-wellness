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
foundation.** The architecture is finalized. FastAPI backend, Flutter mobile
app, and Next.js dashboard exist at foundation level. PostgreSQL is complete
with six SQLAlchemy models and an applied Alembic migration. The
authentication and RBAC security foundation is now in place: bcrypt password
hashing, JWT access tokens, OAuth2 login, current-user dependency, and
role-based route guards are implemented and tested. No business functionality
(assessment, prediction, review), ML, or frontend–backend integration is
implemented yet.

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
- **Migration status:** `bd7a13c80cbb (head)` applied via
  `alembic upgrade head`; all six tables + `alembic_version` present in
  PostgreSQL. No destructive migrations.
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
- FastAPI assessment APIs, duty endpoints, prediction endpoints, dashboard
  APIs — RBAC foundation ready, pending integration
- Synthetic dataset generation
- XGBoost training, inference, and model artifacts
- SHAP explanations
- Real frontend-backend integration (API contract not frozen)
- Flutter ↔ FastAPI integration, Next.js ↔ FastAPI integration — pending
- Notifications, production deployment — pending

### Explicit implementation status
| Component | Status |
|---|---|
| Basic FastAPI foundation | Implemented (scaffold + config) |
| FastAPI `/health` endpoint | Implemented (includes database connectivity check) |
| PostgreSQL foundation | Implemented — `sih_stress_wellness` DB, SQLAlchemy models, Alembic migration `bd7a13c80cbb (head)` applied, connection verified |
| Database entities (6 core tables) | Implemented — User, Personnel, WellnessAssessment, DutyRecord, Prediction, AuditLog |
| DB session dependency (`get_db`) | Implemented |
| Authentication foundation (bcrypt + JWT + OAuth2) | Implemented — `app/core/security.py`, `app/services/auth.py`, `app/api/routes/auth.py` |
| RBAC security dependencies | Implemented — `app/api/deps.py`: `get_current_user`, `get_current_active_user`, `require_roles`, `require_admin` |
| Backend tests (DB + auth + RBAC) | Implemented — 50 passing |
| Basic Flutter scaffold | Implemented |
| Flutter minimal placeholder screen | Implemented |
| Next.js dashboard foundation | Implemented — app initialized, App Router pages, runs on port 3000 |
| Next.js login page | Placeholder only (form present, auth not wired) |
| ML (XGBoost) / SHAP | NOT implemented |
| Prediction logic / prediction endpoints | NOT implemented (storage ready) |
| FastAPI ↔ dashboard integration | NOT implemented |
| Flutter ↔ FastAPI integration | NOT implemented |
| Documentation files | Placeholders only |
| End-to-end testing | NOT started (backend `tests/` implements DB-layer + auth-layer tests; Flutter has smoke test only) |
| Notifications / production deployment | NOT implemented |