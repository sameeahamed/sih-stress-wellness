"""SHAP explainability for the trained prototype model.

Produces:
  * local explanations (top SHAP contributors per selected sample) - show
    which model features pushed toward the predicted risk class;
  * global feature importance (mean |SHAP|) per risk class, computed on the
    held-out test split.

Explanations describe CONTRIBUTING MODEL FACTORS. They are NOT medical
causes or diagnoses, and they are based on synthetic data only.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import shap
import yaml

from ml.data.validate_synthetic import validate_dataset
from ml.features import build_features, load_dataset, split_by_personnel
from ml.model_io import load_artifact, predict_proba, write_json

ML_ROOT = Path(__file__).resolve().parent
CLASSES = ["LOW", "MEDIUM", "HIGH"]
MAX_GLOBAL_ROWS = 500  # keep the global computation fast on the synthetic set


def _class_shap_matrix(shap_values, n_classes: int) -> np.ndarray:
    """Normalize SHAP multiclass output to (n_samples, n_features, n_classes)."""
    if isinstance(shap_values, list):
        if len(shap_values) == n_classes:
            return np.stack(shap_values, axis=-1)
        return np.repeat(shap_values[0][:, :, None], n_classes, axis=2)
    arr = np.asarray(shap_values)
    if arr.ndim == 3:
        return arr
    return np.repeat(arr[:, :, None], n_classes, axis=2)


def main(argv: list[str] | None = None) -> int:
    with open(ML_ROOT / "config.yaml", encoding="utf-8") as fh:
        config = yaml.safe_load(fh)
    seed = config["random_seed"]
    ds = config["dataset"]
    split = config["split"]
    artifact_dir = Path(ML_ROOT / config["artifacts_dir"]) / config["model_version"]

    artifact = load_artifact(artifact_dir)
    df = load_dataset(ML_ROOT / ds["path"])
    validate_dataset(df)
    _, _, test_df = split_by_personnel(
        df, seed=seed,
        val_fraction=split["val_fraction"],
        test_fraction=split["test_fraction"],
    )
    X_test, y_test = build_features(test_df)

    explainer = shap.TreeExplainer(artifact.booster)
    shap_all = explainer.shap_values(X_test)
    shap_matrix = _class_shap_matrix(shap_all, len(CLASSES))

    proba = predict_proba(artifact, X_test)
    y_pred = proba.argmax(axis=1)

    # Local explanations: first test sample predicted in each class.
    local = []
    for cls_idx, cls in enumerate(CLASSES):
        match = np.where(y_pred == cls_idx)[0]
        if len(match) == 0:
            continue
        row_idx = int(match[0])
        contributions = float(shap_matrix[row_idx, :, cls_idx].sum())  # margin delta
        top = np.argsort(np.abs(shap_matrix[row_idx, :, cls_idx]))[::-1]
        local.append(
            {
                "personnel_key": test_df.iloc[row_idx]["personnel_key"],
                "week_start": test_df.iloc[row_idx]["week_start"],
                "predicted_label": cls,
                "true_label": CLASSES[int(y_test[row_idx])],
                "predicted_probabilities": {
                    c: float(proba[row_idx, i]) for i, c in enumerate(CLASSES)
                },
                "prediction_score_margin": round(float(contributions), 4),
                "top_contributors": [
                    {
                        "feature": str(X_test.columns[f]),
                        "value": float(X_test.iloc[row_idx, f]),
                        "shap": round(float(shap_matrix[row_idx, f, cls_idx]), 4),
                    }
                    for f in top[:6]
                ],
            }
        )

    # Global importance per class on a capped subsample of the test split.
    sample = X_test.iloc[:MAX_GLOBAL_ROWS]
    global_importance = []
    for cls_idx, cls in enumerate(CLASSES):
        mean_abs = np.abs(shap_matrix[: len(sample), :, cls_idx]).mean(axis=0)
        order = np.argsort(mean_abs)[::-1]
        global_importance.append(
            {
                "class": cls,
                "computed_rows": int(len(sample)),
                "mean_abs_shap": [
                    {
                        "feature": str(sample.columns[i]),
                        "mean_abs_shap": round(float(mean_abs[i]), 5),
                    }
                    for i in order
                ],
            }
        )

    write_json(
        artifact_dir / "local_explanations.json",
        {
            "model_version": config["model_version"],
            "dataset_version": ds["version"],
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "disclaimer": (
                "Contributing model factors only - not medical causes or "
                "diagnoses. Computed on synthetic data."
            ),
            "samples": local,
        },
    )
    write_json(
        artifact_dir / "global_importance.json",
        {
            "model_version": config["model_version"],
            "dataset_version": ds["version"],
            "classes": CLASSES,
            "per_class": global_importance,
        },
    )

    json_path = artifact_dir / "metadata.json"
    metadata = json.loads(json_path.read_text(encoding="utf-8"))
    metadata["explainability"] = {
        "approach": "SHAP TreeExplainer (local + global importance)",
        "local_explanations": str(artifact_dir / "local_explanations.json"),
        "global_importance": str(artifact_dir / "global_importance.json"),
    }
    json_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    print("=" * 60)
    print("SHAP EXPLAINABILITY (SYNTHETIC TEST SPLIT)")
    print("=" * 60)
    for entry in local:
        print(f"\nPredicted {entry['predicted_label']} (true {entry['true_label']}), "
              f"{entry['personnel_key']} @ {entry['week_start']}")
        print(f"  probabilities: {entry['predicted_probabilities']}")
        top = entry["top_contributors"][:4]
        print(f"  top contributing model factors toward {entry['predicted_label']}:")
        for c in top:
            print(f"    {c['feature']:<22} value={c['value']:<8.2f} "
                  f"shap={c['shap']:+.4f}")
    print()
    print("Contributing model factors only - NOT medical causes or diagnoses.")
    print("local_explanations.json + global_importance.json written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())