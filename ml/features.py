"""Reproducible feature preparation and dataset splitting for the ML pipeline.

Feature set (the exact ordered list the model trains on):

Raw features
  duty_hours_7d          - weekly duty hours (hours)
  rest_hours_7d          - average daily rest (hours)
  sleep_hours_7d         - average daily sleep (hours)
  workload_level         - self-rated workload (1-10)
  deployment_days_30d    - days deployed in last 30
  leave_gap_days         - days since last leave
  leave_count_180d       - leave episodes in last 180 days
  transfers_12m          - transfers/deployments in last 12 months
  duty_intensity         - composite recent-duty intensity (0-100)
  self_report_stress     - self-reported stress level (1-10)

Derived features (built here, no leakage)
  duty_rest_ratio        - weekly duty vs weekly rest budget
  sleep_deficit          - hours short of an 8h reference
  deployment_intensity   - deployment_days_30d normalized to [0, 1]
  leave_gap_weeks        - leave_gap_days in weeks
  recent_workload_trend  - workload change vs the person's previous week (0 on first)
  recent_duty_trend      - duty-hours change vs the person's previous week (0 on first)

No target information is used and no future information is read: trend
features use only the same person's previous snapshot.

The train/validation/test split is done by the personnel opaque key so a
person's snapshots never span more than one split (no person-level leakage).
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from ml.data.generate_synthetic import (
    COLUMN_RANGES,
    FEATURE_COLUMNS,
    TARGET_CLASSES,
)

TARGET = "risk_label"
KEY_COLUMNS = ["personnel_key", "week_start"]

CLASS_TO_IDX = {c: i for i, c in enumerate(TARGET_CLASSES)}
IDX_TO_CLASS = {i: c for c, i in CLASS_TO_IDX.items()}

# Final ordered feature list used by the model (documents "features used").
FEATURE_NAMES = [
    # raw
    "duty_hours_7d",
    "rest_hours_7d",
    "sleep_hours_7d",
    "workload_level",
    "deployment_days_30d",
    "leave_gap_days",
    "leave_count_180d",
    "transfers_12m",
    "duty_intensity",
    "self_report_stress",
    # derived
    "duty_rest_ratio",
    "sleep_deficit",
    "deployment_intensity",
    "leave_gap_weeks",
    "recent_workload_trend",
    "recent_duty_trend",
]

_EPS = 1e-6


def load_dataset(path: str | Path) -> pd.DataFrame:
    """Read the CSV, keeping opaque keys and dates as strings."""
    df = pd.read_csv(path, dtype={COL: "str" for COL in KEY_COLUMNS})
    return df.sort_values(KEY_COLUMNS).reset_index(drop=True)


def compute_feature_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Compute the ordered model feature matrix WITHOUT needing the target.

    Meant for inference-time use (tests, explainability, and later FastAPI
    integration) on rows that carry the raw feature columns. A minimal
    ``personnel_key``/``week_start`` is enough to keep trend derivation stable.
    Mirrors ``build_features`` row canonicalization when keys are present.
    """
    frame = df.copy()
    for col in KEY_COLUMNS:
        if col not in frame.columns:
            frame[col] = "SYN-unknown"
    if all(col in df.columns for col in KEY_COLUMNS):
        frame.sort_values(KEY_COLUMNS, inplace=True, kind="stable")
    frame.reset_index(drop=True, inplace=True)
    return _derive_features(frame)[FEATURE_NAMES]


def build_features(df: pd.DataFrame) -> tuple[pd.DataFrame, np.ndarray]:
    """Return (X, y) with derived features added and target integer-encoded.

    Derived features are computed on the full frame BEFORE any split so that
    training and evaluation environments produce identical values. Leakage
    is avoided because every feature is derived from same-row raw values or
    from the same person's earlier snapshot only. Rows are canonicalized to
    (personnel_key, week_start) ordering so trend deltas are stable.
    """
    frame = df.copy()
    frame.sort_values(KEY_COLUMNS, inplace=True, kind="stable")
    frame.reset_index(drop=True, inplace=True)
    X = _derive_features(frame)[FEATURE_NAMES]
    if X.isna().any().any():
        raise ValueError("feature matrix contains NaN - check derived features")
    y = frame[TARGET].map(CLASS_TO_IDX).to_numpy(dtype=np.int64)
    return X, y


def _derive_features(frame: pd.DataFrame) -> pd.DataFrame:
    """Add derived feature columns to a copy of the input frame."""
    frame = frame.copy()
    duty = frame["duty_hours_7d"].astype(float)
    rest = frame["rest_hours_7d"].astype(float)
    sleep = frame["sleep_hours_7d"].astype(float)

    frame["duty_rest_ratio"] = duty / (rest * 7.0 + _EPS)
    frame["sleep_deficit"] = (8.0 - sleep).clip(lower=0.0)
    frame["deployment_intensity"] = (
        frame["deployment_days_30d"].astype(float) / 30.0
    )
    frame["leave_gap_weeks"] = frame["leave_gap_days"].astype(float) / 7.0

    # Person-level previous-week values (delta vs previous week; 0 for the
    # person's first snapshot).
    prev_workload = frame.groupby("personnel_key")["workload_level"].shift(1)
    prev_duty = frame.groupby("personnel_key")["duty_hours_7d"].shift(1)
    frame["recent_workload_trend"] = (
        frame["workload_level"].astype(float) - prev_workload
    ).fillna(0.0)
    frame["recent_duty_trend"] = (duty - prev_duty).fillna(0.0)
    return frame


def split_by_personnel(
    df: pd.DataFrame,
    seed: int,
    val_fraction: float,
    test_fraction: float,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Deterministic split by personnel key (no person appears in 2 splits)."""
    rng = np.random.default_rng(seed)
    personnel = sorted(df["personnel_key"].unique().tolist())
    rng.shuffle(personnel)

    n = len(personnel)
    n_val = int(round(n * val_fraction))
    n_test = int(round(n * test_fraction))
    train_keys = set(personnel[: n - n_val - n_test])
    val_keys = set(personnel[n - n_val - n_test : n - n_test])
    test_keys = set(personnel[n - n_test :])

    train = df[df["personnel_key"].isin(train_keys)].reset_index(drop=True)
    val = df[df["personnel_key"].isin(val_keys)].reset_index(drop=True)
    test = df[df["personnel_key"].isin(test_keys)].reset_index(drop=True)
    return train, val, test