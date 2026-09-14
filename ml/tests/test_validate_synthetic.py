"""Tests for synthetic dataset validation."""

import numpy as np
import pandas as pd
import pytest

from ml.data.generate_synthetic import generate_dataset
from ml.data.validate_synthetic import ValidationError, validate_dataset


@pytest.fixture()
def dataset() -> pd.DataFrame:
    return generate_dataset(n_personnel=120, snapshots_per_personnel=4, seed=13)


def test_accepts_clean_dataset(dataset: pd.DataFrame) -> None:
    summary = validate_dataset(dataset)
    assert summary["rows"] == len(dataset)
    assert summary["personnel"] == 120
    assert set(summary["class_distribution"]) == {"LOW", "MEDIUM", "HIGH"}


def test_detects_missing_values(dataset: pd.DataFrame) -> None:
    bad = dataset.copy()
    bad.loc[0, "duty_hours_7d"] = np.nan
    with pytest.raises(ValidationError) as exc:
        validate_dataset(bad)
    assert "duty_hours_7d" in str(exc.value)


def test_detects_out_of_range_values(dataset: pd.DataFrame) -> None:
    bad = dataset.copy()
    bad.loc[0, "duty_hours_7d"] = 999.0
    with pytest.raises(ValidationError) as exc:
        validate_dataset(bad)
    assert "out of range" in str(exc.value)


def test_detects_invalid_target(dataset: pd.DataFrame) -> None:
    bad = dataset.copy()
    bad.loc[0, "risk_label"] = "EXTREME"
    with pytest.raises(ValidationError) as exc:
        validate_dataset(bad)
    assert "invalid target" in str(exc.value)


def test_detects_duplicate_rows(dataset: pd.DataFrame) -> None:
    bad = pd.concat([dataset, dataset.iloc[[0]]], ignore_index=True)
    with pytest.raises(ValidationError) as exc:
        validate_dataset(bad)
    assert "duplicate" in str(exc.value).lower()


def test_detects_missing_column(dataset: pd.DataFrame) -> None:
    bad = dataset.drop(columns=["sleep_hours_7d"])
    with pytest.raises(ValidationError) as exc:
        validate_dataset(bad)
    assert "missing columns" in str(exc.value)


def test_detects_missing_class(dataset: pd.DataFrame) -> None:
    bad = dataset.copy()
    bad.loc[bad["risk_label"] == "MEDIUM", "risk_label"] = "LOW"
    with pytest.raises(ValidationError) as exc:
        validate_dataset(bad)
    assert "class" in str(exc.value)


def test_detects_non_numeric_feature(dataset: pd.DataFrame) -> None:
    bad = dataset.copy()
    bad["duty_hours_7d"] = bad["duty_hours_7d"].astype(str).str.replace(".", "_")
    with pytest.raises(ValidationError) as exc:
        validate_dataset(bad)
    assert "not numeric" in str(exc.value)