# SolarMitra ☀️📸

**SolarMitra** is a cutting-edge Flutter mobile application designed to democratize and simplify rooftop solar assessments. By leveraging Augmented Reality (AR) spatial mapping and Machine Learning (ML) object detection, SolarMitra provides users with an instant, hyper-accurate, and 100% on-device solar feasibility report.

Gone are the days of waiting for physical site visits. With SolarMitra, users can map their rooftop, identify obstacles, calculate solar potential, estimate subsidies, and generate a professional-grade PDF report—all from their smartphone in under 2 minutes.

---

## 🌟 Comprehensive Feature Set

### 1. AR Rooftop Spatial Mapping
Instead of estimating roof size or looking up satellite imagery, SolarMitra uses the device's native AR capabilities (ARCore/ARKit) to map the roof in real-time. Users drop virtual anchor points at the corners of their roof to instantly calculate the total spatial area in square meters.

### 2. Edge-AI Obstacle Detection (YOLOv8)
Roofs aren't always empty. Water tanks, HVAC units, and satellite dishes cause shading. The app runs a lightweight **YOLOv8 Nano (`yolov8n.tflite`)** object detection model directly on the camera feed using `tflite_flutter`. It automatically identifies these obstacles, computes their bounding boxes, and deducts the shaded area to calculate the *True Usable Area*.

### 3. PVGIS Irradiance Integration
The app fetches precise localized solar irradiance data (Peak Sun Hours, expected Annual kWh/kW yield) by interfacing with the European Commission's **PVGIS API** based on the phone's exact GPS coordinates (`geolocator`). 

### 4. PM Surya Ghar Muft Bijli Yojana Engine
Built specifically for the Indian market, SolarMitra incorporates the latest slab-based subsidy logic from the **PM Surya Ghar** scheme:
- Central Financial Assistance up to ₹78,000 for 3kW systems.
- State-specific auxiliary subsidy multipliers (e.g., Gujarat, UP, Karnataka).
- Net cost, ROI, and Payback period calculators based on regional tariffs.

### 5. On-Device 16-Section PDF Generator
Using the Dart `pdf` and `printing` packages, the app generates a highly detailed, natively drawn PDF report. **No backend servers or cloud generators (like Python's ReportLab) are required.** The PDF includes:
- Executive summaries and system designs.
- Auto-generated Cashflow & Generation charts (`fl_chart` data rasterized to PDF).
- PM Surya Ghar Guides and Application Checklist.
- Environmental Impact (Carbon offset equivalent).

### 6. Provider & ALMM Brand Matching
SolarMitra features an integrated database of ALMM-approved Tier-1 solar manufacturers (e.g., Tata Power Solar, Adani Solar, Waaree, Vikram Solar). It recommends the best brands based on the user's calculated kW size and price sensitivity.

---

## 🏗️ Technical Architecture & Pipeline

SolarMitra relies on a localized **Orchestration Pipeline** (`ScanOrchestrator`) that manages asynchronous tasks to deliver results instantly:

1. **Concurrent Fetching**:
   - As the AR scan completes, `PvgisService` fires an HTTP request to get irradiance data.
   - Simultaneously, `ObstacleService` runs the TFLite inference over the captured camera frame.
2. **Synchronous Math calculations**:
   - `annualKwh` and `systemKw` are calculated based on the net *Usable Area* and panel dimensions (e.g., Mono PERC 540W variants).
   - `SubsidyService` executes the PM Surya Ghar bracket logic (Central + State formulas).
   - `BrandService` queries the local JSON dataset to filter ALMM-compliant vendors.
3. **Data Hydration**:
   - The resulting `EnrichedScanResult` data class is passed directly to the `PdfReportGenerator` or the UI dashboards.

---

## 📂 Deep Dive: Project Structure

```text
├── assets/
│   ├── 3d_solar_panel/           # 3D models (GLB) for AR visualization 
│   ├── data/                     # Offline databases (solar_brands.json, state_subsidies.json)
│   └── models/                   # yolov8n.tflite (YOLOv8 Nano object detection model)
├── lib/
│   ├── core/theme/               # Centralized theming, typography, and color palettes
│   ├── models/                   # Dart data classes (EnrichedScanResult, Report context)
│   ├── screens/                  
│   │   ├── auth/                 # Login and profile config
│   │   ├── scan/                 # setup_scan_screen.dart & ar_camera_screen.dart
│   │   └── report/               # Financial dashboards and PDF viewer
│   └── services/                 # The Brains:
│       ├── scan_orchestrator.dart      # Concurrency manager for scans
│       ├── pdf_report_generator.dart   # 1400+ line vector PDF generator
│       ├── pvgis_service.dart          # Remote irradiance data fetcher
│       ├── obstacle_service.dart       # TFLite inferences & Shadow Area math
│       ├── brand_service.dart          # Recommend ALMM brands by price bracket
│       └── subsidy_service.dart        # State/Central PM Surya Ghar computations
├── report Module/                # [Optional] Python FastAPI AI generation backend
└── pubspec.yaml                  # Project dependencies
```

---

## 🚀 Getting Started & Installation

### Prerequisites

*   Install **Flutter SDK** (`>= 3.10.4`) and ensure Dart is updated.
*   Install Android Studio (for Android toolchain) or Xcode (for iOS toolchain).
*   **Important**: Because this app heavily relies on Camera feeds, TFLite inferences, and ARCore/ARKit, **testing on a physical device is strongly recommended.**

### 1. Clone the Repository
```bash
git clone https://github.com/Siddesh-bype/SolarMitra.git
cd SolarMitra
```

### 2. Fetch Dependencies
The project uses `tflite_flutter`, `pdf`, `fl_chart`, and `geolocator` among others. 
```bash
flutter pub get
```

### 3. Setup Android API Keys (If needed)
Ensure you have the required capabilities enabled in `android/app/src/main/AndroidManifest.xml` (e.g., Camera permissions, Internet access, ARCore metadata).

### 4. Run the Application
Connect your physical device via USB debugging or Wireless debugging.
```bash
flutter run
```

### 5. Build for Release (Production)
To evaluate the true performance of the TFLite models and the PDF generator, compile the app in release mode:
```bash
flutter build apk --release
```
The output APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📝 Subsidies & Brand Data (Context)

SolarMitra uses localized data curated for the Indian solar market of 2026.
*   **ALMM Compliance**: The app logic specifically prioritizes Approved List of Models and Manufacturers (ALMM) since only these panels qualify for the central subsidy.
*   **Brands Integrated**: Tata Power Solar, Adani Solar, Waaree Energies, Vikram Solar, Luminous, Havells, and Loom Solar.
*   **Subsidy Math**: For 2026, the PM Surya Ghar scheme offers ₹30,000 for 1kW, ₹60,000 for 2kW, and caps at ₹78,000 for 3kW or larger. SolarMitra automatically brackets user capacities to display the precise out-of-pocket costs.

---

## 🔒 Privacy & Offline Capability

**Your data stays yours.** 
Aside from the initial query to PVGIS for regional sun-hours (using your lat/lon), the entire application runs natively on the edge. The Roof mapping, the Machine Learning detection, the subsidy calculations, and the intensive 16-page PDF compilation all occur within the phone's memory. No photographs or metrics are sent to a persistent server.

---

*“SolarMitra: Built to empower faster, smarter, and independent solar energy transitions.”*
