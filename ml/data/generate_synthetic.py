"""Generate a reproducible SYNTHETIC stress-risk dataset.

IMPORTANT
---------
This generator produces purely synthetic data for the SIH prototype ONLY. It
does NOT represent, claim to represent, or resemble real CAPF personnel
records. There is no real CAPF dataset available; production deployment
requires authorized, governed, validated real-world data.

No real names, phone numbers, addresses, personnel IDs, or medical diagnoses
are used. Personnel are identified only by clearly synthetic opaque keys
(prefix ``SYN-``).

Label generation (documented approach)
-------------------------------------
There is no clinical ground truth, so the LOW / MEDIUM / HIGH risk label is
produced by a weighted multi-factor heuristic plus noise:

    risk_score = f(duty_hours, rest, workload, deployment_days, self_report,
                   personnel_latent_stress) + N(0, 0.5)

The heuristic deliberately:
  * combines MANY features so no single feature is a trivial threshold;
  * includes a per-person latent-stress term so one person trends consistently;
  * adds Gaussian noise and cross-feature correlations so the task is not
    trivially memorizable by a single split;
  * assigns labels by percentile thresholds (≈40 / 35 / 25) computed over the
    full generated set, keeping the class distribution stable.

These labels are a stand-in for demonstration and pipeline development only.
They must NEVER be presented as clinically validated stress diagnoses and the
resulting model must not be used on real personnel without real-data
validation.
"""

from __future__ import annotations

import sys
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

ML_ROOT = Path(__file__).resolve().parents[1]

# (column, min, max) used both by the generator and the validator.
COLUMN_RANGES = {
    "duty_hours_7d": (0.0, 84.0),
    "rest_hours_7d": (0.0, 14.0),
    "sleep_hours_7d": (0.0, 12.0),
    "workload_level": (1.0, 10.0),
    "deployment_days_30d": (0.0, 30.0),
    "leave_gap_days": (0.0, 365.0),
    "leave_count_180d": (0.0, 20.0),
    "transfers_12m": (0.0, 20.0),
    "duty_intensity": (0.0, 100.0),
    "self_report_stress": (1.0, 10.0),
}

FEATURE_COLUMNS = list(COLUMN_RANGES.keys())

ANCHOR_MONDAY = date(2026, 9, 7)  # synthetic timeline anchor (a Monday)
TARGET_CLASSES = ("LOW", "MEDIUM", "HIGH")
LOW_Q = 0.42  # below this risk-score quantile -> LOW
HIGH_Q = 0.75  # above this risk-score quantile -> HIGH


def _clip(value, lo, hi):
    return float(min(max(value, lo), hi))


def _random_weeks(rng: np.random.Generator, n: int) -> list[str]:
    """Return the last ``n`` Monday dates (newest last) as ISO strings."""
    weeks = [ANCHOR_MONDAY - timedelta(weeks=n - 1 - i) for i in range(n)]
    return [w.isoformat() for w in weeks]


def generate_dataset(
    n_personnel: int = 1200,
    snapshots_per_personnel: int = 4,
    seed: int = 42,
) -> pd.DataFrame:
    """Generate the synthetic dataset as a clean pandas DataFrame."""
    rng = np.random.default_rng(seed)
    weeks = _random_weeks(rng, snapshots_per_personnel)
    rows: list[dict] = []
    risk_scores: list[float] = []

    for _ in range(n_personnel):
        opaque_key = f"SYN-{rng.integers(0, 16**8):08x}"
        # Personnel-level latent factors (make one person trend consistently).
        latent_stress = float(rng.normal(0.0, 1.0))
        base_duty = _clip(rng.normal(38.0, 9.0), 20.0, 70.0)
        base_workload = _clip(rng.normal(6.0, 1.3), 2.0, 9.0)

        for week in weeks:
            weeks_since_leave = int(rng.integers(0, 26))
            on_leave = weeks_since_leave == 0
            leave_gap_days = weeks_since_leave * 7 + int(rng.integers(0, 7))

            if on_leave:
                deployment_days_30d = 0.0
            elif rng.random() < 0.18:
                deployment_days_30d = float(rng.integers(12, 31))
            else:
                deployment_days_30d = 0.0

            duty = base_duty + float(rng.normal(0.0, 5.0))
            if on_leave:
                duty = float(rng.uniform(0.0, 8.0))
            elif deployment_days_30d > 0:
                duty += float(rng.uniform(8.0, 18.0))
            duty = _clip(duty, 0.0, 84.0)

            rest = float(rng.uniform(4.0, 9.0)) - 0.05 * (duty - 30.0)
            if on_leave:
                rest = float(rng.uniform(8.0, 12.0))
            rest = _clip(rest, 0.0, 14.0)

            sleep = 5.5 + 0.35 * (rest - 6.0) + float(rng.normal(0.0, 0.6))
            sleep = _clip(sleep, 3.0, 10.0)

            workload = round(
                _clip(base_workload + (duty - 38.0) / 8.0 + rng.normal(0.0, 0.7), 1, 10)
            )

            leave_count_180d = float(_clip(rng.poisson(1.4), 0, 10))
            transfers_12m = float(_clip(rng.poisson(0.7), 0, 6))

            duty_intensity = _clip(
                (duty / 84.0) * 45.0
                + (deployment_days_30d / 30.0) * 35.0
                + workload * 2.0
                + rng.normal(0.0, 6.0),
                0.0,
                100.0,
            )

            self_report_stress = round(
                _clip(
                    latent_stress * 1.2
                    + duty / 12.0
                    + workload * 0.6
                    + (8.0 - sleep) * 0.5
                    + (1.0 - rest / 9.0) * 3.0
                    + rng.normal(0.0, 1.2),
                    1,
                    10,
                )
            )

            # Weighted multi-factor risk heuristic (documented above).
            risk_score = (
                0.22 * (duty - 38.0) / 12.0
                + 0.22 * (9.0 - rest) / 3.0
                + 0.16 * (workload - 5.5) / 2.0
                + 0.10 * deployment_days_30d / 25.0
                + 0.12 * (self_report_stress - 5.5) / 2.2
                + 0.12 * latent_stress
                + 0.06 * (duty_intensity - 40.0) / 40.0
                + 0.05 * min(leave_gap_days, 90) / 90.0
                + 0.05 * min(transfers_12m, 5) / 5.0
                + float(rng.normal(0.0, 0.5))
            )

            risk_scores.append(risk_score)
            rows.append(
                {
                    "personnel_key": opaque_key,
                    "week_start": week,
                    "duty_hours_7d": round(duty, 1),
                    "rest_hours_7d": round(rest, 2),
                    "sleep_hours_7d": round(sleep, 2),
                    "workload_level": int(workload),
                    "deployment_days_30d": int(deployment_days_30d),
                    "leave_gap_days": int(leave_gap_days),
                    "leave_count_180d": int(leave_count_180d),
                    "transfers_12m": int(transfers_12m),
                    "duty_intensity": round(duty_intensity, 1),
                    "self_report_stress": int(self_report_stress),
                }
            )

    df = pd.DataFrame(rows)

    # Assign labels by risk-score quantiles so the class mix is stable.
    scores = np.asarray(risk_scores)
    low_thr = float(np.quantile(scores, LOW_Q))
    high_thr = float(np.quantile(scores, HIGH_Q))
    labels = np.where(
        scores < low_thr,
        "LOW",
        np.where(scores < high_thr, "MEDIUM", "HIGH"),
    )
    df["risk_label"] = labels
    return df


def _load_config() -> dict:
    with open(ML_ROOT / "config.yaml", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def main(argv: list[str] | None = None) -> int:
    config = _load_config()
    ds = config["dataset"]
    dataset_path = ML_ROOT / ds["path"]
    dataset_path.parent.mkdir(parents=True, exist_ok=True)

    df = generate_dataset(
        n_personnel=ds["n_personnel"],
        snapshots_per_personnel=ds["snapshots_per_personnel"],
        seed=config["random_seed"],
    )
    df.to_csv(dataset_path, index=False)

    counts = df["risk_label"].value_counts().reindex(TARGET_CLASSES).fillna(0)
    print(f"Wrote {len(df)} synthetic rows -> {dataset_path}")
    print(f"Class distribution:\n{counts.to_string()}")
    print("SYNTHETIC DATA ONLY - not real CAPF personnel data.")
    return 0


if __name__ == "__main__":
    sys.exit(main())