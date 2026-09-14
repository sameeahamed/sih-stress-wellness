# SIH 2026 — AI-Based Predictive Personnel Stress & Welfare Monitoring System

A decision-support prototype for CAPFs and other uniformed forces that uses
authorized personnel and wellness data to predict stress-risk levels
(LOW / MEDIUM / HIGH) and surfaces high-risk cases to authorized welfare
officers and commanders for human review.

The system is an early-warning / welfare decision-support platform. It is
NOT a medical diagnosis system, and its outputs never automatically drive
disciplinary, career, promotion, or posting decisions.

## Repository Layout

- `mobile/` — Flutter personnel mobile application
- `dashboard/` — Next.js + React welfare-officer / commander dashboard
- `backend/` — FastAPI backend and REST API layer
- `backend/app/ml/` — inference-side ML code used by FastAPI
- `ml/` — training-side ML code and model artifacts
- `docs/` — project documentation
- `PROJECT_CONTEXT.md` — permanent source of truth for this project

## Documentation

**Read `PROJECT_CONTEXT.md` first.** It is the permanent project context and
records the problem statement, agreed stack, architecture, security and ML
decisions, MVP scope, and current development status.

Additional technical planning is tracked in `docs/`.

## Status

Prototype development is at the **foundation / PostgreSQL / authentication
security** stage: a FastAPI backend (with `GET /health`, a live PostgreSQL
connection, and `POST /auth/token` + `GET /auth/me` with RBAC role guards), a
basic Flutter mobile app (minimal placeholder screen), and a Next.js dashboard
(landing + login placeholders, shared console layout, placeholder Dashboard /
Personnel / Reviews pages) exist and run locally.

**Database foundation is complete:** the `sih_stress_wellness` PostgreSQL
database, six SQLAlchemy core-entity models (User, Personnel,
WellnessAssessment, DutyRecord, Prediction, AuditLog), the Alembic migration
(`bd7a13c80cbb` at head), and the FastAPI DB session dependency are in place.

**Authentication + RBAC foundation is complete:** bcrypt password hashing,
JWT access tokens (HS256), a standard OAuth2 password-flow login endpoint,
a `/auth/me` authenticated-user endpoint, and reusable per-route role-guard
dependencies are implemented and tested. Secrets come from environment
configuration; nothing is hard-coded. Backend tests (50) pass.

No business functionality is implemented yet — no assessment, prediction, or
review APIs, no ML, no frontend–backend integration. See `PROJECT_CONTEXT.md`
for the detailed current development status and the list of pending stages.

### Running the backend

```bash
cd backend
python -m venv .venv                 # first time only
.venv\Scripts\pip install -r requirements.txt
# create backend/.env from backend/.env.example; set DATABASE_URL and JWT_SECRET_KEY
.venv\Scripts\python -m alembic upgrade head   # apply migrations
.venv\Scripts\python -m uvicorn app.main:app --reload
```

`GET http://localhost:8000/health` reports API status and database
connectivity. `POST /auth/token` accepts `username` + `password` (form data)
and returns a bearer token. `GET /auth/me` (with `Authorization: Bearer ...`)
returns the authenticated user's minimal profile. Run backend tests with
`.venv\Scripts\python -m pytest tests/`.

### Running the dashboard

```bash
cd dashboard
npm install   # first time only
npm run dev   # starts on http://localhost:3000
```

All dashboard pages display visible PROTOTYPE / DEMO and SYNTHETIC DATA
notices; the dashboard currently uses no real CAPF data. No real or synthetic
personnel data is stored in the database.