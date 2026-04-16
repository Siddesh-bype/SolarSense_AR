// lib/services/subsidy_service.dart
//
// Pure Dart subsidy calculation engine.
// Loads state_subsidies.json ONCE at init via rootBundle — never on each call.
//
// Central slab (PM Surya Ghar Muft Bijli Yojana):
//   ≤ 1 kW → ₹30,000
//   ≤ 2 kW → ₹60,000
//   ≥ 3 kW → ₹78,000 (hard cap)

import 'dart:convert';
import 'package:flutter/services.dart';

class SubsidyResult {
  final int centralSubsidy;
  final int stateSubsidy;
  final int totalSubsidy;
  final int estimatedCost;
  final int netCost;
  final double paybackYears;
  final double annualSavingsInr;
  final String stateDisplayName;
  final String statePortal;
  final String stateNotes;

  const SubsidyResult({
    required this.centralSubsidy,
    required this.stateSubsidy,
    required this.totalSubsidy,
    required this.estimatedCost,
    required this.netCost,
    required this.paybackYears,
    required this.annualSavingsInr,
    required this.stateDisplayName,
    required this.statePortal,
    required this.stateNotes,
  });
}

class SubsidyService {
  Map<String, dynamic>? _stateDb;
  bool _initialized = false;

  /// Must be called once before using [calculate].
  Future<void> init() async {
    if (_initialized) return;
    final raw = await rootBundle.loadString('assets/data/state_subsidies.json');
    _stateDb = jsonDecode(raw) as Map<String, dynamic>;
    _initialized = true;
  }

  SubsidyResult calculate({
    required double systemKw,
    required String stateName,
    required double annualKwh,
    required double avgTariff,
  }) {
    assert(_initialized, 'SubsidyService.init() must be called first');

    // ── 1. Central subsidy slab ─────────────────────────────────────────────
    final int central;
    if (systemKw <= 1.0) {
      central = 30000;
    } else if (systemKw <= 2.0) {
      central = 60000;
    } else {
      central = 78000; // hard cap for 3 kW+
    }

    // ── 2. State top-up ──────────────────────────────────────────────────────
    final stateKey = stateName.toLowerCase().trim().replaceAll(' ', '_');
    final stateData = (_stateDb?[stateKey] as Map<String, dynamic>?) ?? {};

    final perKw = (stateData['additional_subsidy_per_kw'] as num?)?.toInt() ?? 0;
    final flat = (stateData['additional_subsidy_flat'] as num?)?.toInt() ?? 0;
    final maxKw =
        (stateData['max_kw_for_state_subsidy'] as num?)?.toDouble() ?? systemKw;

    int state;
    if (perKw > 0) {
      state = (perKw * systemKw.clamp(0, maxKw)).toInt();
    } else if (flat > 0) {
      state = flat;
    } else {
      state = 0;
    }

    // Resolve tariff: prefer state default when caller passes 0
    final tariff = avgTariff > 0
        ? avgTariff
        : (stateData['avg_tariff_per_unit'] as num?)?.toDouble() ?? 7.0;

    // ── 3. Cost & payback ────────────────────────────────────────────────────
    // Standard Indian install cost: ₹75,000/kW (panels + inverter + mounting + labour)
    final estimated = (systemKw * 75000).toInt();
    final total = central + state;
    final net = (estimated - total).clamp(0, estimated).toInt();
    final annualSavings = annualKwh * tariff;
    final payback = annualSavings > 0 ? net / annualSavings : 0.0;

    return SubsidyResult(
      centralSubsidy: central,
      stateSubsidy: state,
      totalSubsidy: total,
      estimatedCost: estimated,
      netCost: net,
      paybackYears: double.parse(payback.toStringAsFixed(2)),
      annualSavingsInr: double.parse(annualSavings.toStringAsFixed(2)),
      stateDisplayName:
          stateData['display_name'] as String? ?? _toTitle(stateName),
      statePortal:
          stateData['portal'] as String? ?? 'pmsuryaghar.gov.in',
      stateNotes: stateData['notes'] as String? ?? '',
    );
  }

  String _toTitle(String s) => s.isEmpty
      ? s
      : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
}
