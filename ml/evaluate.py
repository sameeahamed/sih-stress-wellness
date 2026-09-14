"""Evaluate the trained model on the held-out test split (synthetic data).

Reports accuracy, balanced accuracy, macro & weighted precision/recall/F1,
per-class performance, the confusion matrix, and per-class PR-AUC
(average precision). HIGH-risk recall is reported prominently because
missing a high-risk case matters for a welfare-monitoring prototype.

Any metric here is measured on SYNTHETIC data only. Good numbers on synthetic
data do NOT mean the model is ready for real deployment; real-data validation
is still pending.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import yaml
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_recall_fscore_support,
    precision_score,
    recall_score,
)

from ml.data.validate_synthetic import validate_dataset
from ml.features import (
    IDX_TO_CLASS,
    build_features,
    load_dataset,
    split_by_personnel,
)
from ml.model_io import load_artifact, predict_proba, write_json

ML_ROOT = Path(__file__).resolve().parent
CLASSES = ["LOW", "MEDIUM", "HIGH"]


def _round(x: float, digits: int = 4) -> float:
    return round(float(x), digits)


def main(argv: list[str] | None = None) -> int:
    with open(ML_ROOT / "config.yaml", encoding="utf-8") as fh:
        config = yaml.safe_load(fh)
    seed = config["random_seed"]
    ds = config["dataset"]
    split = config["split"]

    artifact_dir = Path(ML_ROOT / config["artifacts_dir"]) / config["model_version"]
    artifact = load_artifact(artifact_dir)
    train_config_path = artifact_dir / "train_config.json"
    train_config = json.loads(train_config_path.read_text(encoding="utf-8"))
    if train_config["dataset_version"] != ds["version"]:
        raise SystemExit(
            "Version mismatch: artifact dataset version "
            f"'{train_config['dataset_version']}' != config '{ds['version']}'"
        )

    df = load_dataset(ML_ROOT / ds["path"])
    validate_dataset(df)
    _, _, test_df = split_by_personnel(
        df, seed=seed,
        val_fraction=split["val_fraction"],
        test_fraction=split["test_fraction"],
    )
    X_test, y_test = build_features(test_df)

    proba = predict_proba(artifact, X_test)
    y_pred = proba.argmax(axis=1)
    y_true = y_test

    acc = accuracy_score(y_true, y_pred)
    bal_acc = balanced_accuracy_score(y_true, y_pred)
    macro_f1 = f1_score(y_true, y_pred, average="macro")
    weighted_f1 = f1_score(y_true, y_pred, average="weighted")

    per_class_tuples = precision_recall_fscore_support(y_true, y_pred, labels=[0, 1, 2])
    per_class = {}
    pr_auc: dict[str, float] = {}
    for i, cls in enumerate(CLASSES):
        y_bin = (y_true == i).astype(int)
        pr_auc[cls] = _round(average_precision_score(y_bin, proba[:, i]))
        per_class[cls] = {
            "precision": _round(per_class_tuples[0][i]),
            "recall": _round(per_class_tuples[1][i]),
            "f1": _round(per_class_tuples[2][i]),
            "support": int(per_class_tuples[3][i]),
        }

    cm = confusion_matrix(y_true, y_pred, labels=[0, 1, 2])
    high_recall = per_class["HIGH"]["recall"]

    print("=" * 60)
    print("EVALUATION - SYNTHETIC TEST SPLIT (held-out personnel)")
    print("=" * 60)
    print(f"accuracy           : {_round(acc)}")
    print(f"balanced accuracy  : {_round(bal_acc)}")
    print(f"macro F1           : {_round(macro_f1)}")
    print(f"weighted F1        : {_round(weighted_f1)}")
    print(f"PR-AUC (per class) : {pr_auc}")
    print()
    print("Per-class performance:")
    for cls in CLASSES:
        row = per_class[cls]
        print(
            f"  {cls:<6} precision={row['precision']:<7} recall={row['recall']:<7} "
            f"f1={row['f1']:<7} n={row['support']}"
        )
    print()
    print(f"*** HIGH-risk recall on synthetic test set: {_round(high_recall)} ***")
    print("    (critical for the welfare-monitoring prototype)")
    print()
    print(f"Confusion matrix (rows=actual {CLASSES}):")
    print("   " + "  ".join(f"{c:>6}" for c in CLASSES))
    for i, cls in enumerate(CLASSES):
        print(f"   {cls:<6}" + "  ".join(f"{int(v):>6}" for v in cm[i]))
    print()
    print("SYNTHETIC DATA ONLY - model is NOT validated for real deployment.")
    print("Real-data validation remains pending.")
    print("=" * 60)

    evaluation = {
        "model_version": train_config["model_version"],
        "dataset_version": ds["version"],
        "evaluated_at_utc": datetime.now(timezone.utc).isoformat(),
        "n_test_rows": int(len(X_test)),
        "n_test_personnel": int(test_df["personnel_key"].nunique()),
        "accuracy": _round(acc),
        "balanced_accuracy": _round(bal_acc),
        "macro_f1": _round(macro_f1),
        "weighted_f1": _round(weighted_f1),
        "per_class": per_class,
        "pr_auc": pr_auc,
        "high_risk_recall": _round(high_recall),
        "confusion_matrix": {
            "classes": CLASSES,
            "matrix": [[int(v) for v in row] for row in cm],
        },
    }
    write_json(artifact_dir / "evaluation.json", evaluation)

    metadata_path = artifact_dir / "metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    metadata["evaluation"] = evaluation
    metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    print(f"evaluation.json written -> {artifact_dir / 'evaluation.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())