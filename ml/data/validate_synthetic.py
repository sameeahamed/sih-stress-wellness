"""Validate the synthetic dataset before it enters training.

Checks missing values, invalid ranges, duplicate rows, class distribution,
feature data types, and target validity. Any failure raises ``ValidationError``
so the pipeline fails clearly instead of silently training on bad data.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

from ml.data.generate_synthetic import (
    COLUMN_RANGES,
    FEATURE_COLUMNS,
    TARGET_CLASSES,
)

ML_ROOT = Path(__file__).resolve().parents[1]

KEY_COLUMNS = ["personnel_key", "week_start"]
MIN_CLASS_FRACTION = 0.05  # every class must be at least 5% of the data


class ValidationError(Exception):
    """Raised when the dataset fails a validation check."""


def validate_dataset(df: pd.DataFrame) -> dict:
    """Run all checks and return a summary dict; raise on any failure."""
    errors: list[str] = []

    missing_columns = [c for c in KEY_COLUMNS + FEATURE_COLUMNS + ["risk_label"]
                       if c not in df.columns]
    if missing_columns:
        errors.append(f"missing columns: {missing_columns}")

    if errors:
        raise ValidationError("; ".join(errors))

    for col in KEY_COLUMNS:
        if df[col].isna().any():
            errors.append(f"missing key values in column '{col}'")

    for col in FEATURE_COLUMNS:
        if df[col].isna().any():
            errors.append(f"missing values in column '{col}'")
        if not pd.api.types.is_numeric_dtype(df[col]):
            errors.append(f"column '{col}' is not numeric")
            continue
        numeric = df[col].astype(float)
        lo, hi = COLUMN_RANGES[col]
        bad = numeric[(numeric < lo) | (numeric > hi)]
        if not bad.empty:
            errors.append(
                f"column '{col}' out of range [{lo}, {hi}]: {len(bad)} value(s)"
            )

    if df["risk_label"].isna().any():
        errors.append("missing values in target column 'risk_label'")
    bad_labels = set(df["risk_label"].dropna().unique()) - set(TARGET_CLASSES)
    if bad_labels:
        errors.append(f"invalid target values: {sorted(bad_labels)}")

    if df.duplicated().any():
        errors.append(f"{int(df.duplicated().sum())} fully duplicate row(s)")

    key_dupes = df.duplicated(subset=KEY_COLUMNS).any()
    if key_dupes:
        errors.append(
            f"duplicate (personnel_key, week_start) pairs: "
            f"{int(df.duplicated(subset=KEY_COLUMNS).sum())}"
        )

    counts = df["risk_label"].value_counts()
    present = [c for c in TARGET_CLASSES if c in counts.index]
    if len(present) != len(TARGET_CLASSES):
        errors.append(f"missing class(es): {set(TARGET_CLASSES) - set(present)}")
    if not df.empty:
        fracs = counts / len(df)
        low = [c for c in TARGET_CLASSES
               if c in fracs.index and fracs[c] < MIN_CLASS_FRACTION]
        if low:
            errors.append(
                f"class(es) below {MIN_CLASS_FRACTION:.0%} of data: {low}"
            )

    if len(df) < 200:
        errors.append(f"dataset too small for training: {len(df)} rows")

    if errors:
        raise ValidationError("\n  - ".join(["invalid dataset:", *errors]))

    return {
        "rows": int(len(df)),
        "personnel": int(df["personnel_key"].nunique()),
        "class_distribution": {
            c: int(counts.get(c, 0)) for c in TARGET_CLASSES
        },
        "class_fractions": {
            c: float(counts.get(c, 0) / len(df)) for c in TARGET_CLASSES
        },
    }


def main(argv: list[str] | None = None) -> int:
    with open(ML_ROOT / "config.yaml", encoding="utf-8") as fh:
        config = yaml.safe_load(fh)
    dataset_path = ML_ROOT / config["dataset"]["path"]

    if not dataset_path.exists():
        print(
            f"Dataset not found at {dataset_path}. "
            "Run 'python -m ml.data.generate_synthetic' first.",
            file=sys.stderr,
        )
        return 2

    df = pd.read_csv(dataset_path)
    summary = validate_dataset(df)
    counts = summary["class_distribution"]
    print(f"Dataset OK: {summary['rows']} rows, {summary['personnel']} personnel")
    print(
        "Class distribution (LOW / MEDIUM / HIGH): "
        f"{counts['LOW']} / {counts['MEDIUM']} / {counts['HIGH']} "
        f"(fractions {list(round(f, 3) for f in summary['class_fractions'].values())})"
    )
    print("SYNTHETIC DATA ONLY - not real CAPF personnel data.")
    return 0


if __name__ == "__main__":
    sys.exit(main())