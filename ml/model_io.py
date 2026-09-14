"""Model artifact loading and prediction helpers.

Artifact layout (ml/artifacts/<version>/):

  model.json          - xgboost Booster (portable JSON)
  features.json       - ordered feature names the model was trained on
  label_classes.json  - target classes and their integer mapping
  train_config.json   - training configuration snapshot
  metadata.json       - aggregate metadata (model/dataset versions, eval, SHAP)

This module is used by evaluation, explainability, and tests. FastAPI
inference integration is intentionally NOT wired here yet (later phase).
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import xgboost


@dataclass(frozen=True)
class ModelArtifact:
    booster: xgboost.Booster
    feature_names: list[str]
    classes: list[str]
    class_to_idx: dict[str, int]
    metadata_path: Path


def artifact_dir(artifacts_dir: Path, version: str) -> Path:
    return artifacts_dir / version


def load_artifact(model_dir: str | Path) -> ModelArtifact:
    """Load a trained model artifact from disk."""
    model_dir = Path(model_dir)
    model_path = model_dir / "model.json"
    features_path = model_dir / "features.json"
    classes_path = model_dir / "label_classes.json"
    if not model_path.exists():
        raise FileNotFoundError(f"model artifact not found at {model_path}")
    if not features_path.exists() or not classes_path.exists():
        raise FileNotFoundError(f"incomplete artifact in {model_dir}")

    booster = xgboost.Booster()
    booster.load_model(str(model_path))

    with open(features_path, encoding="utf-8") as fh:
        feature_names = json.load(fh)
    with open(classes_path, encoding="utf-8") as fh:
        payload = json.load(fh)

    return ModelArtifact(
        booster=booster,
        feature_names=list(feature_names),
        classes=list(payload["classes"]),
        class_to_idx=dict(payload["class_to_idx"]),
        metadata_path=model_dir / "metadata.json",
    )


def predict_proba(
    artifact: ModelArtifact, X: pd.DataFrame
) -> np.ndarray:
    """Return probability matrix of shape (n_samples, n_classes)."""
    missing = [c for c in artifact.feature_names if c not in X.columns]
    if missing:
        raise ValueError(f"missing model features in input: {missing}")
    dmat = xgboost.DMatrix(
        X[artifact.feature_names].astype(float),
        feature_names=artifact.feature_names,
    )
    proba = artifact.booster.predict(dmat)
    if proba.ndim == 1:  # binary single-column output
        proba = np.column_stack([1.0 - proba, proba])
    return proba


def predict(artifact: ModelArtifact, X: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    """Return (predicted_class_indices, probabilities)."""
    proba = predict_proba(artifact, X)
    return proba.argmax(axis=1), proba


def write_json(path: Path, data: dict[str, Any], indent: int = 2) -> None:
    path.write_text(json.dumps(data, indent=indent, default=str), encoding="utf-8")