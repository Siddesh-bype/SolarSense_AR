# SolarSense ☀️📸

<div align="center">

<a href="https://github.com/Siddesh-bype/SolarSense_AR">
  <img alt="SolarSense logo" src="https://raw.githubusercontent.com/Siddesh-bype/SolarSense_AR/main/assets/logo.png" width="96" />
</a>

<a href="https://github.com/Siddesh-bype/SolarSense_AR">
  <img alt="Animated SolarSense product summary" src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=22&pause=1200&color=0891B2&center=true&vCenter=true&width=640&lines=On-device+rooftop+solar+assessment;AR+spatial+mapping+%2B+YOLOv8+obstacle+AI;PVGIS+irradiance+%2B+PM+Surya+Ghar+subsidies;16-page+PDF+report+in+under+2+minutes" />
</a>

<br />

[![Flutter](https://img.shields.io/badge/app-Flutter-0891B2?style=flat-square)](https://flutter.dev/)
[![ARCore](https://img.shields.io/badge/AR-ARCore/depth-API-0F172A?style=flat-square)](https://developers.google.com/ar)
[![TensorFlow Lite](https://img.shields.io/badge/AI-YOLOv8n%20tflite-059669?style=flat-square)](https://www.tensorflow.org/lite)
[![PVGIS](https://img.shields.io/badge/data-EU+PVGIS-0891B2?style=flat-square)](https://jointsoltechnologies.com/pvgis/)
[![Subsidy](https://img.shields.io/badge/incentive-PM+Surya+Ghar-059669?style=flat-square)](https://www.pmindia.gov.in/en/news_updates/Solar+Lights)
[![License](https://img.shields.io/badge/status-active-0F172A?style=flat-square)](#development)

SolarSense turns your phone into an instant rooftop-solar assessor. Map a roof in
AR, let on-device YOLOv8 route around AC units and water tanks, pull real
irradiance from PVGIS, apply PM Surya Ghar subsidies, and export a 16-page PDF
report — **100 % on-device, no account or server needed.**

</div>

---

## Get the App

<p align="center">
  <a href="https://github.com/Siddesh-bype/SolarSense_AR/releases">
    <img src="https://img.shields.io/github/v/release/Siddesh-bype/SolarSense_AR?color=0891B2&label=latest+release&style=for-the-badge" alt="Latest release" />
  </a>
</p>

| Android (debug / release) |
| --- |
| Run a debug build instantly: `flutter run` · Ship a release APK: `flutter build apk --release` |

> **On a physical device:** ARCore, camera, and the TFLite model need real
> hardware. The emulator cannot render the AR surface or run inference. The
> release APK ships at `build/app/outputs/flutter-apk/app-release.apk`.

---

## What It Does

| Interview | Assessment | Recruiter workflow |
| --- | --- | --- |
| Maps the roof in real time with ARCore depth + plane detection | Computes True Usable Area after subtracting shaded/occupied footprint | Scores system size, subsidy, ROI and payback from your GPS coordinates |
| Routes panels around obstacles detected by YOLOv8n | Derives peak sun hours and annual kWh from PVGIS | Matches ALMM-approved brands to your kW size and price band |
| Lets you raise/tilt and hand-place modules | Applies PM Surya Ghar central + state subsidy slabs | Emits a 16-page on-device PDF with charts and checklists |

---

## Product Flow

<p align="center">
  <img src="https://raw.githubusercontent.com/Siddesh-bype/SolarSense_AR/main/docs/solarsense-flow.svg" alt="SolarSense product workflow: camera + motion → ARCore plane + depth → YOLOv8n obstacle AI → usable-area engine → PVGIS × PM Surya Ghar subsidies → 16-page PDF report" width="760" />
</p>

```text
Camera feed + motion
        |
        v
  ARCore plane + depth map
        |
        v
  YOLOv8n obstacle detection
        |
        v
  Usable-area × PVGIS irradiance × subsidy engine
        |
        v
  16-page on-device PDF report
```

---

## Stack

- **App:** Flutter 3, Dart — ARCore depth API, camera, TFLite inference
- **Renderer:** Native OpenGL ES 2.0 (`ARRenderer.kt`) + `GLSurfaceView`
- **AI:** `yolov8n.tflite` via `tflite_flutter`, NMS + IoU in Dart
- **Data:** PVGIS irradiance, local ALMM brands + state subsidies JSON
- **Reports:** `pdf` + `printing` + `fl_chart`, fully offline

---

## Quick Start

### Prerequisites
- Flutter SDK `>= 3.10.4` (Dart bundled)
- Android Studio cmdline tools + a **physical ARCore device**
- USB / wireless debugging enabled

### 1. Clone & fetch

```bash
git clone https://github.com/Siddesh-bype/SolarSense_AR.git
cd SolarSenseAR
flutter pub get
```

### 2. Android setup
No API keys are required — ARCore auto-installs Google Play Services for AR on
supported devices (the app degrades to manual roof-area entry otherwise; see
[`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)).
The on-device model is committed:
`assets/models/yolov8n.tflite`.

To regenerate it after a YOLOv8n retrain, see
[`tools/convert_yolo.md`](tools/convert_yolo.md) — the converter uses the
ONNX→TFLite path (Ultralytics' TFLite export is Linux/macOS only).

### 3. Run

```bash
flutter run            # debug on a connected device
flutter build apk --release   # production APK
```

---

## Native Bridge (channel API)

SolarSense's heavy lifting lives in Kotlin (`ARSceneManager` / `ARRenderer` /
`PanelGridCalculator`); Flutter drives it through `MethodChannel` + `EventChannel`.

| Method | Direction | Purpose |
| --- | --- | --- |
| `checkArAvailability` | Dart → Kotlin | Gating AR vs manual-entry overlay |
| `autoFillMixed` | Dart → Kotlin | Shelf-pack mixed module sizes across the plane |
| `applyObstacles` | Dart → Kotlin | Push YOLO boxes; native ray-casts keep-out zones |
| `setPanelHeight` / `setAllPanelHeight` | Dart → Kotlin | 0–12 m elevation control |
| `setPanelSize` / `configurePanelFlex` | Dart → Kotlin | Resize / re-orient a panel or the whole array |
| `addPanel` / `removePanel` | Dart → Kotlin | Per-panel add/remove |
| `selectPanelAt` / `movePanel` / `deletePanel` | Dart ←/→ Kotlin | Tap-select, drag, delete |
| `captureFrame` | Dart → Kotlin | JPEG snapshot of the current frame |
| `getScanSnapshot` | Kotlin → Dart | panelCount, systemKw, areaSqm, headingDeg |
| `eventSink` (HUD) | Kotlin → Dart | live panelCount, systemKw, selectedPanelId, tracking |

---

## Development

```bash
# Analyzer + formatters
flutter analyze
flutter format .

# Unit tests (pure Dart, no emulator)
flutter test

# Release build / R8 keep-rules: native ARCore classes are guarded in
# android/app/proguard-rules.pro; arsceneview is NOT a dependency.
flutter build apk --release
```

---

## Project Map

```text
SolarSenseAR/
  android/app/src/main/kotlin/com/example/solarmitra/
    ARRenderer.kt            OpenGL ES 2.0 camera + extruded-panel renderer
    ARSceneManager.kt        ARCore session, per-panel model, touch/drag, packMixed
    PanelGridCalculator.kt   mixed-size shelf packer + keep-out awareness
    MainActivity.kt          platform view + method/event channels
  lib/
    core/theme/               app_colors.dart, app_theme.dart (SolarMitra v2)
    models/                   enriched_scan_result.dart, obstacle_*.dart
    screens/
      scan/                   ar_camera_screen.dart, analysis_loading_screen.dart
      report/                 financial_report_screen.dart, PDF viewer
    services/                 scan_orchestrator.dart, subsidy_service.dart,
                              pvgis_service.dart, obstacle_service.dart,
                              brand_service.dart, pdf_report_generator.dart
    repositories/             Auth/Scan/Leads seams (on-device + backends)
  test/                       sun_path, monthly_profile, subsidy, obstacle IoU,
                              panel_packer (mixed packer math)
  assets/
    models/yolov8n.tflite     on-device obstacle detector
    data/                     solar_brands.json, state_subsidies.json, demo_obstacles.json
    3d_solar_panel/           GLB module asset for AR reference
tools/
  convert_yolo.py             PT -> ONNX -> TFLite pipeline
```

---

## Data & Privacy

**Your data stays yours.** The roof mapping, camera frame, obstacle detection,
irradiance, subsidies, and the 16-page PDF are all produced on-device. The only
network call is an optional HTTPS fetch to PVGIS (lat/lon only); when it fails the
app falls back to a regional irradiance estimate. No photos or metrics leave the
device, and `probeiq.db`–style persistence is avoided — nothing is written to a
server.

Do not commit `.env` or local device logs.

---

<div align="center">

*Built for homeowners and solar pros who want a real feasibility number before
the site visit — not a brochure.*

</div>
