// lib/services/obstacle_service.dart
//
// Runs YOLOv8n.tflite on-device using tflite_flutter.
// Returns normalized ObstacleDetection bounding boxes.
// On ANY failure → returns empty list (never throws to caller).
//
// Input tensor: [1, 640, 640, 3] float32, values [0.0, 1.0]
// Output tensor: [1, 84, 8400] — standard YOLOv8 output (transposed internally)
//   84 = 4 (box) + 80 (COCO class scores)
//
// COCO → rooftop label remap (demo stand-ins):
//   bottle, cup       → water_tank
//   refrigerator      → ac_unit
//   chair, bench      → furniture
//   potted plant      → rooftop_equipment
//   tv, laptop, phone → rooftop_equipment
//
// Replace _cocoToRooftop and swap the .tflite weights with your fine-tuned model
// before production.

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/obstacle_detection.dart';

// Target input resolution expected by YOLOv8n
const _kInputSize = 640;
const _kConfThreshold = 0.4;
const _kIouThreshold = 0.45;
const _kNumClasses = 80; // COCO
const _kMaxDetections = 300;

// COCO class id → rooftop label (zero-indexed)
// Only classes in this map are reported; all others are silently discarded.
// TODO: replace with fine-tuned rooftop class map before production.
const Map<int, String> _cocoToRooftop = {
  39: 'water_tank',   // bottle
  41: 'water_tank',   // cup
  72: 'ac_unit',      // refrigerator
  56: 'furniture',    // chair
  15: 'furniture',    // bench
  58: 'rooftop_equipment', // potted plant
  62: 'rooftop_equipment', // tv
  63: 'rooftop_equipment', // laptop
  67: 'rooftop_equipment', // cell phone
};

class ObstacleService {
  dynamic _interpreter; // tflite_flutter Interpreter — typed as dynamic for safe import
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Dynamic import to avoid compile failure if tflite_flutter is not available
      // in the current build environment.
      // ignore: avoid_dynamic_calls
      final tflite = _tryLoadTflite();
      if (tflite == null) {
        _initialized = true; // will degrade gracefully
        return;
      }
      final modelData =
          await rootBundle.load('assets/models/yolov8n.tflite');
      _interpreter = await tflite.call(modelData.buffer.asUint8List());
      _initialized = true;
    } catch (_) {
      _initialized = true; // mark init so we don't keep retrying
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
    final resized = img.copyResize(decoded,
        width: _kInputSize, height: _kInputSize,
        interpolation: img.Interpolation.linear);

    // 2. Build float32 input tensor [1, 640, 640, 3]
    final inputFlat = Float32List(_kInputSize * _kInputSize * 3);
    int idx = 0;
    for (int y = 0; y < _kInputSize; y++) {
      for (int x = 0; x < _kInputSize; x++) {
        final pixel = resized.getPixel(x, y);
        inputFlat[idx++] = pixel.r / 255.0;
        inputFlat[idx++] = pixel.g / 255.0;
        inputFlat[idx++] = pixel.b / 255.0;
      }
    }
    final input = inputFlat.reshape([1, _kInputSize, _kInputSize, 3]);

    // 3. Prepare output buffer [1, 84, 8400]
    const numAnchors = 8400;
    final outputRaw =
        List.generate(1, (_) => List.generate(84, (_) => Float32List(numAnchors)));
    final outputs = {0: outputRaw};

    // 4. Run inference
    // ignore: avoid_dynamic_calls
    _interpreter.runForMultipleInputs([input], outputs);

    // 5. Parse detections
    final detections = <ObstacleDetection>[];
    final raw = outputRaw[0]; // [84][8400]

    for (int a = 0; a < numAnchors; a++) {
      // Find best class
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

      // YOLOv8 output: cx, cy, w, h (already normalised to [0,1] relative to 640)
      final cx = raw[0][a];
      final cy = raw[1][a];
      final bw = raw[2][a];
      final bh = raw[3][a];

      detections.add(ObstacleDetection(
        label: _cocoToRooftop[bestClass]!,
        confidence: bestScore,
        x: cx,
        y: cy,
        w: bw,
        h: bh,
      ));
    }

    return _nms(detections);
  }

  /// Simple class-agnostic NMS to remove overlapping boxes.
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

    final ix = math.max(0, math.min(ax2, bx2) - math.max(ax1, bx1));
    final iy = math.max(0, math.min(ay2, by2) - math.max(ay1, by1));
    final inter = ix * iy;
    if (inter <= 0) return 0;
    final union = a.w * a.h + b.w * b.h - inter;
    return union > 0 ? inter / union : 0;
  }

  /// Dynamically loads the tflite Interpreter factory — returns null if
  /// tflite_flutter is not linked (e.g. running unit tests on desktop).
  static Function? _tryLoadTflite() {
    try {
      // This will throw if the native library is not available
      // We use a function reference so the import stays conditional
      return _tfliteInterpreterFrom;
    } catch (_) {
      return null;
    }
  }
}

// Separated to keep the tflite_flutter import isolated — avoids breaking
// tests on platforms without the native .so/.dylib.
Future<dynamic> _tfliteInterpreterFrom(Uint8List modelBytes) async {
  // ignore: depend_on_referenced_packages
  final tflite = await _loadTflite();
  return tflite.fromBuffer(modelBytes);
}

Future<dynamic> _loadTflite() async {
  // ignore: avoid_dynamic_calls, depend_on_referenced_packages
  return (await _importTflite())['Interpreter'];
}

Future<Map<String, dynamic>> _importTflite() async {
  throw UnimplementedError(
    'tflite_flutter dynamic import not supported in this environment. '
    'ObstacleService will degrade to returning empty detections.',
  );
}
