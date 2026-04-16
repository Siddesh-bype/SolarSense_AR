import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class VendorConnectScreen extends StatefulWidget {
  const VendorConnectScreen({super.key});

  @override
  State<VendorConnectScreen> createState() => _VendorConnectScreenState();
}

class _VendorConnectScreenState extends State<VendorConnectScreen> {
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Installers'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Solar Installers Near You',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Pune, Maharashtra', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          _buildFilterRow(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildVendorCard(
                  name: 'Surya Power Solutions',
                  initials: 'SP',
                  rating: '4.8',
                  reviews: '42',
                  distance: '1.2 km away',
                  speciality: 'Residential Solar',
                  price: '₹43,000/kW',
                ),
                const SizedBox(height: 16),
                _buildVendorCard(
                  name: 'Green Energy Pros',
                  initials: 'GE',
                  rating: '4.7',
                  reviews: '12',
                  distance: '2.3 km away',
                  speciality: 'Premium Setup',
                  price: '₹45,000/kW',
                ),
                const SizedBox(height: 16),
                _buildVendorCard(
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
              left: 16, right: 16, top: 16, 
              bottom: MediaQuery.of(context).padding.bottom == 0 ? 16 : MediaQuery.of(context).padding.bottom,
            ),
            color: Colors.blue.shade50,
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your report has been shared securely with the selected vendors to provide accurate quotes.',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = ['All', 'Highest Rated', 'Nearest', 'Best Price'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: filters.map((f) {
          final isActive = _activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f),
              selected: isActive,
              onSelected: (val) => setState(() => _activeFilter = f),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: isActive ? Colors.white : AppColors.textPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isActive ? AppColors.primary : AppColors.border),
              ),
              backgroundColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVendorCard({
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                radius: 24,
                child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('$rating ($reviews reviews)', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text('• $distance', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(speciality, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 8),
                  Text('From $price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quote requested! Vendor will contact you soon.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 40),
                ),
                child: const Text('Get Quote'),
              )
            ],
          )
        ],
      ),
    );
  }
}
