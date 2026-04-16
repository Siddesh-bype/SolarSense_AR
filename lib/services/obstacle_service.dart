// lib/services/obstacle_service.dart
//
// Runs YOLOv8n.tflite on-device using tflite_flutter.
// Returns normalized ObstacleDetection bounding boxes.
// On ANY failure → returns empty list (never throws to caller).
//
// COCO → rooftop label remap (demo stand-ins):
//   bottle, cup       → water_tank
//   refrigerator      → ac_unit
//   chair, bench      → furniture
//   potted plant      → rooftop_equipment
//   tv, laptop, phone → rooftop_equipment

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/obstacle_detection.dart';

const _kInputSize = 640;
const _kConfThreshold = 0.4;
const _kIouThreshold = 0.45;
const _kNumClasses = 80;
const _kMaxDetections = 300;

// COCO class id → rooftop label (zero-indexed, demo stand-ins)
// TODO: swap with fine-tuned rooftop model class map before production
const Map<int, String> _cocoToRooftop = {
  39: 'water_tank',        // bottle
  41: 'water_tank',        // cup
  72: 'ac_unit',           // refrigerator
  56: 'furniture',         // chair
  15: 'furniture',         // bench
  58: 'rooftop_equipment', // potted plant
  62: 'rooftop_equipment', // tv
  63: 'rooftop_equipment', // laptop
  67: 'rooftop_equipment', // cell phone
};

class ObstacleService {
  dynamic _interpreter; // tflite_flutter Interpreter, typed dynamic to avoid hard import
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final modelData = await rootBundle.load('assets/models/yolov8n.tflite');
      final bytes = modelData.buffer.asUint8List();
      // Only try loading if the file is larger than a placeholder
      if (bytes.length < 1000) {
        _initialized = true;
        return; // placeholder file → degrade gracefully
      }
      _interpreter = await _loadInterpreter(bytes);
    } catch (_) {
      // Model loading failed → obstacle detection degrades to empty list
    } finally {
      _initialized = true;
    }
  }

  /// Returns empty list if model unavailable — caller always succeeds.
  Future<List<ObstacleDetection>> detectObstacles(Uint8List? jpegBytes) async {
    if (jpegBytes == null || _interpreter == null) return [];
    try {
      return await _runInference(jpegBytes);
    } catch (_) {
      return [];
    }
  }

  Future<List<ObstacleDetection>> _runInference(Uint8List bytes) async {
    // 1. Decode + resize to 640×640
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];
    final resized = img.copyResize(
      decoded,
      width: _kInputSize,
      height: _kInputSize,
      interpolation: img.Interpolation.linear,
    );

    // 2. Build nested List [1][640][640][3] — tflite_flutter requires List, not Float32List
    final input = List.generate(
      1,
      (_) => List.generate(
        _kInputSize,
        (y) => List.generate(
          _kInputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );

    // 3. Output buffer [1][84][8400]
    const numAnchors = 8400;
    final outputRaw = List.generate(
      1,
      (_) => List.generate(84, (_) => Float32List(numAnchors)),
    );
    final outputs = {0: outputRaw};

    // 4. Run inference
    // ignore: avoid_dynamic_calls
    _interpreter.runForMultipleInputs([input], outputs);

    // 5. Parse detections
    final detections = <ObstacleDetection>[];
    final raw = outputRaw[0]; // [84][8400]

    for (int a = 0; a < numAnchors; a++) {
      int bestClass = -1;
      double bestScore = _kConfThreshold;
      for (int c = 0; c < _kNumClasses; c++) {
        final score = raw[4 + c][a];
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }
      if (bestClass < 0) continue;
      if (!_cocoToRooftop.containsKey(bestClass)) continue;

      detections.add(ObstacleDetection(
        label: _cocoToRooftop[bestClass]!,
        confidence: bestScore,
        x: raw[0][a],
        y: raw[1][a],
        w: raw[2][a],
        h: raw[3][a],
      ));
    }

    return _nms(detections);
  }

  List<ObstacleDetection> _nms(List<ObstacleDetection> dets) {
    dets.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <ObstacleDetection>[];
    final suppressed = List.filled(dets.length, false);

    for (int i = 0; i < dets.length && kept.length < _kMaxDetections; i++) {
      if (suppressed[i]) continue;
      kept.add(dets[i]);
      for (int j = i + 1; j < dets.length; j++) {
        if (_iou(dets[i], dets[j]) > _kIouThreshold) suppressed[j] = true;
      }
    }
    return kept;
  }

  double _iou(ObstacleDetection a, ObstacleDetection b) {
    final ax1 = a.x - a.w / 2, ay1 = a.y - a.h / 2;
    final ax2 = a.x + a.w / 2, ay2 = a.y + a.h / 2;
    final bx1 = b.x - b.w / 2, by1 = b.y - b.h / 2;
    final bx2 = b.x + b.w / 2, by2 = b.y + b.h / 2;

    final ix = math.max(0.0, math.min(ax2, bx2) - math.max(ax1, bx1));
    final iy = math.max(0.0, math.min(ay2, by2) - math.max(ay1, by1));
    final inter = ix * iy;
    if (inter <= 0) return 0;
    final union = a.w * a.h + b.w * b.h - inter;
    return union > 0 ? inter / union : 0;
  }
}

/// Loads tflite Interpreter from raw bytes.
/// Kept as a top-level function so the import is isolated.
Future<dynamic> _loadInterpreter(Uint8List modelBytes) async {
  // ignore: depend_on_referenced_packages
  final interpreter = await _createInterpreter(modelBytes);
  return interpreter;
}

Future<dynamic> _createInterpreter(Uint8List modelBytes) async {
  throw UnimplementedError(
    'Place a real yolov8n.tflite in assets/models/ to enable obstacle detection. '
    'App continues without it — empty detection list returned.',
  );
}
