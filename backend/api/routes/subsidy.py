"""
FastAPI route: POST /subsidy-calc

Computes PM Surya Ghar subsidy + state top-up + sorted brand recommendations.
Subsidy slab logic (central):
  ≤ 1 kW  → ₹30,000
  ≤ 2 kW  → ₹60,000
  ≥ 3 kW+ → ₹78,000 (hard cap, MNRE max)

Brand recommendations are sorted by value score for the given price sensitivity.
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException

from models.schemas import (
    BrandRecommendation,
    PriceSensitivity,
    SubsidyBreakdown,
    SubsidyRequest,
)

router = APIRouter(prefix="/subsidy-calc", tags=["Subsidy Calculator"])

# ── Static data files ─────────────────────────────────────────────────────────
_DATA_DIR = Path(__file__).parent.parent.parent / "data"

with open(_DATA_DIR / "state_subsidies.json", encoding="utf-8") as _f:
    _STATE_DB: dict[str, Any] = json.load(_f)

with open(_DATA_DIR / "solar_brands.json", encoding="utf-8") as _f:
    _BRANDS: list[dict[str, Any]] = json.load(_f)


# ── Central subsidy slab (PM Surya Ghar CFA) ─────────────────────────────────

def _central_subsidy(system_kw: float) -> tuple[int, bool]:
    """
    Returns (central_subsidy_inr, cap_applied).
    Slab:  ≤1 kW → ₹30,000 | 1–2 kW → ₹60,000 | ≥3 kW → ₹78,000 (capped)
    """
    if system_kw <= 1.0:
        return 30_000, False
    if system_kw <= 2.0:
        return 60_000, False
    # 3 kW and above: full ₹78,000 regardless of system size
    return 78_000, system_kw > 3.0


def _state_subsidy(state_key: str, system_kw: float) -> int:
    """
    Looks up additional state subsidy from state_subsidies.json.
    Handles three variants:
      1. additional_subsidy_flat   — fixed flat amount
      2. additional_subsidy_per_kw — per-kW amount (capped at max_kw_for_state_subsidy if set)
      3. 0                         — no additional state support
    """
    state = _STATE_DB.get(state_key, {})
    per_kw: int = state.get("additional_subsidy_per_kw", 0)
    flat: int = state.get("additional_subsidy_flat", 0)

    if per_kw > 0:
        max_kw_cap: float = state.get("max_kw_for_state_subsidy", system_kw)
        effective_kw = min(system_kw, max_kw_cap)
        return int(per_kw * effective_kw)

    if flat > 0:
        max_kw_cap_for_flat: float = state.get("max_kw_for_state_subsidy", system_kw)
        if system_kw >= max_kw_cap_for_flat or max_kw_cap_for_flat == system_kw:
            return flat
        return flat  # flat amount is always awarded when any size qualifies

    return 0


# ── Brand recommendation engine ───────────────────────────────────────────────

_TIER_PRICE_MAP: dict[str, PriceSensitivity] = {
    "low": PriceSensitivity.low,
    "medium": PriceSensitivity.medium,
    "high": PriceSensitivity.high,
}


def _recommend_brands(
    system_kw: float,
    price_sensitivity: PriceSensitivity,
    top_n: int = 3,
) -> list[BrandRecommendation]:
    """
    Sorts brands by a value score tuned to price_sensitivity:
      - low  (budget): weight cheapest price/watt more
      - high (premium): weight efficiency and rating more
      - medium: balanced
    Returns top_n brands.
    """

    def _score(brand: dict[str, Any]) -> float:
        avg_ppw = (brand["price_per_watt_min"] + brand["price_per_watt_max"]) / 2
        efficiency = brand["best_efficiency_pct"]
        rating = brand["rating"]
        warranty = brand["panel_warranty_years"]

        if price_sensitivity == PriceSensitivity.low:
            # Penalise high price, reward efficiency slightly
            return -avg_ppw * 2 + efficiency * 0.5 + rating * 0.3
        if price_sensitivity == PriceSensitivity.high:
            # Reward efficiency, rating, warranty; price secondary
            return efficiency * 2 + rating * 1.5 + warranty * 0.1 - avg_ppw * 0.5
        # Medium: balanced score
        return -avg_ppw + efficiency * 1.0 + rating * 1.0 + warranty * 0.05

    sorted_brands = sorted(_BRANDS, key=_score, reverse=True)[:top_n]

    # Estimate actual system cost for the requested kW (scale from 3kW baseline)
    kw_scale = system_kw / 3.0

    recommendations: list[BrandRecommendation] = []
    for rank, brand in enumerate(sorted_brands, start=1):
        est_min = int(brand["system_cost_3kw_min"] * kw_scale)
        est_max = int(brand["system_cost_3kw_max"] * kw_scale)

        reason = _build_reason(brand, price_sensitivity)

        recommendations.append(
            BrandRecommendation(
                rank=rank,
                id=brand["id"],
                display_name=brand["display_name"],
                website=brand["website"],
                customer_care=brand["customer_care"],
                rating=brand["rating"],
                price_per_watt_min=brand["price_per_watt_min"],
                price_per_watt_max=brand["price_per_watt_max"],
                estimated_system_cost_min=est_min,
                estimated_system_cost_max=est_max,
                best_efficiency_pct=brand["best_efficiency_pct"],
                panel_warranty_years=brand["panel_warranty_years"],
                almm_listed=brand["almm_listed"],
                strength=brand["strength"],
                best_for=brand["best_for"],
                reason=reason,
            )
        )
    return recommendations


def _build_reason(brand: dict[str, Any], sensitivity: PriceSensitivity) -> str:
    if sensitivity == PriceSensitivity.low:
        return (
            f"Best value pick — starts at ₹{brand['price_per_watt_min']}/W "
            f"with {brand['best_efficiency_pct']}% efficiency. ALMM-listed, qualifies for subsidy."
        )
    if sensitivity == PriceSensitivity.high:
        return (
            f"Premium choice — {brand['best_efficiency_pct']}% efficiency, "
            f"{brand['panel_warranty_years']}-year warranty. Rated {brand['rating']}/10."
        )
    return (
        f"Balanced recommendation — {brand['rating']}/10 rated, ALMM-listed, "
        f"₹{brand['price_per_watt_min']}–₹{brand['price_per_watt_max']}/W."
    )


# ── Route ─────────────────────────────────────────────────────────────────────

@router.post(
    "",
    response_model=SubsidyBreakdown,
    summary="Calculate PM Surya Ghar subsidy + state top-up",
    response_description="Full subsidy breakdown with payback and brand recommendations",
)
async def calculate_subsidy(req: SubsidyRequest) -> SubsidyBreakdown:
    """
    Computes:
    - Central subsidy (PM Surya Ghar slab: ₹30k / ₹60k / ₹78k)
    - State additional subsidy (from state_subsidies.json)
    - Net cost after all subsidies
    - Annual savings and payback period
    """
    state_key = req.state.value
    state_data = _STATE_DB.get(state_key, {})

    # 1. Central subsidy
    central, cap_applied = _central_subsidy(req.system_kw)

    # 2. State top-up
    state_top_up = _state_subsidy(state_key, req.system_kw)

    total_subsidy = central + state_top_up
    net_cost = max(0.0, req.system_cost_inr - total_subsidy)

    # 3. Annual generation estimate (if not provided)
    annual_kwh = req.annual_units_kwh or (req.system_kw * 4.5 * 365)

    # 4. Tariff (state default fallback if not provided)
    tariff = req.electricity_tariff_inr_per_unit or state_data.get("avg_tariff_per_unit", 7.0)

    annual_savings = round(annual_kwh * tariff, 2)
    payback_years = round(net_cost / annual_savings, 2) if annual_savings > 0 else 0.0

    return SubsidyBreakdown(
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
