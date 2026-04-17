# SolarSense AR

Flutter app — AR rooftop scan → solar sizing → PDF report, **100% on-device**.
No backend, no server, no internet required for the core flow (PVGIS
irradiance is the one optional network call).

## Run it

```
flutter pub get
flutter run
```

Works on Android emulator and any physical Android phone — nothing to
configure. Build a release APK with:

```
flutter build apk --release
```

Install the APK → complete a scan → Report screen → **Download PDF Report**.
The PDF is generated on the device using the `pdf` package and saved to
the app's external-files directory, then opened in your default PDF viewer.

## Project layout

- `lib/` — Flutter app (AR camera, scan pipeline, PDF generator)
- `lib/services/pdf_report_generator.dart` — on-device 16-section PDF
- `lib/services/scan_orchestrator.dart` — on-device solar analysis
- `assets/data/report_static_data.json` — PM Surya Ghar guide, provider
  comparison, assumptions (bundled into the APK)
- `report Module/` — **optional** Python FastAPI backend (same logic as
  the on-device generator but with OpenAI-written narrative). Kept for
  reference / server-side deployments. Not required by the app.
