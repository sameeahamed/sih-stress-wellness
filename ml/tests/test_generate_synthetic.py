"""Tests for synthetic data generation."""

import numpy as np
import pandas as pd
import pytest

from ml.data.generate_synthetic import (
    COLUMN_RANGES,
    FEATURE_COLUMNS,
    TARGET_CLASSES,
    generate_dataset,
)


@pytest.fixture()
def dataset() -> pd.DataFrame:
    return generate_dataset(n_personnel=120, snapshots_per_personnel=4, seed=11)


def test_reproducible_with_fixed_seed() -> None:
    a = generate_dataset(n_personnel=150, snapshots_per_personnel=4, seed=7)
    b = generate_dataset(n_personnel=150, snapshots_per_personnel=4, seed=7)
    pd.testing.assert_frame_equal(a, b)


def test_different_seed_changes_data() -> None:
    a = generate_dataset(n_personnel=150, seed=7)
    b = generate_dataset(n_personnel=150, seed=8)
    assert not a.equals(b)


def test_contains_all_expected_columns(dataset: pd.DataFrame) -> None:
    expected = FEATURE_COLUMNS + ["personnel_key", "week_start", "risk_label"]
    for col in expected:
        assert col in dataset.columns, col


def test_no_missing_values(dataset: pd.DataFrame) -> None:
    assert dataset.isna().sum().sum() == 0


def test_values_within_ranges(dataset: pd.DataFrame) -> None:
    for col, (lo, hi) in COLUMN_RANGES.items():
        assert dataset[col].min() >= lo, col
        assert dataset[col].max() <= hi, col


def test_numeric_feature_types(dataset: pd.DataFrame) -> None:
    for col in FEATURE_COLUMNS:
        assert pd.api.types.is_numeric_dtype(dataset[col]), col


def test_risk_label_uses_only_valid_classes(dataset: pd.DataFrame) -> None:
    assert set(dataset["risk_label"]) == set(TARGET_CLASSES)


def test_all_classes_present(dataset: pd.DataFrame) -> None:
    for cls in TARGET_CLASSES:
        assert int((dataset["risk_label"] == cls).sum()) > 0, cls


def test_no_duplicate_rows(dataset: pd.DataFrame) -> None:
    assert not dataset.duplicated().any()


def test_opaque_synthetic_keys(dataset: pd.DataFrame) -> None:
    assert dataset["personnel_key"].nunique() == 120
    assert dataset["personnel_key"].str.startswith("SYN-").all()


def test_each_person_has_expected_snapshots(dataset: pd.DataFrame) -> None:
    counts = dataset.groupby("personnel_key").size()
    assert (counts == 4).all()


def test_label_mix_is_multi_class_not_single_feature_threshold(dataset: pd.DataFrame) -> None:
    # The label must not be a trivial single-variable cut: every feature's
    # distribution must overlap across classes (no pure separability).
    per_class = {cls: dataset[dataset["risk_label"] == cls] for cls in TARGET_CLASSES}
    for col in ["duty_hours_7d", "self_report_stress", "workload_level", "duty_intensity"]:
        lows = per_class["LOW"][col]
        highs = per_class["HIGH"][col]
        assert lows.min() <= highs.max(), col
        assert lows.max() >= highs.min(), col