"""Tests for feature engineering: correctness, determinism, and no leakage."""

import numpy as np
import pandas as pd
import pytest

from ml.data.generate_synthetic import generate_dataset
from ml.features import (
    CLASS_TO_IDX,
    FEATURE_NAMES,
    TARGET,
    build_features,
    compute_feature_frame,
    split_by_personnel,
)


@pytest.fixture()
def dataset() -> pd.DataFrame:
    return generate_dataset(n_personnel=80, snapshots_per_personnel=4, seed=17)


def test_feature_set_is_exact_model_column_list(dataset: pd.DataFrame) -> None:
    X, _ = build_features(dataset)
    assert list(X.columns) == FEATURE_NAMES


def test_raw_keys_and_target_are_not_features(dataset: pd.DataFrame) -> None:
    X, _ = build_features(dataset)
    for forbidden in ("personnel_key", "week_start", TARGET):
        assert forbidden not in X.columns, forbidden


def test_no_nan_in_feature_matrix(dataset: pd.DataFrame) -> None:
    X, _ = build_features(dataset)
    assert not X.isna().any().any()


def test_label_encoding_matches_class_map(dataset: pd.DataFrame) -> None:
    sorted_dataset = dataset.sort_values(
        ["personnel_key", "week_start"]
    ).reset_index(drop=True)
    _, y = build_features(sorted_dataset)
    expected = sorted_dataset[TARGET].map(CLASS_TO_IDX).to_numpy()
    assert np.array_equal(y, expected)
    assert set(np.unique(y)) == {0, 1, 2}


def test_derived_features_present(dataset: pd.DataFrame) -> None:
    derived = {
        "duty_rest_ratio",
        "sleep_deficit",
        "deployment_intensity",
        "leave_gap_weeks",
        "recent_workload_trend",
        "recent_duty_trend",
    }
    assert derived.issubset(set(FEATURE_NAMES))


def test_trend_features_use_only_past_snapshots(dataset: pd.DataFrame) -> None:
    sorted_df = dataset.sort_values(["personnel_key", "week_start"]).reset_index(drop=True)
    X, _ = build_features(sorted_df)

    expected_workload = (
        sorted_df["workload_level"]
        - sorted_df.groupby("personnel_key")["workload_level"].shift(1)
    ).fillna(0.0).to_numpy()
    expected_duty = (
        sorted_df["duty_hours_7d"]
        - sorted_df.groupby("personnel_key")["duty_hours_7d"].shift(1)
    ).fillna(0.0).to_numpy()

    np.testing.assert_allclose(
        X["recent_workload_trend"].to_numpy(),
        expected_workload.astype(float),
        atol=1e-6,
    )
    np.testing.assert_allclose(
        X["recent_duty_trend"].to_numpy(),
        expected_duty.astype(float),
        atol=1e-6,
    )


def test_first_snapshot_trend_is_zero(dataset: pd.DataFrame) -> None:
    sorted_dataset = dataset.sort_values(
        ["personnel_key", "week_start"]
    ).reset_index(drop=True)
    X, _ = build_features(sorted_dataset)
    first_positions = sorted_dataset.groupby("personnel_key").head(1).index
    assert np.all(X.loc[first_positions, "recent_workload_trend"] == 0.0)
    assert np.all(X.loc[first_positions, "recent_duty_trend"] == 0.0)


def test_split_is_personnel_disjoint(dataset: pd.DataFrame) -> None:
    train, val, test = split_by_personnel(
        dataset, seed=42, val_fraction=0.15, test_fraction=0.15
    )
    train_keys = set(train["personnel_key"])
    val_keys = set(val["personnel_key"])
    test_keys = set(test["personnel_key"])
    assert not (train_keys & val_keys)
    assert not (train_keys & test_keys)
    assert not (val_keys & test_keys)
    assert len(train_keys) + len(val_keys) + len(test_keys) == dataset["personnel_key"].nunique()


def test_split_is_deterministic(dataset: pd.DataFrame) -> None:
    kw = dict(seed=99, val_fraction=0.15, test_fraction=0.15)
    t1, v1, te1 = split_by_personnel(dataset, **kw)
    t2, v2, te2 = split_by_personnel(dataset, **kw)
    assert set(t1["personnel_key"]) == set(t2["personnel_key"])
    assert set(te1["personnel_key"]) == set(te2["personnel_key"])


def test_build_features_is_deterministic(dataset: pd.DataFrame) -> None:
    X1, y1 = build_features(dataset)
    X2, y2 = build_features(dataset)
    pd.testing.assert_frame_equal(X1, X2)
    np.testing.assert_array_equal(y1, y2)


def test_compute_feature_frame_matches_build_features(dataset: pd.DataFrame) -> None:
    X, _ = build_features(dataset)
    X_inf = compute_feature_frame(dataset)
    pd.testing.assert_frame_equal(X_inf, X)


def test_compute_feature_frame_works_on_raw_inference_row(dataset: pd.DataFrame) -> None:
    raw = dataset[["duty_hours_7d", "rest_hours_7d", "sleep_hours_7d",
                   "workload_level", "deployment_days_30d", "leave_gap_days",
                   "leave_count_180d", "transfers_12m", "duty_intensity",
                   "self_report_stress"]].iloc[[0]]
    X = compute_feature_frame(raw)
    assert list(X.columns) == FEATURE_NAMES
    assert not X.isna().any().any()