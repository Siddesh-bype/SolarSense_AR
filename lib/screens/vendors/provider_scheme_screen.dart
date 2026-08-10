import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enriched_scan_result.dart';

class ProviderSchemeScreen extends StatelessWidget {
  const ProviderSchemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('Subsidies & Providers',
            style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: c.onSurface)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF047857),
                    Color(0xFF059669),
                    Color(0xFF0B6B4F),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance,
                            color: AppColors.goldDeep, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "PM Surya Ghar Yojana",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Claim up to ₹78,000 in central subsidies by installing rooftop solar through empanelled vendors.",
                    style:
                        TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("View Subsidy Slab",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_forward,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Top Certified Providers",
                style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: c.onSurface),
              ),
            ),
            _buildDynamicBrandList(context, c, tt),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, c, tt),
    );
  }

  Widget _buildDynamicBrandList(
      BuildContext context, SolarPalette c, TextTheme tt) {
    final data = ModalRoute.of(context)?.settings.arguments as EnrichedScanResult?;
    final brands = data?.brandRecommendations;

    if (brands != null && brands.isNotEmpty) {
      return Column(
        children: brands.map((b) => _brandCard(
              c: c,
              tt: tt,
              title: b.name,
              rating: b.rating.toStringAsFixed(1),
              efficiency: '${b.bestEfficiencyPct}% efficiency',
              priceRange: '₹${b.pricePerWattMin}–₹${b.pricePerWattMax}/W',
              reason: b.reason,
              rank: b.rank,
            )).toList(),
      );
    }

    return Column(
      children: [
        _brandCard(
            c: c, tt: tt, title: 'Tata Power Solar', rating: '9.2',
            efficiency: '22.1% efficiency', priceRange: '₹29–₹34/W',
            reason: 'Trusted brand with widest service network.', rank: 1),
        _brandCard(
            c: c, tt: tt, title: 'Waaree Energies', rating: '8.8',
            efficiency: '22.0% efficiency', priceRange: '₹25–₹34/W',
            reason: "India's largest exporter — best value.", rank: 2),
        _brandCard(
            c: c, tt: tt, title: 'Loom Solar', rating: '8.3',
            efficiency: '21.8% efficiency', priceRange: '₹26–₹32/W',
            reason: 'D2C brand with transparent online pricing.', rank: 3),
      ],
    );
  }

  Widget _brandCard({
    required SolarPalette c,
    required TextTheme tt,
    required String title,
    required String rating,
    required String efficiency,
    required String priceRange,
    required String reason,
    required int rank,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700, color: c.onSurface)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(rating,
                        style: tt.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                            color: c.border, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(efficiency,
                        style: tt.bodySmall?.copyWith(color: c.onSurfaceMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(reason,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(priceRange,
              style: tt.labelSmall?.copyWith(
                  color: AppColors.primaryDeep, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(
      BuildContext context, SolarPalette c, TextTheme tt) {
    return BottomNavigationBar(
      currentIndex: 2,
      unselectedLabelStyle: tt.labelSmall,
      selectedLabelStyle: tt.labelSmall,
      onTap: (index) {
        if (index == 0) Navigator.pushReplacementNamed(context, '/home');
        if (index == 1) Navigator.pushReplacementNamed(context, '/scan/setup');
        if (index == 3) Navigator.pushReplacementNamed(context, '/report');
        if (index == 4) Navigator.pushReplacementNamed(context, '/profile');
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Scan'),
        BottomNavigationBarItem(
            icon: Icon(Icons.assignment_ind), label: 'Subsidies & Pros'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}