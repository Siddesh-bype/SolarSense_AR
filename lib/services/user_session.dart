// In-memory store of user-entered data shared across screens.
// AR-driven values (panel count, system kW, roof area) are passed via
// Navigator route arguments and do NOT live here.

import 'package:flutter/foundation.dart';

class UserSession extends ChangeNotifier {
  UserSession._();
  static final UserSession instance = UserSession._();

  // Auth / profile
  String? name;
  String? email;

  // Location — stateKey must match assets/data/state_subsidies.json keys.
  String? city;
  String? stateKey;          // e.g. 'maharashtra', 'gujarat'
  double? lat;
  double? lon;

  // Electricity
  double? monthlyBillInr;    // ₹ per month
  double? avgTariffInr;      // ₹ per kWh — optional override
  String? electricityProvider;

  // Roof (user-declared, optional; AR may override)
  String? roofType;          // 'Flat' | 'Sloped' | 'Mixed'
  double? roofAreaSqFt;      // optional user-declared

  bool get hasCoreInputs =>
      (monthlyBillInr != null && monthlyBillInr! > 0) && stateKey != null;

  void updateProfile({String? name, String? email}) {
    if (name != null) this.name = name;
    if (email != null) this.email = email;
    notifyListeners();
  }

  void updateScanInputs({
    String? city,
    String? stateKey,
    double? lat,
    double? lon,
    double? monthlyBillInr,
    double? avgTariffInr,
    String? electricityProvider,
    String? roofType,
    double? roofAreaSqFt,
  }) {
    if (city != null) this.city = city;
    if (stateKey != null) this.stateKey = stateKey;
    if (lat != null) this.lat = lat;
    if (lon != null) this.lon = lon;
    if (monthlyBillInr != null) this.monthlyBillInr = monthlyBillInr;
    if (avgTariffInr != null) this.avgTariffInr = avgTariffInr;
    if (electricityProvider != null) this.electricityProvider = electricityProvider;
    if (roofType != null) this.roofType = roofType;
    if (roofAreaSqFt != null) this.roofAreaSqFt = roofAreaSqFt;
    notifyListeners();
  }

  void clear() {
    name = email = null;
    city = stateKey = electricityProvider = roofType = null;
    lat = lon = monthlyBillInr = avgTariffInr = roofAreaSqFt = null;
    notifyListeners();
  }
}
