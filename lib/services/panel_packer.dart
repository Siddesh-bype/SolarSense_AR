// lib/services/panel_packer.dart
//
// Pure-Dart greedy shelf packer for mixed solar-module layouts on a roof plane.
//
// It is a Dart port of the native `PanelGridCalculator.packMixed` so the on-device
// pipeline can derive a panel count / system kW for the manual-entry path (and for
// unit tests) without an ARCore session. Layout is centre-origin in plane-local XZ:
// x runs along the roof width, z along the roof depth.

/// Roof plane extent in metres (width along X, depth along Z).
class Extent {
  final double width;
  final double depth;
  const Extent(this.width, this.depth);
}

/// A module SKU offered to the packer.
class PanelSpec {
  final String name;
  final double widthM;
  final double heightM;
  final int watts;
  const PanelSpec(this.name, this.widthM, this.heightM, this.watts);

  double get area => widthM * heightM;
  double get kw => watts / 1000.0;
}

/// One packed module, centred on its (x, z) plane-local position.
class PlacedPanel {
  final int id;
  final double x;
  final double z;
  final double widthM;
  final double heightM;
  final int watts;
  PlacedPanel(this.id, this.x, this.z, this.widthM, this.heightM, this.watts);

  double get halfW => widthM / 2;
  double get halfD => heightM / 2;

  bool overlaps(PlacedPanel other) =>
      (x - other.x).abs() < (halfW + other.halfW) &&
      (z - other.z).abs() < (halfD + other.halfD);
}

/// Obstacle keep-out zone in plane-local XZ (centre + half-extents), metres.
class KeepOut {
  final double x;
  final double z;
  final double halfW;
  final double halfD;
  const KeepOut(this.x, this.z, this.halfW, this.halfD);
}

class PackResult {
  final List<PlacedPanel> panels;
  final double totalKw;
  final int totalWatts;
  const PackResult({required this.panels, required this.totalKw, required this.totalWatts});
}

/// Packs [catalog] (any order) into [plane] using greedy shelf packing: the
/// largest SKU whose depth fits the remaining rows goes into a row, then panels
/// are laid edge-to-edge along X. Cells overlapping [keepOuts] are skipped, so the
/// result never overlaps an obstacle. Caps at [maxPanels].
PackResult packMixed({
  required Extent plane,
  required List<PanelSpec> catalog,
  int maxPanels = 50,
  List<KeepOut> keepOuts = const [],
}) {
  if (catalog.isEmpty || maxPanels <= 0) {
    return const PackResult(panels: [], totalKw: 0, totalWatts: 0);
  }
  final sorted = [...catalog]..sort((a, b) => b.area.compareTo(a.area));

  final halfW = plane.width / 2;
  final halfD = plane.depth / 2;
  if (halfW <= 0 || halfD <= 0) {
    return const PackResult(panels: [], totalKw: 0, totalWatts: 0);
  }

  final placed = <PlacedPanel>[];
  int id = 0;
  double edgeZ = -halfD; // front edge of the current row

  while (edgeZ < halfD && placed.length < maxPanels) {
    final availDepth = halfD - edgeZ;
    // Largest SKU that fits the remaining depth.
    PanelSpec? rowSpec;
    for (final s in sorted) {
      if (s.heightM <= availDepth) {
        rowSpec = s;
        break;
      }
    }
    if (rowSpec == null) break;

    double edgeX = -halfW;
    while (edgeX < halfW && placed.length < maxPanels) {
      if (edgeX + rowSpec.widthM > halfW) break; // row full

      final cx = edgeX + rowSpec.widthM / 2;
      final cz = edgeZ + rowSpec.heightM / 2;
      if (_cellClear(cx, cz, rowSpec.widthM / 2, rowSpec.heightM / 2, keepOuts)) {
        placed.add(PlacedPanel(id++, cx, cz, rowSpec.widthM, rowSpec.heightM, rowSpec.watts));
        edgeX += rowSpec.widthM;
      } else {
        // Skip just enough to clear the obstacle and retry the cell.
        edgeX += rowSpec.widthM;
      }
    }
    edgeZ += rowSpec.heightM;
  }

  var totalW = 0;
  for (final p in placed) {
    totalW += p.watts;
  }
  return PackResult(
    panels: placed,
    totalKw: totalW / 1000.0,
    totalWatts: totalW,
  );
}

bool _cellClear(
  double cx,
  double cz,
  double halfW,
  double halfD,
  List<KeepOut> kos,
) {
  for (final k in kos) {
    if ((cx - k.x).abs() < (halfW + k.halfW) &&
        (cz - k.z).abs() < (halfD + k.halfD)) {
      return false;
    }
  }
  return true;
}
