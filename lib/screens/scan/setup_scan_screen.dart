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

  // All fields start empty — user must fill them.
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
    // Prefill from session if the user has already been here before.
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
    setState(() { _locating = true; _error = null; });
    try {
      final loc = await _locationService.getCurrentLatLon();
      _session.updateScanInputs(lat: loc.lat, lon: loc.lon);
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
    return Scaffold(
      appBar: AppBar(
        title: null,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Up Your Scan',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us about your home — the AR scan will handle the panels.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildLocationCard(),
              const SizedBox(height: 16),
              _buildStateCard(),
              const SizedBox(height: 16),
              _buildRoofTypeCard(),
              const SizedBox(height: 16),
              _buildRoofAreaCard(),
              const SizedBox(height: 16),
              _buildBillCard(),
              const SizedBox(height: 16),
              _buildTariffCard(),
              const SizedBox(height: 16),
              _buildProviderCard(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Continue to AR Scan',
                onPressed: _continue,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBase({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return _buildCardBase(
      label: 'Your City',
      child: Column(
        children: [
          CustomTextField(
            controller: _cityCtrl,
            hintText: 'e.g. Pune',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useGps,
            icon: _locating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: AppColors.primary),
            label: Text(
              _session.lat != null ? 'GPS locked' : 'Use GPS',
              style: const TextStyle(color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard() {
    return _buildCardBase(
      label: 'State (for subsidy calculation)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _stateKey,
            isExpanded: true,
            hint: const Text('Select your state'),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
            items: _kStates.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (val) => setState(() => _stateKey = val),
          ),
        ),
      ),
    );
  }

  Widget _buildRoofTypeCard() {
    return _buildCardBase(
      label: 'Roof Type',
      child: Row(
        children: ['Flat', 'Sloped', 'Mixed'].map((type) {
          final isSelected = _roofType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _roofType = type),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoofAreaCard() {
    return _buildCardBase(
      label: 'Approximate Roof Area (sq ft) — optional',
      child: CustomTextField(
        controller: _roofAreaCtrl,
        hintText: '0',
        keyboardType: TextInputType.number,
        suffixIcon: const Padding(
          padding: EdgeInsets.all(14.0),
          child: Text('sq ft', style: TextStyle(color: AppColors.textSecondary)),
        ),
        helperText: "Leave blank — we'll estimate from the AR scan",
      ),
    );
  }

  Widget _buildBillCard() {
    return _buildCardBase(
      label: 'Average Monthly Bill (₹)',
      child: CustomTextField(
        controller: _billCtrl,
        hintText: 'e.g. 2500',
        keyboardType: TextInputType.number,
        prefixIcon: Icons.currency_rupee,
      ),
    );
  }

  Widget _buildTariffCard() {
    return _buildCardBase(
      label: 'Electricity Tariff (₹ / kWh) — optional',
      child: CustomTextField(
        controller: _tariffCtrl,
        hintText: 'e.g. 8.5',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        prefixIcon: Icons.bolt_outlined,
        helperText: "Leave blank — we'll use the state average",
      ),
    );
  }

  Widget _buildProviderCard() {
    return _buildCardBase(
      label: 'Electricity Provider (optional)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _provider,
            isExpanded: true,
            hint: const Text('Select provider'),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
            items: ['MSEDCL', 'BESCOM', 'TATA Power', 'Adani', 'Torrent Power', 'Other']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _provider = val),
          ),
        ),
      ),
    );
  }
}
