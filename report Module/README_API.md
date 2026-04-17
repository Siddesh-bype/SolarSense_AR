# SolarSense AR - Report API

FastAPI wrapper around the existing `report_generator.py`. Data is split into
two JSON sources:

| File | Owner | Purpose |
|---|---|---|
| `static_data.json` | Server (checked into repo) | Provider comparison, PM Surya Ghar guide, assumptions, disclaimer, contact, report metadata |
| API POST body | Caller (per-request) | `report_id`, `timestamp`, `user`, `input_data`, `solar_estimation`, `energy_output`, `financial_analysis`, `savings`, `roi_analysis`, `environmental_impact`, `visual_data` |

See [`dynamic_data_sample.json`](dynamic_data_sample.json) for a ready-to-send payload.

## Install

```bash
pip install -r requirements.txt
```

## Run

```bash
python api.py
# or
uvicorn api:app --reload --host 0.0.0.0 --port 8000
```

Open http://localhost:8000/docs for interactive Swagger UI.

## Endpoints

- `GET /` — service info
- `GET /health` — liveness
- `GET /static-data` — returns stored static reference data
- `POST /generate-report` — accepts dynamic JSON body, returns PDF file
- `POST /generate-report/json` — accepts dynamic JSON body, returns JSON metadata with PDF path

## Example

```bash
curl -X POST http://localhost:8000/generate-report \
  -H "Content-Type: application/json" \
  -d @dynamic_data_sample.json \
  --output report.pdf
```

## How it works

1. Client POSTs dynamic JSON payload.
2. API validates required top-level keys.
3. Server loads `static_data.json`.
4. The two dicts are merged (dynamic overrides static on key collision).
5. Merged dict is written to a temp file under `output/`.
6. The existing `report_generator.generate_report(path, output)` is called unchanged.
7. The resulting PDF is streamed back (or its path returned as JSON).

`report_generator.py` and `ai_content.py` are **not modified** — the API is a thin orchestration layer on top.
