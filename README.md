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

Prototype development is at the **foundation / prototype scaffolding +
PostgreSQL foundation** stage: a basic FastAPI backend (with `GET /health` and
a live PostgreSQL connection via SQLAlchemy/Alembic), a basic Flutter mobile
app (minimal placeholder screen), and a Next.js dashboard (landing + login
placeholders, shared console layout, placeholder Dashboard / Personnel /
Reviews pages) exist and run locally.

**Database foundation is complete:** the `sih_stress_wellness` PostgreSQL
database, six SQLAlchemy core-entity models (User, Personnel,
WellnessAssessment, DutyRecord, Prediction, AuditLog), the Alembic migration
(`bd7a13c80cbb` at head), and the FastAPI DB session dependency are in place.
Backend DB-layer tests (18) pass.

No business functionality is implemented yet — no authentication, assessment
APIs, ML, or frontend–backend integration. See `PROJECT_CONTEXT.md` for the
detailed current development status and the list of pending stages.

### Running the backend

```bash
cd backend
python -m venv .venv                 # first time only
.venv\Scripts\pip install -r requirements.txt
# create backend/.env from backend/.env.example and set DATABASE_URL
.venv\Scripts\python -m alembic upgrade head   # apply migrations
.venv\Scripts\python -m uvicorn app.main:app --reload
```

`GET http://localhost:8000/health` reports API status and database
connectivity. Run backend tests with `.venv\Scripts\python -m pytest tests/`.

### Running the dashboard

```bash
cd dashboard
npm install   # first time only
npm run dev   # starts on http://localhost:3000
```

All dashboard pages display visible PROTOTYPE / DEMO and SYNTHETIC DATA
notices; the dashboard currently uses no real CAPF data. No real or synthetic
personnel data is stored in the database.