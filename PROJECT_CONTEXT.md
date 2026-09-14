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

**Stage: Foundation / prototype scaffolding.** Planning is complete. The
FastAPI backend, the Flutter mobile app, and the Next.js dashboard all exist
at foundation (smoke-level) stage with placeholder UI only. No business
functionality, data layer, authentication, ML, or frontend-backend
integration is implemented yet.

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

### FastAPI scaffolding (smoke-level)
- `backend/app/main.py` — FastAPI app + CORS middleware
- `backend/app/api/routes/health.py` — `GET /health` endpoint (status, app,
  version, environment)
- `backend/app/core/config.py` — settings via pydantic-settings
- `backend/requirements.txt` (fastapi, uvicorn, pydantic, pydantic-settings,
  python-dotenv) and `backend/.env.example`
- `backend/.venv` created locally
- Empty placeholder folders present: `backend/app/db`, `app/ml`, `app/models`,
  `app/schemas`, `app/services`, `alembic/`, `scripts/`, `tests/`

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
- PostgreSQL — no schema, migrations, or connection code
- Authentication / JWT / RBAC
- Synthetic dataset generation
- XGBoost training, inference, and model artifacts
- SHAP explanations
- Real frontend-backend integration (API contract not frozen)

### Explicit implementation status
| Component | Status |
|---|---|
| Basic FastAPI foundation | Implemented (scaffold + config) |
| FastAPI `/health` endpoint | Implemented |
| Basic Flutter scaffold | Implemented |
| Flutter minimal placeholder screen | Implemented |
| Next.js dashboard foundation | Implemented — app initialized, App Router pages, runs on port 3000 |
| Next.js login page | Placeholder only (form present, auth not wired) |
| PostgreSQL | NOT implemented |
| Authentication / JWT / RBAC | NOT implemented |
| ML (XGBoost) / SHAP | NOT implemented |
| FastAPI ↔ dashboard integration | NOT implemented |
| Documentation files | Placeholders only |
| End-to-end testing | NOT started (backend `tests/` empty; Flutter has smoke test only) |