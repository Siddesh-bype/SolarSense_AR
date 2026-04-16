import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enriched_scan_result.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/solar_panel_3d.dart';

class FinancialReportScreen extends StatelessWidget {
  const FinancialReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Receive EnrichedScanResult passed from analysis_loading_screen
    final data = ModalRoute.of(context)?.settings.arguments as EnrichedScanResult?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Solar Report'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.download_outlined)),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 140,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryHero(context, data),
                const SizedBox(height: 24),
                Text('Financial Summary', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildFinancialGrid(context, data),
                const SizedBox(height: 24),
                _buildMonthlySavingsCard(context, data),
                const SizedBox(height: 24),
                _buildProjectionCard(context, data),
                const SizedBox(height: 24),
                _buildEnvironmentalCard(context, data),
                const SizedBox(height: 24),
                _buildSubsidyCard(context, data),
              ],
            ),
          ),
          _buildStickyBottomBar(context, data),
        ],
      ),
    );
  }

  Widget _buildSummaryHero(BuildContext context, EnrichedScanResult? data) {
    final systemKw = data?.systemSizeKw ?? 3.0;
    final annualKwh = data?.annualKwh ?? 4927.5;
    final stateLabel = data != null
        ? '${data.stateDisplayName} • ${data.pvgisFallback ? "Estimated Data" : "Live Data"}'
        : 'Pune, MH • Generated Today';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Size: ${systemKw.toStringAsFixed(1)} kW',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Annual Generation: ${annualKwh.toStringAsFixed(0)} kWh',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(stateLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: SolarPanel3DWidget(panelCount: 4, size: 80),
              )
            ],
          ),
          // PVGIS fallback disclaimer
          if (data?.pvgisFallback == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline, color: Colors.white70, size: 14),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Solar data estimated (location service unavailable)',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFinancialGrid(BuildContext context, EnrichedScanResult? data) {
    final grossCost = data?.estimatedCost ?? 225000;
    final totalSubsidy = data?.totalSubsidy ?? 78000;
    final netCost = data?.netCost ?? 147000;
    final payback = data?.paybackYears ?? 4.2;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildGridCard('Gross Cost', '₹${_fmt(grossCost)}', AppColors.textPrimary),
        _buildGridCard('Govt. Subsidy', '₹${_fmt(totalSubsidy)}', AppColors.success),
        _buildGridCard('Net Cost', '₹${_fmt(netCost)}', AppColors.primary),
        _buildGridCard('Payback', '${payback.toStringAsFixed(1)} years', AppColors.textPrimary),
      ],
    );
  }

  Widget _buildGridCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMonthlySavingsCard(BuildContext context, EnrichedScanResult? data) {
    final annualSavings = data?.annualSavingsInr ?? 22200.0;
    final monthlySavings = (annualSavings / 12).toInt();
    final billBefore = monthlySavings + 1350;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Bill Savings: ₹$monthlySavings', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildBarChartRow('Before', billBefore, Colors.redAccent, 1.0),
          const SizedBox(height: 16),
          _buildBarChartRow('After', 1350, AppColors.success, 1350 / billBefore),
        ],
      ),
    );
  }

  Widget _buildBarChartRow(String label, int amount, Color color, double factor) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Expanded(
          child: Stack(
            children: [
              Container(height: 24, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12))),
              FractionallySizedBox(
                widthFactor: factor.clamp(0.05, 1.0),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('₹$amount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProjectionCard(BuildContext context, EnrichedScanResult? data) {
    final annualSavings = data?.annualSavingsInr ?? 22200.0;
    final savings25yr = annualSavings * 25 / 100000;

    final spots = List.generate(6, (i) {
      final yr = i * 5.0;
      return FlSpot(yr, annualSavings * yr / 100000);
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total 25-Year Savings', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          Text('₹${savings25yr.toStringAsFixed(2)} Lakh', style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) => Text('Yr ${value.toInt()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      interval: 5,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEnvironmentalCard(BuildContext context, EnrichedScanResult? data) {
    final annualKwh = data?.annualKwh ?? 4927.5;
    final co2Tonnes = annualKwh * 0.000820;
    final trees = (co2Tonnes * 16).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'CO₂ Avoided: ${co2Tonnes.toStringAsFixed(1)} tonnes/year',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Equivalent to planting $trees trees annually', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(8, (index) => const Icon(Icons.park, color: AppColors.success, size: 30)),
          )
        ],
      ),
    );
  }

  Widget _buildSubsidyCard(BuildContext context, EnrichedScanResult? data) {
    final totalSubsidy = data?.totalSubsidy ?? 78000;
    final stateDisplay = data?.stateDisplayName ?? 'Maharashtra';
    final centralSubsidy = data?.centralSubsidy ?? 78000;
    final stateSubsidy = data?.stateSubsidy ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text('PM Surya Ghar Yojana', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text('Total Subsidy: ₹${_fmt(totalSubsidy)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Central: ₹${_fmt(centralSubsidy)}${stateSubsidy > 0 ? ' + $stateDisplay: ₹${_fmt(stateSubsidy)}' : ''}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text('Apply Now'),
          )
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, EnrichedScanResult? data) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).padding.bottom == 0 ? 16 : MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {},
              child: const Text('Download PDF Report'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              // Pass the brand list to the vendors screen via route args
              onPressed: () => Navigator.pushNamed(context, '/vendors', arguments: data),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border), foregroundColor: AppColors.textPrimary),
              child: const Text('Find Solar Vendors Near Me'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int value) {
    final s = value.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write(',');
      result.write(s[i]);
    }
    return result.toString();
  }
}
