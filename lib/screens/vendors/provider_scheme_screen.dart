import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enriched_scan_result.dart';

class ProviderSchemeScreen extends StatelessWidget {
  const ProviderSchemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Subsidies & Providers', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PM Surya Ghar Highlight Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFFFB690)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance, color: Colors.white, size: 24)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text("PM Surya Ghar Yojana", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Claim up to ₹78,000 in central subsidies by installing rooftop solar through empanelled vendors.", style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("View Subsidy Slab", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("Top Certified Providers", style: TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            ),
            
            // Brand cards — populated from EnrichedScanResponse if available
            _buildDynamicBrandList(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  /// Renders brand cards from route args (EnrichedScanResponse) or static fallback.
  Widget _buildDynamicBrandList(BuildContext context) {
    final data = ModalRoute.of(context)?.settings.arguments as EnrichedScanResult?;
    final brands = data?.brandRecommendations;

    if (brands != null && brands.isNotEmpty) {
      return Column(
        children: brands.map((b) => _buildBrandCard(
          title: b.name,
          rating: b.rating.toStringAsFixed(1),
          efficiency: '${b.bestEfficiencyPct}% efficiency',
          priceRange: '₹${b.pricePerWattMin}–₹${b.pricePerWattMax}/W',
          reason: b.reason,
          rank: b.rank,
        )).toList(),
      );
    }

    // Static fallback when no data passed
    return Column(
      children: [
        _buildBrandCard(title: 'Tata Power Solar', rating: '9.2', efficiency: '22.1% efficiency', priceRange: '₹29–₹34/W', reason: 'Trusted brand with widest service network.', rank: 1),
        _buildBrandCard(title: 'Waaree Energies', rating: '8.8', efficiency: '22.0% efficiency', priceRange: '₹25–₹34/W', reason: "India's largest exporter — best value.", rank: 2),
        _buildBrandCard(title: 'Loom Solar', rating: '8.3', efficiency: '21.8% efficiency', priceRange: '₹26–₹32/W', reason: 'D2C brand with transparent online pricing.', rank: 3),
      ],
    );
  }

  Widget _buildBrandCard({
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Center(
              child: Text('#$rank', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.border, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(efficiency, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(priceRange, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border, width: 1))),
      child: BottomNavigationBar(
        currentIndex: 2,
        backgroundColor: Colors.white,
        elevation: 0,
        unselectedFontSize: 11,
        selectedFontSize: 11,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/home');
          if (index == 1) Navigator.pushReplacementNamed(context, '/scan/setup');
          if (index == 3) Navigator.pushReplacementNamed(context, '/report');
          if (index == 4) Navigator.pushReplacementNamed(context, '/profile');
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_ind), label: 'Subsidies & Pros'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
