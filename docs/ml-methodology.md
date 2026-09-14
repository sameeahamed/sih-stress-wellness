# ml-methodology.md

Placeholder — intended final content: the training-side ML methodology.

Planned sections:
- Synthetic dataset generation (deterministic, seedable, distributions)
- Feature definitions and temporal windows (7d/30d duty, rest gaps,
  deployment duration, leave, wellness scales)
- Preprocessing and saved pipeline artifacts
- Chronological train/validation/test split and leak-prevention
- Class-imbalance handling (XGBoost class weights, optional SMOTE)
- XGBoost training configuration and hyperparameters
- Evaluation metrics and expected output (thresholds vs. metric curves)
- SHAP local + global explanation approach
- Model versioning / reproducibility (artifacts + metadata.json)
- Training ↔ inference parity rules