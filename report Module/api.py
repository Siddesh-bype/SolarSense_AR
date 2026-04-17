"""
SolarSense AR - FastAPI Backend
Accepts dynamic report data as JSON, merges it with server-stored static
reference data (static_data.json), then invokes the existing
report_generator.generate_report() to produce a PDF.

Endpoints:
  GET  /                      - Health / info
  GET  /health                - Liveness probe
  GET  /static-data           - Returns the stored static reference data
  POST /generate-report       - Accepts dynamic JSON, returns PDF (streamed)
  POST /generate-report/json  - Same as above but returns JSON with file path
"""

import json
import os
import tempfile
import uuid
from datetime import datetime
from typing import Any, Dict

from fastapi import FastAPI, HTTPException, Body
from fastapi.responses import FileResponse, JSONResponse

from report_generator import generate_report


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DATA_PATH = os.path.join(BASE_DIR, "static_data.json")

# Vercel (and most serverless platforms) mount the deployment read-only;
# only the system temp dir is writable. Fall back to it when we can't write
# next to the source.
_default_output = os.path.join(BASE_DIR, "output")
if os.environ.get("VERCEL") or not os.access(BASE_DIR, os.W_OK):
    OUTPUT_DIR = os.path.join(tempfile.gettempdir(), "solarsense_output")
else:
    OUTPUT_DIR = _default_output
os.makedirs(OUTPUT_DIR, exist_ok=True)


app = FastAPI(
    title="SolarSense AR - Report API",
    description=(
        "Generates a professional PDF solar assessment report. Clients POST "
        "the dynamic user-specific payload; the server merges it with stored "
        "static reference data (provider comparison, PM Surya Ghar guide, "
        "assumptions, disclaimer, contact, metadata) and returns the PDF."
    ),
    version="1.0.0",
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def load_static_data() -> Dict[str, Any]:
    """Load the server-stored static reference data."""
    if not os.path.exists(STATIC_DATA_PATH):
        raise HTTPException(
            status_code=500,
            detail=f"Static data file not found: {STATIC_DATA_PATH}",
        )
    with open(STATIC_DATA_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


# Top-level keys that MUST be supplied in the dynamic payload
REQUIRED_DYNAMIC_KEYS = [
    "report_id",
    "timestamp",
    "user",
    "input_data",
    "solar_estimation",
    "energy_output",
    "financial_analysis",
    "savings",
    "roi_analysis",
    "environmental_impact",
    "visual_data",
]


def validate_dynamic_payload(payload: Dict[str, Any]) -> None:
    missing = [k for k in REQUIRED_DYNAMIC_KEYS if k not in payload]
    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Missing required keys in dynamic payload: {missing}",
        )


def merge_data(dynamic: Dict[str, Any], static: Dict[str, Any]) -> Dict[str, Any]:
    """
    Merge dynamic (per-request) data with static (server-stored) reference
    data into the single dict shape that report_generator expects.

    Dynamic keys win on collision (so a caller can override static defaults
    if they really need to).
    """
    merged: Dict[str, Any] = {}
    merged.update(static)
    merged.update(dynamic)
    return merged


def write_merged_json(merged: Dict[str, Any]) -> str:
    """Write merged dict to a temp JSON file and return its path.

    report_generator.generate_report() expects a file path, so we persist
    the merged document to a unique temporary file per request.
    """
    fd, path = tempfile.mkstemp(
        prefix="solarsense_req_",
        suffix=".json",
        dir=OUTPUT_DIR,
    )
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
    return path


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get("/")
def root():
    return {
        "service": "SolarSense AR - Report API",
        "version": "1.0.0",
        "endpoints": {
            "GET /health": "Liveness probe",
            "GET /static-data": "Inspect stored static reference data",
            "POST /generate-report": "Generate and download PDF (multipart)",
            "POST /generate-report/json": "Generate PDF, return JSON metadata",
        },
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "static_data_present": os.path.exists(STATIC_DATA_PATH),
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }


@app.get("/static-data")
def get_static_data():
    """Returns the server-stored static reference data (for inspection)."""
    return load_static_data()


@app.post("/generate-report")
def generate_report_endpoint(payload: Dict[str, Any] = Body(...)):
    """
    Accepts the dynamic per-user payload as JSON, merges with static data,
    produces the PDF, and streams it back.
    """
    validate_dynamic_payload(payload)

    static = load_static_data()
    merged = merge_data(payload, static)

    merged_path = write_merged_json(merged)

    report_id = payload.get("report_id") or f"REP{uuid.uuid4().hex[:8].upper()}"
    output_pdf = os.path.join(OUTPUT_DIR, f"SolarSense_Report_{report_id}.pdf")

    try:
        generate_report(merged_path, output_pdf)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Report generation failed: {exc}",
        )
    finally:
        # Keep the merged JSON for debugging if generation failed; otherwise clean up.
        if os.path.exists(output_pdf) and os.path.exists(merged_path):
            try:
                os.remove(merged_path)
            except OSError:
                pass

    if not os.path.exists(output_pdf):
        raise HTTPException(status_code=500, detail="PDF was not created.")

    return FileResponse(
        output_pdf,
        media_type="application/pdf",
        filename=os.path.basename(output_pdf),
    )


@app.post("/generate-report/json")
def generate_report_json_endpoint(payload: Dict[str, Any] = Body(...)):
    """
    Same as /generate-report but returns a JSON response containing the
    path to the generated PDF instead of streaming the file.
    Useful when the client prefers to fetch the PDF separately or when
    the PDF lives on shared storage.
    """
    validate_dynamic_payload(payload)

    static = load_static_data()
    merged = merge_data(payload, static)

    merged_path = write_merged_json(merged)

    report_id = payload.get("report_id") or f"REP{uuid.uuid4().hex[:8].upper()}"
    output_pdf = os.path.join(OUTPUT_DIR, f"SolarSense_Report_{report_id}.pdf")

    try:
        generate_report(merged_path, output_pdf)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Report generation failed: {exc}",
        )
    finally:
        if os.path.exists(output_pdf) and os.path.exists(merged_path):
            try:
                os.remove(merged_path)
            except OSError:
                pass

    return JSONResponse(
        {
            "status": "ok",
            "report_id": report_id,
            "pdf_path": output_pdf,
            "pdf_filename": os.path.basename(output_pdf),
        }
    )


# ---------------------------------------------------------------------------
# Local dev entry point: `python api.py`
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)
