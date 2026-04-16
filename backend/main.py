"""
SolarSense AR — FastAPI Backend
================================
Endpoints:
  GET  /irradiance          → PVGIS solar irradiance for GPS coordinates
  POST /detect-obstacles    → YOLOv8 rooftop obstacle detection
  POST /subsidy-calc        → PM Surya Ghar subsidy + state top-up calculator
  POST /enrich-scan         → Enriched scan export (combines all of the above)

Run locally:
  cd backend
  pip install -r requirements.txt
  cp .env.example .env
  uvicorn main:app --reload --host 0.0.0.0 --port 8000

Expose via ngrok (for Flutter):
  ngrok http 8000
"""

from __future__ import annotations

import os

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()  # load .env before importing routes (routes read env vars at import time)

from api.routes import irradiance, obstacles, subsidy, scan_export  # noqa: E402

# ── App instance ──────────────────────────────────────────────────────────────

app = FastAPI(
    title="SolarSense AR — AI Backend",
    description=(
        "AI backend for SolarSense AR: rooftop obstacle detection (YOLOv8), "
        "solar irradiance data (PVGIS), PM Surya Ghar subsidy calculator, "
        "and enriched scan export for the Flutter AR frontend."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allow all origins for hackathon demo. Restrict in production.
_cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins if _cors_origins != ["*"] else ["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(irradiance.router)
app.include_router(obstacles.router)
app.include_router(subsidy.router)
app.include_router(scan_export.router)


# ── Health check ──────────────────────────────────────────────────────────────

@app.get("/", tags=["Health"], summary="Health check")
async def root() -> dict[str, str]:
    return {"status": "ok", "service": "SolarSense AR Backend v1.0.0"}


@app.get("/health", tags=["Health"], summary="Health check")
async def health() -> dict[str, str]:
    return {"status": "ok"}


# ── Dev entry point ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
        reload=True,
    )
