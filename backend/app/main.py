from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import assessments, auth, duty_records, health
from app.core.config import settings

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "AI-Based Predictive Personnel Stress and Welfare Monitoring System "
        "for CAPFs and Uniformed Forces (SIH 2026 prototype)."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(assessments.router)
app.include_router(duty_records.router)