# SolarSense AR — Demo Runbook

A practical, judge-facing script for live demos and rehearsal. The app is
**fully on-device** except an optional PVGIS irradiance lookup, which falls back
to a regional estimate offline.

## Prerequisites
- Flutter SDK `>= 3.10.4`, Android toolchain, a physical Android device
  (ARCore does not work on emulators).
- `flutter pub get` then `flutter run` (or `flutter build apk --release`).

## The 5-minute demo flow
1. **Setup** (`/scan/setup`): pick a state (e.g. *Maharashtra*), enter a monthly
   bill (₹2,000), choose roof type *Flat*.
2. **AR scan** (`/scan/ar`): point at a flat surface, drop 4 corner anchors,
   tap **DETECT** to capture a frame for obstacle detection, then **CAPTURE**.
3. **Analysis** (loading screen): PVGIS + obstacle AI run concurrently; watch the
   four-step progress.
4. **Report** (`/report`): 16-section PDF with a latitude-aware monthly curve,
   embedded AR snapshot, obstacle/shading section, subsidy math, and provider
   comparison. Tap **Download PDF** to save/share.
5. **Vendors** (`/vendors`): ALMM brand shortlist + "request vendors near me".

## Talking points (what's real vs. fallback)
- **Real:** ARCore spatial mapping, native GLES2 panel rendering with azimuth +
  depth occlusion, YOLOv8n on-device detection via `tflite_flutter`, PVGIS
  irradiance, PM Surya Ghar tiered subsidy, on-device PDF generation.
- **Graceful fallback:** if `yolov8n.tflite` is absent or inference fails, the
  app uses canned detections from `assets/data/demo_obstacles.json` and reports
  `ObstacleModelStatus.demoMode` — the pipeline and report stay fully visible.
- **Offline:** PVGIS failure triggers a regional PSH estimate; the demo never
  blanks out.

## If something looks wrong
- **Empty obstacle list on a real model:** frame too dark / no mapped COCO proxy
  class. Demo mode still shows water_tank / chimney / ac_unit.
- **Report shows "Estimated Data":** PVGIS was unreachable — expected offline.
- **Re-run:** the loading screen has a **Retry** button.

## Regenerating the model
See [`tools/convert_yolo.md`](tools/convert_yolo.md). One-liner:
`python tools/convert_yolo.py` → writes `assets/models/yolov8n.tflite` (FP32).
INT8 is the production target (needs calibration images).
