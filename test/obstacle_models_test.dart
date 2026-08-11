import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solarsense/models/obstacle_detection.dart';
import 'package:solarsense/models/obstacle_summary.dart';
import 'package:solarsense/services/obstacle_service.dart';

void main() {
  group('ObstacleDetection', () {
    test('footprint and shading resolve from the rooftop class map', () {
      const d = ObstacleDetection(
          label: 'water_tank', confidence: 0.8, x: 0.5, y: 0.5, w: 0.1, h: 0.1);
      expect(d.footprintM2, 1.4);
      expect(d.shadingLossPct, 0.06);
    });

    test('unknown label falls back to "other"', () {
      const d = ObstacleDetection(
          label: 'nonsense', confidence: 0.5, x: 0.1, y: 0.1, w: 0.1, h: 0.1);
      expect(d.footprintM2, ObstacleFootprint.kind('other'));
      expect(d.shadingLossPct, ObstacleFootprint.shading('other'));
    });

    test('round-trips through JSON', () {
      const d = ObstacleDetection(
          label: 'ac_unit', confidence: 0.7, x: 0.2, y: 0.3, w: 0.05, h: 0.05);
      final back =
          ObstacleDetection.fromJson(jsonDecode(jsonEncode(d.toJson())));
      expect(back.label, d.label);
      expect(back.confidence, d.confidence);
      expect(back.x, d.x);
      expect(back.w, d.w);
    });

    test('listFromJson decodes the demo array', () {
      const raw = '[{"label":"water_tank","confidence":0.82,'
          '"x":0.38,"y":0.42,"w":0.10,"h":0.12}]';
      final list = ObstacleDetection.listFromJson(raw);
      expect(list.length, 1);
      expect(list.first.label, 'water_tank');
      expect(list.first.confidence, 0.82);
    });
  });

  group('ObstacleSummary / aggregate', () {
    test('aggregate sums footprint and caps shading at maxLoss', () {
      final svc = ObstacleService();
      // 10 water tanks: 10 * 0.06 = 0.60 shading, but capped at 0.30.
      final many = List.generate(
        10,
        (i) => ObstacleDetection(
            label: 'water_tank',
            confidence: 0.9,
            x: 0.1 * (i % 10),
            y: 0.1,
            w: 0.05,
            h: 0.05),
      );
      final summary = svc.aggregate(many);
      expect(summary.obstacleAreaM2, closeTo(14.0, 1e-9)); // 10 * 1.4
      expect(summary.shadingLossPct,
          closeTo(ObstacleSummary.maxLoss, 1e-9)); // 0.30 cap
      expect(summary.items.length, 10);
    });

    test('aggregate with no obstacles is zeroed', () {
      final summary = ObstacleService().aggregate(const []);
      expect(summary.obstacleAreaM2, 0.0);
      expect(summary.shadingLossPct, 0.0);
    });
  });

  group('iouOfDetections', () {
    test('identical boxes => IoU 1.0', () {
      const box = ObstacleDetection(
          label: 'x', confidence: 1, x: 0.5, y: 0.5, w: 0.2, h: 0.2);
      expect(iouOfDetections(box, box), closeTo(1.0, 1e-9));
    });

    test('disjoint boxes => IoU 0.0', () {
      const a = ObstacleDetection(
          label: 'x', confidence: 1, x: 0.2, y: 0.2, w: 0.1, h: 0.1);
      const b = ObstacleDetection(
          label: 'x', confidence: 1, x: 0.8, y: 0.8, w: 0.1, h: 0.1);
      expect(iouOfDetections(a, b), 0.0);
    });

    test('half-overlapping boxes => IoU 1/3', () {
      // Two equal boxes side by side, overlapping by half in x.
      const a = ObstacleDetection(
          label: 'x', confidence: 1, x: 0.25, y: 0.5, w: 0.2, h: 0.2);
      const b = ObstacleDetection(
          label: 'x', confidence: 1, x: 0.35, y: 0.5, w: 0.2, h: 0.2);
      // intersection area = 0.1 * 0.2 = 0.02; each area = 0.04; union = 0.06
      expect(iouOfDetections(a, b), closeTo(1 / 3, 1e-9));
    });
  });
}
