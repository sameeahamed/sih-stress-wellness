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

Prototype development is at the **scaffolding / smoke-level foundation** stage:
a basic FastAPI backend (with `GET /health`) and a basic Flutter mobile app
(minimal placeholder screen) exist. No business functionality is implemented
yet. See `PROJECT_CONTEXT.md` for the detailed current development status and
the list of pending stages.