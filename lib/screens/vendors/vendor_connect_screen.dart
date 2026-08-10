import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class VendorConnectScreen extends StatefulWidget {
  const VendorConnectScreen({super.key});

  @override
  State<VendorConnectScreen> createState() => _VendorConnectScreenState();
}

class _VendorConnectScreenState extends State<VendorConnectScreen> {
  String _activeFilter = 'All';

  static const _filters = ['All', 'Highest Rated', 'Nearest', 'Best Price'];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect with Installers')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Solar Installers Near You',
                  style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700, color: c.onSurface),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: AppColors.primaryDeep),
                    const SizedBox(width: 4),
                    Text('Pune, Maharashtra',
                        style:
                            tt.bodySmall?.copyWith(color: c.onSurfaceMuted)),
                  ],
                ),
              ],
            ),
          ),
          _buildFilterRow(c, tt),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _vendorCard(
                  c: c,
                  tt: tt,
                  name: 'Surya Power Solutions',
                  initials: 'SP',
                  rating: '4.8',
                  reviews: '42',
                  distance: '1.2 km away',
                  speciality: 'Residential Solar',
                  price: '₹43,000/kW',
                ),
                const SizedBox(height: 14),
                _vendorCard(
                  c: c,
                  tt: tt,
                  name: 'Green Energy Pros',
                  initials: 'GE',
                  rating: '4.7',
                  reviews: '12',
                  distance: '2.3 km away',
                  speciality: 'Premium Setup',
                  price: '₹45,000/kW',
                ),
                const SizedBox(height: 14),
                _vendorCard(
                  c: c,
                  tt: tt,
                  name: 'EcoRoof India',
                  initials: 'ER',
                  rating: '4.5',
                  reviews: '28',
                  distance: '4.5 km away',
                  speciality: 'Budget Friendly',
                  price: '₹41,000/kW',
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom == 0
                  ? 16
                  : MediaQuery.of(context).padding.bottom,
            ),
            color: c.goldSoft,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.goldDeep),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your report has been shared securely with the selected vendors to provide accurate quotes.',
                    style: tt.bodySmall?.copyWith(color: AppColors.goldDeep),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(SolarPalette c, TextTheme tt) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _filters.map((f) {
          final isActive = _activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isActive,
              onSelected: (val) => setState(() => _activeFilter = f),
              labelStyle: tt.labelMedium?.copyWith(
                color: isActive ? c.onPrimary : c.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _vendorCard({
    required SolarPalette c,
    required TextTheme tt,
    required String name,
    required String initials,
    required String rating,
    required String reviews,
    required String distance,
    required String speciality,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: c.primarySoft,
                radius: 24,
                child: Text(initials,
                    style: TextStyle(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700, color: c.onSurface)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 15),
                        const SizedBox(width: 4),
                        Text('$rating ($reviews reviews)',
                            style: tt.bodySmall?.copyWith(
                                color: AppColors.primaryDeep,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text('• $distance',
                            style: tt.bodySmall
                                ?.copyWith(color: c.onSurfaceMuted)),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.primarySoft.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(speciality,
                        style: tt.labelSmall?.copyWith(color: c.onSurfaceMuted)),
                  ),
                  const SizedBox(height: 8),
                  Text('From $price',
                      style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700, color: c.onSurface)),
                ],
              ),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Quote requested! Vendor will contact you soon.')),
                  );
                },
                child: const Text('Get Quote'),
              ),
            ],
          )
        ],
      ),
    );
  }
}