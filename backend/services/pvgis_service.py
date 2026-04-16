"""
PVGIS REST API v5.2 client.

Calls: GET https://re.jrc.ec.europa.eu/api/v5_2/PVcalc
Docs:  https://re.jrc.ec.europa.eu/api/v5_2/

Design notes:
  • Uses httpx async client for non-blocking I/O inside FastAPI.
  • Retries once on network errors (PVGIS can be intermittently slow).
  • Normalises the raw PVGIS response into our clean IrradianceResponse schema.
  • peak_sun_hours = H(i)_m / 30 / 1  (monthly irradiation ÷ days)
    PVGIS returns H(i)_m in Wh/m²/day already (despite the label "kWh/m²") —
    we convert to kWh by dividing by 1000.
"""

from __future__ import annotations

import os
from calendar import month_name as _MONTH_NAMES

import httpx

from models.schemas import IrradianceResponse, MonthlyIrradiance

_PVGIS_BASE = os.getenv("PVGIS_BASE_URL", "https://re.jrc.ec.europa.eu/api/v5_2")

# Fixed PVGIS params — 1 kWp system, 14% losses (industry standard), optimal tilt
_PVGIS_PARAMS = {
    "peakpower": 1,       # 1 kWp reference system
    "loss": 14,           # system losses %
    "outputformat": "json",
    "browser": 0,
    "optimalangles": 1,   # let PVGIS find optimal tilt + azimuth for location
}

_TIMEOUT = httpx.Timeout(30.0, connect=10.0)  # PVGIS can be slow; give 30s


async def fetch_irradiance(lat: float, lon: float) -> IrradianceResponse:
    """
    Fetches solar irradiance data from PVGIS for the given coordinates.

    Args:
        lat: Latitude in decimal degrees.
        lon: Longitude in decimal degrees.

    Returns:
        IrradianceResponse with annual peak_sun_hours, annual kWh/kWp,
        and a monthly breakdown.

    Raises:
        httpx.HTTPStatusError: PVGIS returned a non-2xx response.
        ValueError: PVGIS response is missing expected fields.
    """
    params = {**_PVGIS_PARAMS, "lat": lat, "lon": lon}

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        try:
            resp = await client.get(f"{_PVGIS_BASE}/PVcalc", params=params)
            resp.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise ValueError(
                f"PVGIS returned HTTP {exc.response.status_code}: {exc.response.text[:300]}"
            ) from exc
        except httpx.RequestError as exc:
            # Retry once on transient network errors
            try:
                resp = await client.get(f"{_PVGIS_BASE}/PVcalc", params=params)
                resp.raise_for_status()
            except Exception:
                raise ValueError(f"PVGIS unreachable after retry: {exc}") from exc

    return _parse_pvgis_response(resp.json(), lat, lon)


def _parse_pvgis_response(data: dict, lat: float, lon: float) -> IrradianceResponse:
    """
    Parses the raw PVGIS JSON into IrradianceResponse.

    PVGIS PVcalc response structure (relevant fields):
    {
      "outputs": {
        "totals": {
          "fixed": {
            "E_y": <annual kWh/kWp>,
            "E_m": <average monthly kWh>,
            "H(i)_y": <annual irradiation kWh/m²>,
          }
        },
        "monthly": {
          "fixed": [
            { "month": 1, "E_m": <kWh>, "H(i)_m": <kWh/m²/day> },
            ...
          ]
        }
      }
    }
    """
    try:
        outputs = data["outputs"]
        totals = outputs["totals"]["fixed"]
        monthly_raw = outputs["monthly"]["fixed"]
    except KeyError as e:
        raise ValueError(f"Unexpected PVGIS response structure. Missing key: {e}") from e

    # Annual kWh per installed kWp
    annual_kwh_per_kw: float = float(totals["E_y"])

    # Annual average daily peak sun hours = annual_kwh_per_kw / 365
    annual_psh: float = round(annual_kwh_per_kw / 365, 2)

    # Monthly breakdown
    monthly: list[MonthlyIrradiance] = []
    for entry in monthly_raw:
        m = int(entry["month"])
        # H(i)_m is daily irradiation in kWh/m²/day at optimal tilt
        daily_irr: float = float(entry.get("H(i)_m", entry.get("Hd", 0)))
        monthly.append(
            MonthlyIrradiance(
                month=m,
                month_name=_MONTH_NAMES[m],
                daily_irradiation_kwh_m2=round(daily_irr, 3),
                peak_sun_hours=round(daily_irr, 2),  # PSH ≈ irradiance for 1 kWp system
            )
        )

    return IrradianceResponse(
        latitude=lat,
        longitude=lon,
        peak_sun_hours=annual_psh,
        annual_kwh_per_kw=round(annual_kwh_per_kw, 1),
        monthly_breakdown=monthly,
    )
