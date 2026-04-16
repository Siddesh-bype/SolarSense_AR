"""
FastAPI route: POST /enrich-scan

Master orchestrator: combines PVGIS irradiance, subsidy calculation, and brand
recommendations into a single enriched scan response for the Flutter report screen.

Data flow:
  ScanExportRequest (from Flutter AR screen)
      │
      ├─ PVGIS service → real peak sun hours & monthly breakdown
      │    └─ if PVGIS fails → fallback 4.5 PSH, pvgis_fallback=True
      │
      ├─ subsidy logic → PM Surya Ghar + state top-up (from subsidy.py logic)
      │
      └─ brand engine → top 3 sorted by price_sensitivity

All calls are async. The PVGIS call uses a 30s timeout (already configured in pvgis_service).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException

from api.routes.subsidy import (
    _central_subsidy,
    _recommend_brands,
    _state_subsidy,
    _STATE_DB,
)
from models.schemas import (
    EnrichedScanResponse,
    IrradianceResponse,
    MonthlyIrradiance,
    ScanExportRequest,
    SubsidyBreakdown,
)
from services.pvgis_service import fetch_irradiance

router = APIRouter(prefix="/enrich-scan", tags=["Enriched Scan Export"])

# ── PVGIS fallback constant ───────────────────────────────────────────────────
_FALLBACK_PSH = 4.5  # generic India average PSH when PVGIS is unreachable
_FALLBACK_ANNUAL_KWH_PER_KW = _FALLBACK_PSH * 365  # ≈ 1642 kWh/kWp


def _build_fallback_irradiance(lat: float, lon: float) -> IrradianceResponse:
    """Returns a static fallback IrradianceResponse using 4.5 PSH."""
    return IrradianceResponse(
        latitude=lat,
        longitude=lon,
        peak_sun_hours=_FALLBACK_PSH,
        annual_kwh_per_kw=round(_FALLBACK_ANNUAL_KWH_PER_KW, 1),
        monthly_breakdown=[
            MonthlyIrradiance(
                month=m,
                month_name=[
                    "", "January", "February", "March", "April", "May", "June",
                    "July", "August", "September", "October", "November", "December"
                ][m],
                daily_irradiation_kwh_m2=_FALLBACK_PSH,
                peak_sun_hours=_FALLBACK_PSH,
            )
            for m in range(1, 13)
        ],
        data_source="Fallback (PVGIS unavailable) — India average 4.5 PSH",
    )


# ── Route ─────────────────────────────────────────────────────────────────────

@router.post(
    "",
    response_model=EnrichedScanResponse,
    summary="Enrich AR scan data with irradiance, subsidy, and brand recommendations",
    response_description="Complete solar assessment combining PVGIS + subsidy + brand picks",
)
async def enrich_scan(req: ScanExportRequest) -> EnrichedScanResponse:
    """
    Single endpoint that Flutter calls after the AR scan.
    Returns everything needed to render the financial report screen.

    - `pvgis_fallback` flag (in data_source field) is set if PVGIS is unreachable.
    - Brand recommendations are sorted by the user's price_sensitivity preference.
    """
    # ── 1. PVGIS irradiance (async, with fallback) ────────────────────────────
    pvgis_fallback = False
    try:
        irradiance = await fetch_irradiance(lat=req.latitude, lon=req.longitude)
    except Exception:
        irradiance = _build_fallback_irradiance(req.latitude, req.longitude)
        pvgis_fallback = True

    # ── 2. Energy generation estimates ───────────────────────────────────────
    actual_daily_kwh = round(req.system_size_kw * irradiance.peak_sun_hours, 2)
    actual_annual_kwh = round(req.system_size_kw * irradiance.annual_kwh_per_kw, 1)

    # ── 3. Subsidy calculation ────────────────────────────────────────────────
    state_key = req.state.value
    state_data = _STATE_DB.get(state_key, {})

    central, cap_applied = _central_subsidy(req.system_size_kw)
    state_top_up = _state_subsidy(state_key, req.system_size_kw)
    total_subsidy = central + state_top_up
    net_cost = max(0.0, req.system_cost_inr - total_subsidy)

    tariff = req.electricity_tariff_inr_per_unit or state_data.get("avg_tariff_per_unit", 7.0)
    annual_savings = round(actual_annual_kwh * tariff, 2)
    payback_years = round(net_cost / annual_savings, 2) if annual_savings > 0 else 0.0

    subsidy = SubsidyBreakdown(
        central_subsidy_inr=central,
        state_subsidy_inr=state_top_up,
        total_subsidy_inr=total_subsidy,
        net_cost_inr=net_cost,
        annual_savings_inr=annual_savings,
        payback_years=payback_years,
        state_display_name=state_data.get("display_name", state_key.title()),
        state_portal=state_data.get("portal", "pmsuryaghar.gov.in"),
        state_notes=state_data.get("notes", ""),
        subsidy_cap_applied=cap_applied,
    )

    # ── 4. Brand recommendations ──────────────────────────────────────────────
    brands = _recommend_brands(
        system_kw=req.system_size_kw,
        price_sensitivity=req.price_sensitivity,
        top_n=3,
    )

    # ── 5. Assemble response ──────────────────────────────────────────────────
    return EnrichedScanResponse(
        total_area_m2=req.total_area,
        usable_area_m2=req.usable_area,
        panel_count=req.panel_count,
        system_size_kw=req.system_size_kw,
        irradiance=irradiance,
        actual_daily_kwh=actual_daily_kwh,
        actual_annual_kwh=actual_annual_kwh,
        subsidy=subsidy,
        brand_recommendations=brands,
    )
