import '../../domain/models/obstacle_model.dart';

/// CRUD service for obstacle zones.
///
/// Keeps the list of active [ObstacleModel] objects and exposes
/// aggregate metrics consumed by [AreaCalculationService].
class ObstacleService {
  ObstacleService();

  final List<ObstacleModel> _obstacles = <ObstacleModel>[];

  // ── Read ───────────────────────────────────────────────────────────────────

  List<ObstacleModel> get obstacles => List<ObstacleModel>.unmodifiable(_obstacles);

  double get totalObstacleAreaM2 =>
      _obstacles.fold(0.0, (double sum, ObstacleModel obs) => sum + obs.areaM2);

  ObstacleModel? findById(String id) {
    for (final ObstacleModel obs in _obstacles) {
      if (obs.id == id) return obs;
    }
    return null;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  void addObstacle({
    required String id,
    required double centerX,
    required double centerZ,
    double widthM = 0.5,
    double depthM = 0.5,
  }) {
    _obstacles.add(ObstacleModel(
      id: id,
      centerX: centerX,
      centerZ: centerZ,
      widthM: widthM,
      depthM: depthM,
    ));
  }

  bool updateObstacle({
    required String id,
    double? centerX,
    double? centerZ,
    double? widthM,
    double? depthM,
  }) {
    final int idx = _obstacles.indexWhere((ObstacleModel o) => o.id == id);
    if (idx == -1) return false;
    _obstacles[idx] = _obstacles[idx].copyWith(
      centerX: centerX,
      centerZ: centerZ,
      widthM: widthM,
      depthM: depthM,
    );
    return true;
  }

  bool removeObstacle(String id) {
    final int before = _obstacles.length;
    _obstacles.removeWhere((ObstacleModel o) => o.id == id);
    return _obstacles.length < before;
  }

  void clearAll() => _obstacles.clear();

  // ── Serialization ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> toJsonList() =>
      _obstacles.map((ObstacleModel o) => o.toJson()).toList();
}
