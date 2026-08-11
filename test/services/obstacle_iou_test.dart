// test/services/obstacle_iou_test.dart
//
// Regression tests for the IoU helper underpinning YOLO non-max suppression.
// The helper is a pure function on ObstacleDetection boxes (centre-xywh).

import 'package:flutter_test/flutter_test.dart';
import 'package:solarsense/models/obstacle_detection.dart';
import 'package:solarsense/services/obstacle_service.dart';

ObstacleDetection _box({
  required double cx,
  required double cy,
  required double w,
  required double h,
}) {
  return ObstacleDetection(
    label: 'test',
    confidence: 1.0,
    x: cx,
    y: cy,
    w: w,
    h: h,
  );
}

void main() {
  group('iouOfDetections', () {
    test('identical boxes → IoU = 1', () {
      final a = _box(cx: 0.5, cy: 0.5, w: 0.2, h: 0.2);
      final b = _box(cx: 0.5, cy: 0.5, w: 0.2, h: 0.2);
      expect(iouOfDetections(a, b), closeTo(1.0, 1e-9));
    });

    test('disjoint boxes → IoU = 0', () {
      final a = _box(cx: 0.2, cy: 0.2, w: 0.1, h: 0.1);
      final b = _box(cx: 0.8, cy: 0.8, w: 0.1, h: 0.1);
      expect(iouOfDetections(a, b), equals(0.0));
    });

    test('touching-only (zero area intersection) → IoU = 0', () {
      // Left box ends at x=0.3, right box starts at x=0.3.
      final a = _box(cx: 0.2, cy: 0.5, w: 0.2, h: 0.2);
      final b = _box(cx: 0.4, cy: 0.5, w: 0.2, h: 0.2);
      expect(iouOfDetections(a, b), equals(0.0));
    });

    test('half-overlap on one axis → IoU = 1/3', () {
      // Two unit-square boxes shifted by 0.5 on x → intersection 0.5×1 = 0.5,
      // union = 1 + 1 − 0.5 = 1.5, IoU = 0.5 / 1.5 = 1/3.
      final a = _box(cx: 0.5, cy: 0.5, w: 1.0, h: 1.0);
      final b = _box(cx: 1.0, cy: 0.5, w: 1.0, h: 1.0);
      expect(iouOfDetections(a, b), closeTo(1 / 3, 1e-9));
    });

    test('containment → IoU = areaSmall / areaLarge', () {
      final outer = _box(cx: 0.5, cy: 0.5, w: 1.0, h: 1.0);
      final inner = _box(cx: 0.5, cy: 0.5, w: 0.5, h: 0.5);
      // inter = 0.25, union = 1.0 → IoU = 0.25
      expect(iouOfDetections(outer, inner), closeTo(0.25, 1e-9));
    });

    test('is symmetric in its arguments', () {
      final a = _box(cx: 0.4, cy: 0.4, w: 0.3, h: 0.4);
      final b = _box(cx: 0.5, cy: 0.5, w: 0.4, h: 0.3);
      expect(
        iouOfDetections(a, b),
        closeTo(iouOfDetections(b, a), 1e-12),
      );
    });

    test('zero-area box never produces a positive IoU', () {
      final point = _box(cx: 0.5, cy: 0.5, w: 0.0, h: 0.0);
      final big   = _box(cx: 0.5, cy: 0.5, w: 1.0, h: 1.0);
      expect(iouOfDetections(point, big), equals(0.0));
    });
  });
}
