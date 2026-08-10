# Converting YOLOv8n → TFLite for On-Device Obstacle Detection

SolarSense AR detects rooftop obstacles (water tanks, AC units, chimneys, …)
with a YOLOv8n model running **entirely on-device** via `tflite_flutter`.
This document explains how to (re)produce the `assets/models/yolov8n.tflite`
artifact.

## Why not just `yolo export format=tflite`?

Ultralytics renamed the TFLite exporter to **LiteRT** and, as of 8.4.x,
the `litert`/`tflite` exporter **only runs on Linux x86 and macOS**:

```
AssertionError: LiteRT export only supported on Linux x86 and macOS
```

It also dropped FP16 (`half=True`) support for the TFLite format — only
INT8 or FP32 are allowed. On a Windows dev machine the official one-liner
fails. The Windows-safe route is:

```
yolov8n.pt  ──ultralytics──▶  yolov8n.onnx  ──onnx2tf──▶  yolov8n.tflite
```

## Prerequisites

```bash
# Python 3.10+ virtualenv (anywhere)
python -m venv .venv && source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install "ultralytics" "onnx>=1.12.0,<2.0.0" onnxruntime onnxslim onnx2tf
```

> `onnx2tf` pulls in TensorFlow, so the install is large (~hundreds of MB).

## Steps (Windows or any OS)

```bash
# 1. ONNX export (works everywhere ultralytics runs)
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='onnx', imgsz=640, dynamic=False, simplify=True)"

# 2. ONNX → TFLite (Windows-safe)
onnx2tf -i yolov8n.onnx -o yolov8n_saved_model -osd

# 3. Place the result where the app expects it
#    onnx2tf emits yolov8n_saved_model_float32.tflite
cp yolov8n_saved_model_float32.tflite assets/models/yolov8n.tflite
```

Or run the bundled helper, which does all three in one go:

```bash
python tools/convert_yolo.py                 # → FP32 assets/models/yolov8n.tflite
python tools/convert_yolo.py --int8 --calib-dir data/calib   # → INT8 (needs images)
```

## Output layout the Dart code expects

YOLOv8n's head emits `[1, 84, 8400]` after export (84 = 4 box coords +
80 COCO class scores; 8400 anchors). `lib/services/obstacle_service.dart`
reads `raw[4 + class][anchor]` and `raw[0..3][anchor]`. If a future export
reorders the axes to `[1, 8400, 84]`, adjust the indexing in `_runInference`.

## Quantization: FP32 vs INT8

| Format | Size | Speed | Requires calibration | Notes |
|--------|------|-------|----------------------|-------|
| **FP32** (default) | ~12 MB | slower | No | Maximally compatible with `tflite_flutter`. Ships in repo. |
| **INT8** | ~3 MB | faster | Yes (20–100 imgs) | Production target. Pass `--int8 --calib-dir`. |

If INT8 calibration images aren't available, FP32 is the safe choice — the
app still builds and runs; detection just uses more RAM/CPU.

## Fallback behaviour (so the demo never breaks)

`obstacle_service.dart` is defensive:

- If `assets/models/yolov8n.tflite` is **missing or < 1000 bytes** → loads
  canned detections from `assets/data/demo_obstacles.json` and reports
  `ObstacleModelStatus.demoMode`.
- If the model is present but inference throws (e.g. shape mismatch on a
  future export) → catches and returns an empty list; the UI still renders.

So the build **requires** the `.tflite` asset to exist (Flutter fails the
build otherwise), but a wrong-shaped model degrades gracefully rather than
crashing.
