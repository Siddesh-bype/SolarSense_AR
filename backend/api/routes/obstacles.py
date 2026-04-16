"""
FastAPI route: POST /detect-obstacles

Detects obstacles on a rooftop image using YOLOv8n (COCO zero-shot for demo).
Accepts a multipart JPEG frame from the Flutter camera.

COCO class remap → rooftop labels (demo stand-ins):
  bottle, cup       → water_tank
  refrigerator      → ac_unit
  chair, bench      → furniture
  potted plant      → rooftop_equipment
  tv, laptop        → rooftop_equipment

Replace _ROOFTOP_CLASSES and swap the model weights (YOLO_MODEL_PATH in .env)
with a fine-tuned rooftop model before production.

Returns:
  - If model runs successfully: list of ObstacleDetection in normalised [0,1] coords
  - If model is unavailable or fails: empty list + note (never crashes the app)
"""

from __future__ import annotations

import io
import os
from typing import Optional

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image

from models.schemas import ObstacleDetection, ObstacleDetectionResponse

router = APIRouter(prefix="/detect-obstacles", tags=["Obstacle Detection"])

# ── YOLO model (lazy-loaded once) ─────────────────────────────────────────────
_yolo_model = None
_YOLO_MODEL_PATH: str = os.getenv("YOLO_MODEL_PATH", "yolov8n.pt")
_CONF_THRESHOLD: float = float(os.getenv("YOLO_CONF_THRESHOLD", "0.35"))

# ── COCO → rooftop label remap ────────────────────────────────────────────────
# TODO: swap these with the real fine-tuned model's class names before production.
# These COCO classes serve as demo stand-ins for typical rooftop obstacles.
_COCO_TO_ROOFTOP: dict[str, str] = {
    "bottle": "water_tank",
    "cup": "water_tank",
    "refrigerator": "ac_unit",
    "chair": "furniture",
    "bench": "furniture",
    "potted plant": "rooftop_equipment",
    "tv": "rooftop_equipment",
    "laptop": "rooftop_equipment",
    "cell phone": "rooftop_equipment",
    "clock": "rooftop_equipment",
}

# Only run inference on these COCO classes (ignore all others for demo)
_ALLOWED_COCO_CLASSES: set[str] = set(_COCO_TO_ROOFTOP.keys())


def _get_model():
    """Lazy-load the YOLO model on first call; return None if unavailable."""
    global _yolo_model
    if _yolo_model is not None:
        return _yolo_model
    try:
        from ultralytics import YOLO  # noqa: PLC0415
        _yolo_model = YOLO(_YOLO_MODEL_PATH)
        return _yolo_model
    except Exception as exc:
        # Don't crash startup if model not downloaded — endpoint will return empty list
        print(f"[obstacles] YOLO model unavailable: {exc}")
        return None


# ── Route ─────────────────────────────────────────────────────────────────────

@router.post(
    "",
    response_model=ObstacleDetectionResponse,
    summary="Detect rooftop obstacles in a camera frame",
    response_description="List of detected obstacles with normalised bounding boxes",
)
async def detect_obstacles(
    image: UploadFile = File(..., description="JPEG frame from Flutter camera"),
) -> ObstacleDetectionResponse:
    """
    Accepts a JPEG/PNG image, runs YOLOv8 inference, and returns detected
    rooftop obstacles with normalised bounding-box coordinates.

    If the YOLO model is unavailable, returns an empty detection list
    (the Flutter app continues without obstacle data — no crash).
    """
    # Read image bytes
    try:
        contents = await image.read()
        pil_img = Image.open(io.BytesIO(contents)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid image: {exc}") from exc

    img_w, img_h = pil_img.size
    model = _get_model()

    detections: list[ObstacleDetection] = []

    if model is None:
        # Graceful degradation — model not available
        return ObstacleDetectionResponse(
            detections=[],
            image_width=img_w,
            image_height=img_h,
            model=_YOLO_MODEL_PATH,
            note="YOLO model not available. Running without obstacle detection.",
        )

    try:
        results = model.predict(
            source=pil_img,
            conf=_CONF_THRESHOLD,
            verbose=False,
        )

        for result in results:
            boxes = result.boxes
            if boxes is None:
                continue
            for box in boxes:
                coco_class: str = result.names[int(box.cls[0])]
                if coco_class not in _ALLOWED_COCO_CLASSES:
                    continue  # skip classes not in our rooftop-relevant set

                rooftop_label = _COCO_TO_ROOFTOP[coco_class]
                conf = float(box.conf[0])

                # YOLO xywhn gives normalised centre x, y, w, h  ∈ [0,1]
                xywhn = box.xywhn[0].tolist()
                cx, cy, bw, bh = xywhn[0], xywhn[1], xywhn[2], xywhn[3]

                detections.append(
                    ObstacleDetection(
                        label=rooftop_label,
                        confidence=round(conf, 3),
                        x=round(cx, 4),
                        y=round(cy, 4),
                        w=round(bw, 4),
                        h=round(bh, 4),
                        coco_class=coco_class,
                    )
                )

    except Exception as exc:
        # Never crash; return empty list so Flutter scan flow continues
        print(f"[obstacles] Inference error: {exc}")
        return ObstacleDetectionResponse(
            detections=[],
            image_width=img_w,
            image_height=img_h,
            model=_YOLO_MODEL_PATH,
            note=f"Inference error (returned empty): {exc}",
        )

    return ObstacleDetectionResponse(
        detections=detections,
        image_width=img_w,
        image_height=img_h,
        model=_YOLO_MODEL_PATH,
    )
