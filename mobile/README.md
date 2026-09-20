# SIH Stress & Wellness — Personnel Mobile App (Flutter)

The **personnel-facing** Flutter application of the SIH 2026 prototype
(AI-Based Predictive Personnel Stress and Welfare Monitoring System for CAPFs
and Uniformed Forces).

> ⚠️ **SYNTHETIC DEMO DATA.** This prototype runs only against
> deterministic synthetic seed data. There is NO real CAPF personnel data.
> The app is a self-reporting wellness tool for the SIH demo — it is NOT a
> medical diagnosis system.

---

## What the app does (MVP)

- **Login** — real JWT flow against the FastAPI backend (`POST /auth/token`),
  token persisted with `flutter_secure_storage`.
- **Home / profile** — authenticated user, role, and opaque (pseudonymized)
  personnel key via `GET /auth/me`; sign-out.
- **Wellness assessment** — validated 1–10 stress/workload, 0–24 h
  rest/sleep; `POST /assessments` auto-generates the ML stress-risk
  prediction (LOW/MEDIUM/HIGH) + SHAP contributing factors.
- **Duty record** — duty type + optional clock times; `POST /duty-records`.
  The **server derives `duty_hours`** from start/end — the app never sends
  `duty_hours` when clock times are given (parity with the backend
  contract). When only self-reported hours exist, the server uses those.
- **Prediction result** — risk level, per-class probabilities, SHAP
  contributing factors.
- **History** — user-scoped assessment/prediction history via RBAC
  (`GET /assessments`, `GET /predictions`); a personnel account only ever
  sees its own records.

401 responses (expired/invalid token) redirect to login with a clean
navigation-stack collapse.

## Prerequisites

- Flutter SDK (stable). Tested: `flutter analyze` clean, 38 widget/unit
  tests passing.
- A running FastAPI backend (see `../backend/`) with demo seed data loaded
  (`python scripts/seed_demo_data.py`). Default accounts use
  `demo-password-123` and are clearly labeled SYNTHETIC.
- No Flutter-specific DB or ML setup — the app is a pure API client.

## API base URL configuration

The base URL is injected at build/run time via a Dart define:

```sh
# Desktop / web / iOS simulator (default)
flutter run

# Android emulator (host machine is 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical device on the same LAN as the backend host
flutter run --dart-define=API_BASE_URL=http://<backend-host-ip>:8000
```

- Default: `http://localhost:8000` (see `lib/core/config.dart`).
- Cleartext HTTP is enabled in the Android manifest **for the prototype
  only** (`android:usesCleartextTraffic="true"` + `INTERNET`). This must be
  removed for any real deployment.

## Run

```sh
cd mobile
flutter pub get
flutter run                       # desktop/web/emulator, uses default base URL
```

## Test

```sh
flutter test          # 38 tests: login/auth, assessment+prediction,
                      # duty (server-derived hours), history, full flow,
                      # model parsing, RBAC-scoped history
flutter analyze       # must be clean
```

The test suite runs against a contract-mirroring fake HTTP layer — no live
backend or network needed.

## Project structure

```
mobile/
  lib/
    core/            config (API base URL), models, api_client,
                     session (AuthController), secure token store
    features/
      auth/          login screen
      home/          home + profile
      assessment/    wellness assessment form
      duty/          duty record form + result
      results/       prediction result screen
      history/       assessment/prediction history
    main.dart        entry point, auth gate, routes
  test/              widget + unit tests (38)
```

## Known limitation: Android APK build (environment, not code)

Building the Android APK on this machine is currently **environment-blocked**,
unrelated to the app code:

- The local Android SDK `cmdline-tools` CLI hard-crashes
  (`0xC0000409` / `-1073740791`) at teardown on every invocation, so AGP's
  sdkmanager probe fails and the Gradle build cannot run.
- `platforms/android-36` is not installed and cannot be added by the broken
  CLI; the installed `platforms/android-37.0` is mislabeled (ApiLevel 37.0 /
  "Android SDK Platform 17"), which AGP rejects.

The app itself compiles clean (`flutter analyze`, 38 tests). To produce an
APK on a healthy machine:

```sh
flutter build apk --debug
```

See `../PROJECT_CONTEXT.md` → "Android SDK APK build environment blocker"
for the full history.
