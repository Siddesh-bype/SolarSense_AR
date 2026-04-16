"""
FastAPI route: GET /irradiance

Returns solar irradiance data for a given GPS coordinate by calling the
European Commission PVGIS v5.2 REST API.

Flutter calls this endpoint with the device's GPS coordinates after the user
gives location permission, replacing the hardcoded 4.5 PSH in AreaModel.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from models.schemas import IrradianceResponse
from services.pvgis_service import fetch_irradiance

router = APIRouter(prefix="/irradiance", tags=["Irradiance"])


@router.get(
    "",
    response_model=IrradianceResponse,
    summary="Get solar irradiance for a GPS location",
    response_description="Annual & monthly irradiance data from PVGIS v5.2",
)
async def get_irradiance(
    lat: float = Query(
        ...,
        ge=-90,
        le=90,
        description="Latitude in decimal degrees (e.g. 18.52 for Pune)",
    ),
    lon: float = Query(
        ...,
        ge=-180,
        le=180,
        description="Longitude in decimal degrees (e.g. 73.85 for Pune)",
    ),
) -> IrradianceResponse:
    """
    Fetches real irradiance data from PVGIS for the given coordinates.

    - **lat**: Device GPS latitude
    - **lon**: Device GPS longitude
    - Returns annual peak sun hours, annual kWh per installed kWp,
      and a month-by-month irradiance breakdown.

    Use the returned `peak_sun_hours` to replace the hardcoded `4.5` in
    Flutter's `AreaModel.dailyEnergyKwh` getter.
    """
    try:
        result = await fetch_irradiance(lat=lat, lon=lon)
    except ValueError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return result
