// lib/repositories/leads_repository.dart
//
// Vendor-lead capture boundary.
//
// When a user requests "solar vendors near me", the app can hand off a lead to
// a sales backend. The on-device default just queues leads locally. A FastAPI
// seam is sketched (not imported) so the backend story is real but optional.

class VendorLead {
  final String name;
  final String contact;
  final String stateKey;
  final DateTime createdAt;

  VendorLead({
    required this.name,
    required this.contact,
    required this.stateKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact': contact,
        'stateKey': stateKey,
        'createdAt': createdAt.toIso8601String(),
      };
}

abstract class LeadsRepository {
  Future<void> submit(VendorLead lead);
  Future<List<VendorLead>> pending();
}

class OnDeviceLeadsRepository implements LeadsRepository {
  final List<VendorLead> _queue = [];

  @override
  Future<void> submit(VendorLead lead) async => _queue.add(lead);

  @override
  Future<List<VendorLead>> pending() async => List.unmodifiable(_queue);
}

/*
/// ── FASTAPI SEAM (optional) ─────────────────────────────────────────────────
/// Requires the `http` package (already a dependency). POST each queued lead to
/// your backend and flush on success.
///
/// class ApiLeadsRepository implements LeadsRepository {
///   final http.Client _client;
///   final String _baseUrl;
///   final OnDeviceLeadsRepository _local;
///   ApiLeadsRepository(this._client, this._baseUrl, this._local);
///
///   @override
///   Future<void> submit(VendorLead lead) async {
///     await _client.post(
///       Uri.parse('$_baseUrl/leads'),
///       headers: {'Content-Type': 'application/json'},
///       body: jsonEncode(lead.toJson()),
///     );
///     await _local.submit(lead);
///   }
///
///   @override
///   Future<List<VendorLead>> pending() async => _local.pending();
/// }
*/
