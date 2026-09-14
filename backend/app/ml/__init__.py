"""Inference-side ML integration hosted inside the FastAPI application.

This package loads the trained artifacts through the shared training-side
helpers (``ml.model_io`` / ``ml.features``) so the runtime feature vector and
model loading code are never duplicated. Only domain mapping (assessment +
duty data -> raw model features) and SHAP factor phrasing live here.
"""