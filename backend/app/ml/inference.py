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

# Human-readable phrase per model feature for a feature that pushed TOWARD
# higher assessed risk (positive SHAP against the high-risk class).
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

# The protective counterpart of every phrase above, for a feature that pushed
# AWAY from higher assessed risk (negative SHAP against the high-risk class).
# Without this table a LOW or MEDIUM prediction would be described using
# risk-increasing wording, which inverts the meaning for the reader.
_PROTECTIVE_LABELS: dict[str, str] = {
    "duty_hours_7d": "lower weekly duty hours",
    "rest_hours_7d": "more rest hours",
    "sleep_hours_7d": "more sleep",
    "workload_level": "lighter self-rated workload",
    "deployment_days_30d": "little recent deployment",
    "leave_gap_days": "shorter time since last leave",
    "leave_count_180d": "more recent leave taken",
    "transfers_12m": "fewer transfers",
    "duty_intensity": "lower duty intensity",
    "self_report_stress": "lower self-reported stress",
    "duty_rest_ratio": "lower duty-to-rest ratio",
    "sleep_deficit": "little sleep deficit",
    "deployment_intensity": "lower deployment intensity",
    "leave_gap_weeks": "shorter gap since last leave",
    "recent_workload_trend": "falling workload trend",
    "recent_duty_trend": "falling duty-hours trend",
}

MAX_FACTORS = 5
SHAP_EPS = 1e-4

RISK_REFERENCE_CLASS = "high"

# Placeholder key used when reconstructing a single person's snapshot history
# for trend derivation. Inference is always evaluated for one person at a time,
# so the key only has to be stable and sort ahead of nothing.
_SINGLE_PERSONNEL_KEY = "SYN-inference"
_PREVIOUS_SNAPSHOT_ORDER = "0"
_CURRENT_SNAPSHOT_ORDER = "1"


class ModelLoadError(RuntimeError):
    """Raised when the configured model artifact cannot be loaded/used."""


@dataclass(frozen=True)
class InferenceModel:
    artifact: ModelArtifact
    explainer: "shap.TreeExplainer"
    classes: list[str]  # lowercase class names, aligned to artifact.classes
    high_idx: int | None  # index of the high-risk class, if present


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
        classes = [c.lower() for c in artifact.classes]
        model = InferenceModel(
            artifact=artifact,
            explainer=shap.TreeExplainer(artifact.booster),
            classes=classes,
            high_idx=(
                classes.index(RISK_REFERENCE_CLASS)
                if RISK_REFERENCE_CLASS in classes
                else None
            ),
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
    shap_matrix: np.ndarray, predicted_idx: int, high_idx: int
) -> list[dict[str, Any]]:
    """Top model features that pushed the assessment toward its own class.

    Explanations are always anchored to the high-risk class so the wording can
    never invert:

    * a HIGH prediction lists the features with the largest POSITIVE SHAP
      against high risk, described with risk-increasing phrases;
    * a LOW or MEDIUM prediction lists the features with the largest NEGATIVE
      SHAP against high risk (the features that held assessed risk down),
      described with protective phrases.

    Only one direction is reported per prediction. If no feature clears the
    threshold in the relevant direction an empty list is returned rather than
    falling back to wording that would contradict the prediction.
    """
    row_contrib = shap_matrix[0, :, high_idx]
    if predicted_idx == high_idx:
        direction = "toward_higher_risk"
        labels = _FACTOR_LABELS
        candidates = [i for i in range(len(row_contrib)) if row_contrib[i] > SHAP_EPS]
    else:
        direction = "toward_lower_risk"
        labels = _PROTECTIVE_LABELS
        candidates = [i for i in range(len(row_contrib)) if row_contrib[i] < -SHAP_EPS]

    # Strongest contribution first in the relevant direction.
    candidates.sort(key=lambda i: row_contrib[i], reverse=predicted_idx == high_idx)

    factors: list[dict[str, Any]] = []
    for f_idx in candidates[:MAX_FACTORS]:
        feature = FEATURE_NAMES[f_idx]
        factors.append(
            {
                "feature": feature,
                "shap_value": round(float(row_contrib[f_idx]), 5),
                "factor": labels[feature],
                "direction": direction,
            }
        )
    return factors


def run_prediction(
    raw_features: dict[str, float],
    defaults_applied: list[str] | None = None,
    version: str | None = None,
    previous_features: dict[str, float] | None = None,
) -> dict[str, Any]:
    """Compute a risk prediction + SHAP factors from the 10 raw features.

    ``previous_features`` supplies the same person's preceding snapshot so the
    week-over-week trend features are computed exactly as they are in training.
    Training derives them with a per-person ``shift(1)`` (see
    ml/features.py), which on a single-row frame always yields 0.0 - the value
    for a person's first snapshot only. Passing the previous row reproduces the
    training derivation rather than reimplementing it, so the two cannot drift.

    When no previous snapshot exists the features are legitimately 0.0, which
    is what training produces for a first snapshot.
    """
    model = get_inference_model(version)
    missing = [name for name in RAW_FEATURES if name not in raw_features]
    if missing:
        raise ValueError(f"missing model features in input: {missing}")

    raw = {name: float(raw_features[name]) for name in RAW_FEATURES}
    rows = [
        {
            "personnel_key": _SINGLE_PERSONNEL_KEY,
            "week_start": _CURRENT_SNAPSHOT_ORDER,
            **raw,
        }
    ]
    if previous_features is not None:
        previous_missing = [
            name for name in RAW_FEATURES if name not in previous_features
        ]
        if previous_missing:
            raise ValueError(
                f"missing previous-snapshot features in input: {previous_missing}"
            )
        rows.insert(
            0,
            {
                "personnel_key": _SINGLE_PERSONNEL_KEY,
                "week_start": _PREVIOUS_SNAPSHOT_ORDER,
                **{name: float(previous_features[name]) for name in RAW_FEATURES},
            },
        )

    # Derive on the full history, then score the current (last) snapshot only.
    X = compute_feature_frame(pd.DataFrame(rows)).iloc[[-1]]
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
    top_factors = _top_factors(
        shap_matrix,
        predicted_idx,
        model.high_idx if model.high_idx is not None else predicted_idx,
    )

    version_used = version or settings.ML_MODEL_VERSION
    feature_snapshot = {
        "model_version": version_used,
        "feature_names": FEATURE_NAMES,
        "features": {
            col: round(float(X.iloc[0][col]), 5) for col in FEATURE_NAMES
        },
        "defaults_applied": sorted(defaults_applied or []),
    }
    is_high = predicted_idx == (model.high_idx if model.high_idx is not None else predicted_idx)
    factor_direction = "toward_higher_risk" if is_high else "toward_lower_risk"
    direction_label = "higher assessed risk" if is_high else "lower assessed risk"
    shap_explanation = {
        "model_version": version_used,
        "disclaimer": (
            "Model feature associations, not medical causes and not a "
            "diagnosis. These are the strongest inputs the model weighted "
            f"toward {direction_label}; they do not explain or establish why "
            "this person is where they are. Trained on synthetic prototype "
            "data, and a welfare officer remains responsible for any follow-up."
        ),
        "predicted_class": predicted_class,
        "factor_direction": factor_direction,
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