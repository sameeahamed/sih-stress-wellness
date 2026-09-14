"""Model loading, prediction and SHAP explanation for the FastAPI service.

Reuses the training-side artifacts exactly:
  * ``ml.model_io.load_artifact`` - reads model.json / features / classes;
  * ``ml.features.compute_feature_frame`` - turns the raw feature columns into
    the exact ordered 16-feature matrix the model was trained on (feature
    derivation is never duplicated here).

Only the domain mapping happens in ``app.services.predictions`` and only the
SHAP contributing-factor phrasing lives in this module.

LIMITATION: the artifact is trained and evaluated on SYNTHETIC data only. It
demonstrates prototype technical feasibility and must not be treated as
validated for real personnel deployment.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import shap

_REPO_ROOT = Path(__file__).resolve().parents[3]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from ml.features import FEATURE_NAMES, compute_feature_frame  # noqa: E402
from ml.model_io import ModelArtifact, load_artifact, predict_proba  # noqa: E402

from app.core.config import settings  # noqa: E402

# The 10 raw feature columns the model consumes before derived features.
RAW_FEATURES = [
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
]

# Human-readable phrase per model feature for a positive SHAP contribution
# toward the predicted risk class.
_FACTOR_LABELS: dict[str, str] = {
    "duty_hours_7d": "elevated weekly duty hours",
    "rest_hours_7d": "reduced rest hours",
    "sleep_hours_7d": "reduced sleep hours",
    "workload_level": "heavier self-rated workload",
    "deployment_days_30d": "recent deployment",
    "leave_gap_days": "longer time since last leave",
    "leave_count_180d": "more recorded leave episodes",
    "transfers_12m": "frequent transfers",
    "duty_intensity": "higher duty intensity",
    "self_report_stress": "elevated self-reported stress",
    "duty_rest_ratio": "higher duty-to-rest ratio",
    "sleep_deficit": "sleep deficit",
    "deployment_intensity": "higher deployment intensity",
    "leave_gap_weeks": "longer gap since last leave",
    "recent_workload_trend": "rising workload trend",
    "recent_duty_trend": "rising duty-hours trend",
}

MAX_FACTORS = 5
SHAP_EPS = 1e-4


class ModelLoadError(RuntimeError):
    """Raised when the configured model artifact cannot be loaded/used."""


@dataclass(frozen=True)
class InferenceModel:
    artifact: ModelArtifact
    explainer: "shap.TreeExplainer"
    classes: list[str]  # lowercase class names, aligned to artifact.classes


_LOADED: dict[tuple[str, Path], InferenceModel] = {}


def get_inference_model(version: str | None = None) -> InferenceModel:
    """Lazily load (and cache) the model artifact for a known version."""
    version = version or settings.ML_MODEL_VERSION
    model_dir = Path(settings.ML_ARTIFACTS_DIR) / version
    key = (version, model_dir.resolve())
    cached = _LOADED.get(key)
    if cached is not None:
        return cached

    try:
        artifact = load_artifact(model_dir)
        model = InferenceModel(
            artifact=artifact,
            explainer=shap.TreeExplainer(artifact.booster),
            classes=[c.lower() for c in artifact.classes],
        )
    except Exception as exc:
        raise ModelLoadError(
            f"Could not load ML model artifact at {model_dir}"
        ) from exc

    _LOADED[key] = model
    return model


def _shap_for_class(shap_values: Any, n_classes: int) -> np.ndarray:
    """Normalize SHAP multiclass output to (n_samples, n_features, n_classes)."""
    if isinstance(shap_values, list):
        if len(shap_values) == n_classes:
            return np.stack(shap_values, axis=-1)
        return np.repeat(shap_values[0][:, :, None], n_classes, axis=2)
    arr = np.asarray(shap_values)
    if arr.ndim == 3:
        return arr
    return np.repeat(arr[:, :, None], n_classes, axis=2)


def _top_factors(
    shap_matrix: np.ndarray, predicted_idx: int
) -> list[dict[str, Any]]:
    """Top model features that pushed TOWARD the predicted class.

    Only positive SHAP contributions (toward the predicted class) are
    surfaced; features that pushed toward other classes are not listed so the
    factor description always matches the direction of the prediction.
    """
    row_contrib = shap_matrix[0, :, predicted_idx]
    order = np.argsort(np.abs(row_contrib))[::-1]
    factors: list[dict[str, Any]] = []
    for f_idx in order:
        feature = FEATURE_NAMES[f_idx]
        score = float(row_contrib[f_idx])
        if score <= SHAP_EPS:
            continue
        label = _FACTOR_LABELS[feature]
        factors.append(
            {"feature": feature, "shap_value": round(score, 5), "factor": label}
        )
        if len(factors) >= MAX_FACTORS:
            break
    return factors


def run_prediction(
    raw_features: dict[str, float],
    defaults_applied: list[str] | None = None,
    version: str | None = None,
) -> dict[str, Any]:
    """Compute a risk prediction + SHAP factors from the 10 raw features."""
    model = get_inference_model(version)
    missing = [name for name in RAW_FEATURES if name not in raw_features]
    if missing:
        raise ValueError(f"missing model features in input: {missing}")

    raw = {name: float(raw_features[name]) for name in RAW_FEATURES}
    X = compute_feature_frame(pd.DataFrame([raw]))
    if X.isna().any().any() or not np.isfinite(X.to_numpy()).all():
        raise ValueError("model feature input contains NaN or non-finite values")

    proba = predict_proba(model.artifact, X)
    predicted_idx = int(proba.argmax(axis=1)[0])
    predicted_class = model.classes[predicted_idx]
    probabilities = {
        c: round(float(proba[0, i]), 5) for i, c in enumerate(model.classes)
    }

    shap_matrix = _shap_for_class(
        model.explainer.shap_values(X), len(model.classes)
    )
    top_factors = _top_factors(shap_matrix, predicted_idx)

    version_used = version or settings.ML_MODEL_VERSION
    feature_snapshot = {
        "model_version": version_used,
        "feature_names": FEATURE_NAMES,
        "features": {
            col: round(float(X.iloc[0][col]), 5) for col in FEATURE_NAMES
        },
        "defaults_applied": sorted(defaults_applied or []),
    }
    shap_explanation = {
        "model_version": version_used,
        "disclaimer": (
            "Contributing model factors only - not a medical diagnosis. "
            "Model trained on synthetic prototype data."
        ),
        "predicted_class": predicted_class,
        "top_factors": top_factors,
        "contributing_factors": [item["factor"] for item in top_factors],
    }

    return {
        "model_version": version_used,
        "risk_level": predicted_class,
        "probabilities": probabilities,
        "feature_snapshot": feature_snapshot,
        "shap_explanation": shap_explanation,
    }