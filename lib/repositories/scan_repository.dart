// lib/repositories/scan_repository.dart
//
// Scan-result persistence boundary.
//
// On-device default keeps a bounded in-memory cache of the most recent scans so
// the app can display a "past scans" list without any backend. A Firestore
// seam is sketched (not imported) for when cloud sync is needed.

import '../models/enriched_scan_result.dart';

abstract class ScanRepository {
  Future<void> save(EnrichedScanResult result);
  Future<List<EnrichedScanResult>> recent({int limit = 10});
}

class InMemoryScanRepository implements ScanRepository {
  final List<EnrichedScanResult> _store = [];
  static const int _kMax = 25;

  @override
  Future<void> save(EnrichedScanResult result) async {
    _store.insert(0, result);
    if (_store.length > _kMax) {
      _store.removeRange(_kMax, _store.length);
    }
  }

  @override
  Future<List<EnrichedScanResult>> recent({int limit = 10}) async =>
      _store.take(limit).toList();
}

/*
/// ── FIRESTORE SEAM (optional) ───────────────────────────────────────────────
/// Requires `cloud_firestore`. Scans are keyed per-user under
/// `users/{uid}/scans/{scanId}`.
///
/// class FirestoreScanRepository implements ScanRepository {
///   final FirebaseFirestore _db;
///   final String _uid;
///   FirestoreScanRepository(this._db, this._uid);
///
///   @override
///   Future<void> save(EnrichedScanResult result) async {
///     await _db
///         .collection('users')
///         .doc(_uid)
///         .collection('scans')
///         .add(result.toJson()); // add a toJson() to EnrichedScanResult
///   }
///
///   @override
///   Future<List<EnrichedScanResult>> recent({int limit = 10}) async {
///     final snap = await _db
///         .collection('users')
///         .doc(_uid)
///         .collection('scans')
///         .orderBy('createdAt', descending: true)
///         .limit(limit)
///         .get();
///     return snap.docs
///         .map((d) => EnrichedScanResult.fromJson(d.data()))
///         .toList(); // add a factory to EnrichedScanResult
///   }
/// }
*/
