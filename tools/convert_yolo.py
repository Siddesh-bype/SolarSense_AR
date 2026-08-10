#!/usr/bin/env python3
"""
convert_yolo.py — Convert YOLOv8n (PyTorch) → TensorFlow Lite for on-device
rooftop-obstacle detection in SolarSense AR.

WHY THIS SCRIPT EXISTS
---------------------
The Dart app (`lib/services/obstacle_service.dart`) runs the model via
`tflite_flutter`. That requires a `.tflite` file at
`assets/models/yolov8n.tflite`. Ultralytics' built-in `yolo export
format=tflite` (LiteRT) only runs on Linux x86 / macOS — it refuses on
Windows. This script uses the Windows-safe path:

    yolov8n.pt  --(ultralytics)→  yolov8n.onnx  --(onnx2tf)→  yolov8n.tflite

USAGE
-----
    # Default: FP32 TFLite (maximally compatible with tflite_flutter)
    python tools/convert_yolo.py

    # INT8 (smaller + faster, needs a calibration image folder)
    python tools/convert_yolo.py --int8 --calib-dir data/calib_images

    # Custom paths
    python tools/convert_yolo.py --pt yolov8n.pt --out assets/models/yolov8n.tflite

OUTPUT LAYOUT
-------------
The TFLite model's detection head outputs shape [1, 84, 8400]
(class scores + box coords for 8400 anchors). `obstacle_service.dart`
decodes that layout directly.

INT8 NOTE
---------
INT8 requires a representative dataset (20–100 rooftop-ish images) for
calibration. Without it the export still works but accuracy drops. FP32
is the safe default and is what ships in the repo.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(cmd: list[str]) -> None:
    print("▶", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)


def export_onnx(pt_path: str, onnx_path: str, imgsz: int) -> None:
    from ultralytics import YOLO

    model = YOLO(pt_path)
    out = model.export(
        format="onnx",
        imgsz=imgsz,
        dynamic=False,
        simplify=True,
        device="cpu",
    )
    # ultralytics returns the export path; copy to the requested location.
    if out and out != onnx_path and os.path.abspath(out) != os.path.abspath(onnx_path):
        import shutil

        shutil.move(out, onnx_path)
    print(f"✓ ONNX written: {onnx_path}")


def convert_tflite(onnx_path: str, tflite_path: str, int8: bool, calib_dir: str | None) -> None:
    # onnx2tf imports are heavy; import lazily so `--help` stays cheap.
    import onnx2tf  # noqa: F401  (ensures the package is installed)

    import glob

    sm_dir = os.path.splitext(tflite_path)[0] + "_saved_model"
    cmd = [
        "onnx2tf",
        "-i", onnx_path,
        "-o", sm_dir,
        "-osd",  # output sequential data (cleaner shape)
    ]
    if int8:
        if not calib_dir or not os.path.isdir(calib_dir):
            raise SystemExit("INT8 requires --calib-dir with calibration images")
        cmd += ["-oiqt", "-qc", calib_dir]
    run(cmd)

    # onnx2tf writes inside <sm_dir>/ as <onnx_basename>_float32.tflite
    # (or _float16 / _int8). Pick the one matching the requested quantisation.
    suffix = "_int8" if int8 else "_float32"
    candidates = [
        os.path.join(sm_dir, f"*{suffix}.tflite"),
        os.path.join(sm_dir, "*_float32.tflite"),
        os.path.join(sm_dir, "*_float16.tflite"),
    ]
    src: str | None = None
    for pat in candidates:
        hits = sorted(glob.glob(pat))
        if hits:
            src = hits[0]
            break
    if src is None:
        raise SystemExit(f"Could not find exported .tflite in {sm_dir}")
    if os.path.abspath(src) != os.path.abspath(tflite_path):
        import shutil

        shutil.move(src, tflite_path)
    print(f"✓ TFLite written: {tflite_path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pt", default=os.path.join(REPO_ROOT, "yolov8n.pt"))
    ap.add_argument("--out", default=os.path.join(REPO_ROOT, "assets", "models", "yolov8n.tflite"))
    ap.add_argument("--imgsz", type=int, default=640)
    ap.add_argument("--int8", action="store_true", help="Quantize to INT8 (needs --calib-dir)")
    ap.add_argument("--calib-dir", default=None, help="Folder of calibration images for INT8")
    ap.add_argument("--skip-onnx", action="store_true",
                    help="Assume yolov8n.onnx already exists at repo root")
    args = ap.parse_args()

    onnx_path = os.path.join(REPO_ROOT, "yolov8n.onnx")
    os.makedirs(os.path.dirname(args.out), exist_ok=True)

    if not args.skip_onnx:
        export_onnx(args.pt, onnx_path, args.imgsz)
    elif not os.path.exists(onnx_path):
        raise SystemExit(f"--skip-onnx set but {onnx_path} not found")

    convert_tflite(onnx_path, args.out, args.int8, args.calib_dir)
    print("\nDone. The model is ready at:", args.out)
    print("Ensure assets/models/yolov8n.tflite is declared in pubspec.yaml (it is).")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print("Command failed:", e, file=sys.stderr)
        sys.exit(1)
