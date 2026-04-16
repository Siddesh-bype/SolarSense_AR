import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_textfield.dart';

class SetupScanScreen extends StatefulWidget {
  const SetupScanScreen({super.key});

  @override
  State<SetupScanScreen> createState() => _SetupScanScreenState();
}

class _SetupScanScreenState extends State<SetupScanScreen> {
  String _selectedRoof = 'Flat';
  String? _selectedProvider = 'MSEDCL';
  double _billAmount = 2500;

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
                'Help us calculate accurately',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildLocationCard(),
              const SizedBox(height: 16),
              _buildRoofTypeCard(),
              const SizedBox(height: 16),
              _buildRoofAreaCard(),
              const SizedBox(height: 16),
              _buildBillCard(),
              const SizedBox(height: 16),
              _buildProviderCard(),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Continue to AR Scan',
                onPressed: () => Navigator.pushNamed(context, '/scan/ar'),
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
      label: 'Your Location',
      child: Column(
        children: [
          const CustomTextField(
            hintText: 'Pune, Maharashtra',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            label: const Text('Use GPS', style: TextStyle(color: AppColors.primary)),
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

  Widget _buildRoofTypeCard() {
    return _buildCardBase(
      label: 'Roof Type',
      child: Row(
        children: ['Flat', 'Sloped', 'Mixed'].map((type) {
          final isSelected = _selectedRoof == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRoof = type),
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
      label: 'Approximate Roof Area (sq ft)',
      child: const CustomTextField(
        hintText: '0',
        keyboardType: TextInputType.number,
        suffixIcon: Padding(
          padding: EdgeInsets.all(14.0),
          child: Text('sq ft', style: TextStyle(color: AppColors.textSecondary)),
        ),
        helperText: "Leave blank — we'll estimate from AR scan",
      ),
    );
  }

  Widget _buildBillCard() {
    return _buildCardBase(
      label: 'Average Monthly Bill (₹)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '₹${_billAmount.toInt()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withOpacity(0.2),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.1),
            ),
            child: Slider(
              value: _billAmount,
              min: 500,
              max: 10000,
              divisions: 95,
              onChanged: (val) => setState(() => _billAmount = val),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('₹500', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('₹10,000+', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          )
        ],
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
            value: _selectedProvider,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
            items: ['MSEDCL', 'BESCOM', 'TATA Power', 'Other']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _selectedProvider = val),
          ),
        ),
      ),
    );
  }
}
