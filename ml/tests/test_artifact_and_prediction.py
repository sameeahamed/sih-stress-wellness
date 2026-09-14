"""Tests for model artifact integrity and prediction output format.

These tests load the actual trained artifact under ml/artifacts/v1 and are
Skipped gracefully when it has not been trained yet (run
`python -m ml.train` first). They do not require FastAPI or Flutter.
"""

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from ml.features import FEATURE_NAMES
from ml.model_io import predict, predict_proba, load_artifact

ARTIFACT_DIR = Path(__file__).resolve().parents[1] / "artifacts" / "v1"
REQUIRED_FILES = [
    "model.json",
    "features.json",
    "label_classes.json",
    "train_config.json",
    "metadata.json",
]


@pytest.fixture(scope="module")
def artifact():
    if not (ARTIFACT_DIR / "model.json").exists():
        pytest.skip("trained artifact not present; run 'python -m ml.train' first")
    return load_artifact(ARTIFACT_DIR)


def test_artifact_files_exist() -> None:
    if not (ARTIFACT_DIR / "model.json").exists():
        pytest.skip("trained artifact not present; run 'python -m ml.train' first")
    for name in REQUIRED_FILES:
        assert (ARTIFACT_DIR / name).exists(), name


def test_metadata_is_complete(artifact) -> None:
    metadata = json.loads(
        (ARTIFACT_DIR / "metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["model_version"] == "v1"
    assert metadata["dataset_version"] == "v1"
    assert metadata["target"] == "risk_label"
    assert metadata["target_classes"] == ["LOW", "MEDIUM", "HIGH"]
    assert metadata["feature_names"] == FEATURE_NAMES
    assert "training" in metadata
    assert "dataset_path" in metadata


def test_feature_order_matches_model(artifact) -> None:
    assert artifact.feature_names == FEATURE_NAMES
    assert len(artifact.feature_names) == len(set(artifact.feature_names))


def test_label_classes_mapping(artifact) -> None:
    assert set(artifact.classes) == {"LOW", "MEDIUM", "HIGH"}
    assert artifact.class_to_idx == {"LOW": 0, "MEDIUM": 1, "HIGH": 2}


def test_single_row_prediction_format(artifact) -> None:
    row = pd.DataFrame([{name: 0.0 for name in FEATURE_NAMES}])
    proba = predict_proba(artifact, row)
    assert proba.shape == (1, 3)
    assert np.all(proba >= 0.0) and np.all(proba <= 1.0)
    assert np.isclose(proba.sum(axis=1), 1.0, atol=1e-5).all()

    class_idx, proba_again = predict(artifact, row)
    assert class_idx.shape == (1,)
    assert int(class_idx[0]) in artifact.class_to_idx.values()
    assert np.isclose(proba_again.sum(axis=1), 1.0, atol=1e-5).all()


def test_predicted_class_matches_argmax_and_valid_label(artifact) -> None:
    rng = np.random.default_rng(0)
    rows = {name: rng.uniform(0, 10, size=8) for name in FEATURE_NAMES}
    X = pd.DataFrame(rows)
    class_idx, proba = predict(artifact, X)
    assert np.array_equal(class_idx, proba.argmax(axis=1))
    labels = [artifact.classes[i] for i in class_idx]
    assert set(labels) <= {"LOW", "MEDIUM", "HIGH"}


def test_evaluation_report_exists_and_is_valid() -> None:
    eval_path = ARTIFACT_DIR / "evaluation.json"
    if not eval_path.exists():
        pytest.skip("evaluation.json not present; run 'python -m ml.evaluate' first")
    report = json.loads(eval_path.read_text(encoding="utf-8"))
    assert set(report["per_class"]) == {"LOW", "MEDIUM", "HIGH"}
    for cls in ("LOW", "MEDIUM", "HIGH"):
        for metric in ("precision", "recall", "f1"):
            assert 0.0 <= report["per_class"][cls][metric] <= 1.0
    assert "high_risk_recall" in report