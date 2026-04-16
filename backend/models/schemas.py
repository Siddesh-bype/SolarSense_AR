"""
Pydantic v2 schemas for all SolarSense AR API request and response models.
All monetary values are in Indian Rupees (₹). All areas in m². All power in kW.
"""

from __future__ import annotations

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# ── Enums ─────────────────────────────────────────────────────────────────────

class PriceSensitivity(str, Enum):
    low = "low"          # cheapest system, prioritise cost
    medium = "medium"    # balance of cost and quality
    high = "high"        # premium efficiency, brand trust


class StateKey(str, Enum):
    """Normalised state keys that match data/state_subsidies.json."""
    maharashtra = "maharashtra"
    gujarat = "gujarat"
    karnataka = "karnataka"
    rajasthan = "rajasthan"
    tamil_nadu = "tamil_nadu"
    uttar_pradesh = "uttar_pradesh"


# ── PVGIS / Irradiance ────────────────────────────────────────────────────────

class MonthlyIrradiance(BaseModel):
    month: int = Field(..., ge=1, le=12)
    month_name: str
    daily_irradiation_kwh_m2: float = Field(..., description="Daily irradiation kWh/m²")
    peak_sun_hours: float = Field(..., description="Equivalent peak sun hours per day")


class IrradianceResponse(BaseModel):
    latitude: float
    longitude: float
    peak_sun_hours: float = Field(..., description="Annual average daily PSH")
    annual_kwh_per_kw: float = Field(..., description="Annual yield per installed kWp")
    monthly_breakdown: list[MonthlyIrradiance]
    data_source: str = "PVGIS v5.2 (EC JRC)"


# ── Obstacle Detection ────────────────────────────────────────────────────────

class ObstacleDetection(BaseModel):
    label: str = Field(..., description="Human-readable obstacle class")
    confidence: float = Field(..., ge=0.0, le=1.0)
    x: float = Field(..., ge=0.0, le=1.0, description="Bounding box centre X, normalised [0,1]")
    y: float = Field(..., ge=0.0, le=1.0, description="Bounding box centre Y, normalised [0,1]")
    w: float = Field(..., ge=0.0, le=1.0, description="Bounding box width, normalised [0,1]")
    h: float = Field(..., ge=0.0, le=1.0, description="Bounding box height, normalised [0,1]")
    coco_class: Optional[str] = Field(None, description="Original COCO class before remapping")


class ObstacleDetectionResponse(BaseModel):
    detections: list[ObstacleDetection]
    image_width: int
    image_height: int
    model: str
    note: str = (
        "Zero-shot COCO classes are remapped to rooftop labels. "
        "Replace model with fine-tuned weights for production accuracy."
    )


# ── Subsidy Calculator ────────────────────────────────────────────────────────

class SubsidyRequest(BaseModel):
    system_kw: float = Field(..., gt=0, le=100, description="Installed system capacity in kW")
    state: StateKey = Field(..., description="Indian state for additional state subsidy lookup")
    system_cost_inr: float = Field(
        ..., gt=0,
        description="Total installed cost (panels + inverter + mounting + installation + GST) in ₹"
    )
    annual_units_kwh: Optional[float] = Field(
        None, gt=0,
        description="Expected annual generation in kWh (used for payback calculation). "
                    "If not provided, estimated from system_kw × 4.5 PSH × 365."
    )
    electricity_tariff_inr_per_unit: Optional[float] = Field(
        None, gt=0,
        description="Local electricity tariff ₹/kWh. Falls back to state default if not provided."
    )

    @field_validator("system_kw")
    @classmethod
    def round_kw(cls, v: float) -> float:
        return round(v, 2)


class SubsidyBreakdown(BaseModel):
    central_subsidy_inr: int = Field(..., description="PM Surya Ghar CFA (fixed slab)")
    state_subsidy_inr: int = Field(..., description="Additional state government subsidy")
    total_subsidy_inr: int = Field(..., description="Central + State combined")
    net_cost_inr: float = Field(..., description="system_cost - total_subsidy (never < 0)")
    annual_savings_inr: float = Field(..., description="annual_units × tariff (₹ saved per year)")
    payback_years: float = Field(..., description="net_cost / annual_savings")
    state_display_name: str
    state_portal: str
    state_notes: str
    subsidy_cap_applied: bool = Field(
        ..., description="True when system > 3 kW and central subsidy was capped at ₹78,000"
    )


# ── Brand Recommendation ──────────────────────────────────────────────────────

class BrandRecommendation(BaseModel):
    rank: int
    id: str
    display_name: str
    website: str
    customer_care: str
    rating: float
    price_per_watt_min: int
    price_per_watt_max: int
    estimated_system_cost_min: int
    estimated_system_cost_max: int
    best_efficiency_pct: float
    panel_warranty_years: int
    almm_listed: bool
    strength: str
    best_for: str
    reason: str = Field(..., description="Why this brand was recommended for this user")


# ── Enriched Scan Export ──────────────────────────────────────────────────────

class ScanExportRequest(BaseModel):
    """
    Mirrors the Flutter exportScanData() JSON output plus location + preferences.
    Flutter AR controller exports: total_area, usable_area, panel_count, system_size_kw.
    """
    # From Flutter exportScanData()
    total_area: float = Field(..., gt=0, description="Total detected rooftop area m²")
    usable_area: float = Field(..., gt=0, description="Usable area after obstacles m²")
    panel_count: int = Field(..., gt=0)
    system_size_kw: float = Field(..., gt=0)

    # Location (for PVGIS call)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

    # Subsidy inputs
    state: StateKey
    system_cost_inr: float = Field(..., gt=0)

    # Preferences
    price_sensitivity: PriceSensitivity = PriceSensitivity.medium
    electricity_tariff_inr_per_unit: Optional[float] = Field(None, gt=0)


class EnrichedScanResponse(BaseModel):
    # Original scan data
    total_area_m2: float
    usable_area_m2: float
    panel_count: int
    system_size_kw: float

    # Real irradiance (replaces hardcoded 4.5 PSH)
    irradiance: IrradianceResponse
    actual_daily_kwh: float = Field(..., description="system_kw × real peak_sun_hours")
    actual_annual_kwh: float = Field(..., description="system_kw × annual_kwh_per_kw")

    # Subsidy
    subsidy: SubsidyBreakdown

    # Brand picks
    brand_recommendations: list[BrandRecommendation]
