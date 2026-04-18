# SolarSense AR ☀️📸

SolarSense AR is a state-of-the-art Flutter mobile application that leverages Augmented Reality (AR) and Machine Learning (ML) to perform on-device rooftop solar assessments. 

With SolarSense, you can perform an AR rooftop scan, determine exact solar capacity, estimate financial savings based on regional government schemes (like PM Surya Ghar), and generate a detailed, completely offline PDF report — all from your mobile phone! 

## 🌟 Key Features

*   **AR Rooftop Scanning**: Measure your available roof area in real-time using AR point plotting. 
*   **Machine Learning Obstacle Detection**: Integrates an edge-deployed YOLOv8 model (`tflite_flutter`) to detect rooftop obstacles (like water tanks, AC units) and calculate shading losses.
*   **100% On-Device Processing**: The core flow requires zero server dependency, protecting user data and ensuring high speed.
*   **PVGIS Integration**: Optional network connections to PVGIS for precise solar irradiance and energy yield forecasts based on the user's geocoordinates.
*   **Comprehensive Financial Analysis**: Includes integrated data on government subsidies (e.g., PM Surya Ghar Scheme) to calculate ROI, payback periods, and savings.
*   **Detailed PDF Report Generator**: Produces a rich, 16-section financial and technical PDF report right on the device using the `pdf` package.
*   **Hardware Agnostic**: Works effortlessly on standard Android (and iOS) devices.

## 🏗️ Technology Stack

*   **App Framework**: Flutter & Dart (`^3.10.4`)
*   **Object Detection (ML)**: TensorFlow Lite (`tflite_flutter`) with YOLOv8 nano model
*   **Geospatial & Irradiance**: `geolocator`, PVGIS API
*   **Local Data Parsing**: JSON serialization for brand and subsidy data
*   **PDF Generation**: `pdf` and `printing` packages
*   **Charts**: `fl_chart` for data visualization

## 📂 Project Structure

```text
├── assets/
│   ├── 3d_solar_panel/           # 3D models of solar panels (GLB)
│   ├── data/                     # Subsidies, brands, and static info JSONs
│   └── models/                   # Pre-compiled YOLOv8n TFLite model
├── lib/
│   ├── core/theme/               # Global standard UI theme specifications
│   ├── screens/                  # App views (Authentication, Home, AR Camera, Vendor, Profile)
│   └── services/                 # Core logic:
│       ├── scan_orchestrator.dart      # Manages the AR scan & evaluation pipeline
│       ├── pdf_report_generator.dart   # On-device 16-section financial PDF engine
│       ├── pvgis_service.dart          # Remote irradiance data fetcher
│       ├── obstacle_service.dart       # Computes shadow maps & available areas
│       └── subsidy_service.dart        # Regional subsidy calculations logic
├── report Module/                # [Optional] Python FastAPI backend for AI narratives.
└── pubspec.yaml                  # Project dependencies
```

## 🚀 Getting Started

### Prerequisites

*   Install [Flutter SDK](https://docs.flutter.dev/get-started/install)
*   Install Android Studio / Xcode for device emulation
*   A physical Android/iOS phone is recommended to test the AR camera and TFLite performance efficiently.

### Installation & Run

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/your-username/solarsense-ar.git
    cd solarsense-ar
    ```

2.  **Fetch Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the App**:
    ```bash
    flutter run
    ```

### Building for Release

To generate a highly optimized `APK` ready for deployment on Android:

```bash
flutter build apk --release
```

Install the output APK on your physical device, run through an interactive scan session, and hit **Download PDF Report** to view the on-device generated analytics result.

## ⚙️ How it Works under the Hood

1.  **Onboarding & Auth**: Standard entry flow, profile configuration.
2.  **Setup Scan**: The user specifies their location and inputs parameters like monthly electricity bill.
3.  **AR Session & YOLO**: The phone camera tracks the roof planes. Simultaneously, frames are piped to the YOLO TFLite model (`yolov8n.tflite`) to identify structures (obstacles) that might cast shadows. 
4.  **Math Engine (`scan_orchestrator`)**: Deducts obstacle areas from total AR-mapped area, fetches irradiance, calculates kW size, and outputs cost savings.
5.  **PDF Generation**: Results, UI summaries, graphical distributions, and PM Surya Ghar schematics are rendered natively into a viewable PDF buffer.

## 📝 License & Notes

*   **Offline Mode**: Ensure you have downloaded the required models and JSON assets. The app relies solely on internal databases unless the PVGIS endpoint is invoked.
*   **Report Module**: The `report Module/` folder contains a separate Python backend for extended capabilities (like querying OpenAI for dynamic narratives). It is strictly optional and not required by the main Flutter app.

---
*Built to empower faster, smarter, and independent solar energy transitions.*
