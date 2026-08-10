import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/location_service.dart';
import '../../services/user_session.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_textfield.dart';

// stateKey -> display label. Keys must match assets/data/state_subsidies.json.
const Map<String, String> _kStates = {
  'maharashtra': 'Maharashtra',
  'gujarat': 'Gujarat',
  'karnataka': 'Karnataka',
  'rajasthan': 'Rajasthan',
  'tamil_nadu': 'Tamil Nadu',
  'uttar_pradesh': 'Uttar Pradesh',
};

class SetupScanScreen extends StatefulWidget {
  const SetupScanScreen({super.key});

  @override
  State<SetupScanScreen> createState() => _SetupScanScreenState();
}

class _SetupScanScreenState extends State<SetupScanScreen> {
  final _locationService = LocationService();
  final _session = UserSession.instance;

  final _cityCtrl = TextEditingController();
  final _billCtrl = TextEditingController();
  final _tariffCtrl = TextEditingController();
  final _roofAreaCtrl = TextEditingController();

  String? _stateKey;
  String? _roofType;
  String? _provider;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cityCtrl.text = _session.city ?? '';
    _billCtrl.text = _session.monthlyBillInr?.toStringAsFixed(0) ?? '';
    _tariffCtrl.text = _session.avgTariffInr?.toStringAsFixed(2) ?? '';
    _roofAreaCtrl.text = _session.roofAreaSqFt?.toStringAsFixed(0) ?? '';
    _stateKey = _session.stateKey;
    _roofType = _session.roofType;
    _provider = _session.electricityProvider;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _billCtrl.dispose();
    _tariffCtrl.dispose();
    _roofAreaCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final loc = await _locationService.getCurrentLatLon();
      _session.updateScanInputs(lat: loc.lat, lon: loc.lon);
      final place = await _locationService.reverseGeocode(loc.lat, loc.lon);
      if (!mounted) return;
      if (place != null) {
        if (place.city != null && place.city!.isNotEmpty) {
          _cityCtrl.text = place.city!;
        }
        if (place.stateKey != null && _kStates.containsKey(place.stateKey)) {
          _stateKey = place.stateKey;
        }
        _session.updateScanInputs(city: place.city, stateKey: place.stateKey);
      }
    } catch (_) {
      setState(() => _error = 'Could not get GPS. Enter location manually.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? _validate() {
    final bill = double.tryParse(_billCtrl.text.trim());
    if (bill == null || bill <= 0) return 'Enter your monthly electricity bill.';
    if (_stateKey == null) return 'Select your state.';
    return null;
  }

  void _continue() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final tariff = double.tryParse(_tariffCtrl.text.trim());
    final area = double.tryParse(_roofAreaCtrl.text.trim());

    _session.updateScanInputs(
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      stateKey: _stateKey,
      monthlyBillInr: double.parse(_billCtrl.text.trim()),
      avgTariffInr: tariff,
      electricityProvider: _provider,
      roofType: _roofType,
      roofAreaSqFt: area,
    );

    Navigator.pushNamed(context, '/scan/ar');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set up your scan',
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us about your home — the AR scan will handle the panels.',
                style: tt.bodyLarge?.copyWith(color: c.onSurfaceMuted),
              ),
              const SizedBox(height: 24),
              _card('Your City', [
                CustomTextField(
                  controller: _cityCtrl,
                  hintText: 'e.g. Pune',
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useGps,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_session.lat != null ? 'GPS locked' : 'Use GPS'),
                ),
              ]),
              const SizedBox(height: 16),
              _card('State (for subsidy calculation)', [
                _dropdown(
                  value: _stateKey,
                  hint: 'Select your state',
                  items: _kStates.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (val) => setState(() => _stateKey = val),
                ),
              ]),
              const SizedBox(height: 16),
              _card('Roof Type', [
                Row(
                  children: ['Flat', 'Sloped', 'Mixed'].map((type) {
                    final isSelected = _roofType == type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _roofType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? c.primary : Colors.transparent,
                            border:
                                Border.all(color: isSelected ? c.primary : c.border),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            type,
                            style: tt.labelMedium?.copyWith(
                              color: isSelected
                                  ? c.onPrimary
                                  : c.onSurface,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ]),
              const SizedBox(height: 16),
              _card('Approximate roof area (sq ft) — optional', [
                CustomTextField(
                  controller: _roofAreaCtrl,
                  hintText: '0',
                  keyboardType: TextInputType.number,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('sq ft',
                        style: TextStyle(color: c.onSurfaceMuted)),
                  ),
                  helperText: "Leave blank — we'll estimate from the AR scan",
                ),
              ]),
              const SizedBox(height: 16),
              _card('Average monthly bill (₹)', [
                CustomTextField(
                  controller: _billCtrl,
                  hintText: 'e.g. 2500',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.currency_rupee,
                ),
              ]),
              const SizedBox(height: 16),
              _card('Electricity tariff (₹ / kWh) — optional', [
                CustomTextField(
                  controller: _tariffCtrl,
                  hintText: 'e.g. 8.5',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.bolt_outlined,
                  helperText: "Leave blank — we'll use the state average",
                ),
              ]),
              const SizedBox(height: 16),
              _card('Electricity provider (optional)', [
                _dropdown(
                  value: _provider,
                  hint: 'Select provider',
                  items: ['MSEDCL', 'BESCOM', 'TATA Power', 'Adani', 'Torrent Power', 'Other']
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _provider = val),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                      style: tt.bodySmall?.copyWith(color: c.error)),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Continue to AR Scan',
                onPressed: _continue,
                icon: Icons.arrow_forward,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String label, List<Widget> children) {
    final c = AppColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: c.onSurfaceMuted)),
          icon: Icon(Icons.keyboard_arrow_down, color: c.onSurfaceMuted),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}