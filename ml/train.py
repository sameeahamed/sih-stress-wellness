"""Train the XGBoost stress-risk classifier on SYNTHETIC data.

Pipeline: load config -> regenerate-or-load dataset -> validate -> build
features (on the FULL frame, before splitting) -> group split by personnel
(no person-level leakage) -> train with balanced class weights and early
stopping on the validation split -> save artifact + metadata.

The trained model is a prototype on synthetic data; it must NOT be used on
real personnel until validated against real, governed data.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import xgboost
import yaml

from ml.data.validate_synthetic import validate_dataset
from ml.features import (
    CLASS_TO_IDX,
    IDX_TO_CLASS,
    TARGET,
    build_features,
    load_dataset,
    split_by_personnel,
)
from ml.model_io import write_json

ML_ROOT = Path(__file__).resolve().parent


def _resolve(path: str) -> Path:
    return ML_ROOT / path


def _build_model_params(config: dict) -> dict:
    model_cfg = config["model"]
    return {
        "objective": model_cfg["objective"],
        "eval_metric": model_cfg["eval_metric"],
        "eta": model_cfg["eta"],
        "max_depth": model_cfg["max_depth"],
        "min_child_weight": model_cfg["min_child_weight"],
        "subsample": model_cfg["subsample"],
        "colsample_bytree": model_cfg["colsample_bytree"],
        "n_estimators": model_cfg["n_estimators"],
        "early_stopping_rounds": model_cfg["early_stopping_rounds"],
        "n_jobs": model_cfg["n_jobs"],
        "random_state": config["random_seed"],
        "tree_method": "hist",
        "seed": config["random_seed"],
    }


def main(argv: list[str] | None = None) -> int:
    with open(ML_ROOT / "config.yaml", encoding="utf-8") as fh:
        config = yaml.safe_load(fh)
    seed = config["random_seed"]
    ds = config["dataset"]
    split = config["split"]

    dataset_path = _resolve(ds["path"])
    if not dataset_path.exists():
        print(
            f"Dataset missing: {dataset_path}\n"
            "Run 'python -m ml.data.generate_synthetic' first.",
            file=sys.stderr,
        )
        return 2

    df = load_dataset(dataset_path)
    validate_dataset(df)

    X, y = build_features(df)
    train_df, val_df, test_df = split_by_personnel(
        df, seed=seed,
        val_fraction=split["val_fraction"],
        test_fraction=split["test_fraction"],
    )
    X_train, y_train = build_features(train_df)
    X_val, y_val = build_features(val_df)
    X_test, y_test = build_features(test_df)

    _, class_counts = np.unique(y_train, return_counts=True)
    print(
        f"Train/Val/Test rows: {len(X_train)}/{len(X_val)}/{len(X_test)} "
        f"(personnel-disjoint split)"
    )
    print(f"Train class counts: {dict(zip(['LOW', 'MEDIUM', 'HIGH'], class_counts))}")

    # Balanced handling of any class imbalance in the synthetic data.
    from sklearn.utils.class_weight import compute_class_weight

    sample_weight = compute_class_weight(
        "balanced", classes=np.array(list(CLASS_TO_IDX.values())), y=y_train
    )[y_train]

    params = _build_model_params(config)
    model = xgboost.XGBClassifier(**params)
    model.fit(
        X_train,
        y_train,
        eval_set=[(X_val, y_val)],
        sample_weight=sample_weight,
        verbose=False,
    )
    best_iter = model.get_booster().best_iteration
    val_mlogloss = model.evals_result()["validation_0"]["mlogloss"][best_iter]
    print(f"Best iteration: {best_iter} | validation mlogloss: {val_mlogloss:.4f}")

    # Save artifact ---------------------------------------------------------
    artifact_path = _resolve(config["artifacts_dir"]) / config["model_version"]
    artifact_path.mkdir(parents=True, exist_ok=True)

    model.get_booster().save_model(str(artifact_path / "model.json"))
    write_json(artifact_path / "features.json", list(X.columns))
    write_json(
        artifact_path / "label_classes.json",
        {
            "classes": list(IDX_TO_CLASS.values()),
            "class_to_idx": CLASS_TO_IDX,
        },
    )

    train_config = {
        "model_version": config["model_version"],
        "dataset_version": ds["version"],
        "dataset_path": str(dataset_path),
        "target": TARGET,
        "random_seed": seed,
        "split": {
            "val_fraction": split["val_fraction"],
            "test_fraction": split["test_fraction"],
            "train_rows": int(len(X_train)),
            "val_rows": int(len(X_val)),
            "test_rows": int(len(X_test)),
            "train_personnel": int(train_df["personnel_key"].nunique()),
        },
        "model_params": params,
        "best_iteration": best_iter,
        "validation_mlogloss": float(val_mlogloss),
        "xgboost_version": xgboost.__version__,
        "trained_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    write_json(artifact_path / "train_config.json", train_config)

    metadata = {
        "model_version": config["model_version"],
        "dataset_version": ds["version"],
        "dataset_path": str(dataset_path),
        "target": TARGET,
        "target_classes": list(IDX_TO_CLASS.values()),
        "feature_names": list(X.columns),
        "training": train_config,
        "evaluation": None,
        "explainability": None,
    }
    write_json(artifact_path / "metadata.json", metadata)

    print(f"Artifact saved to {artifact_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())