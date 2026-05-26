import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enriched_scan_result.dart';
import '../../services/report_api_service.dart';
import '../../services/user_session.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/solar_panel_3d.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  bool _downloading = false;
  String? _lastPdfPath;

  @override
  Widget build(BuildContext context) {
    final data = ModalRoute.of(context)?.settings.arguments as EnrichedScanResult?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Solar Report'),
        actions: [
          IconButton(
            onPressed: data == null || _downloading ? null : () => _share(data),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            onPressed: data == null || _downloading ? null : () => _download(data),
            icon: _downloading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: data == null ? _buildEmptyState(context) : _buildReport(context, data),
    );
  }

  Future<void> _download(EnrichedScanResult data) async {
    setState(() => _downloading = true);
    try {
      final path = await ReportApiService.instance.generateAndDownload(data);
      _lastPdfPath = path;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report saved'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report failed: ${_friendly(e)}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _share(EnrichedScanResult data) async {
    final path = _lastPdfPath;
    if (path == null) {
      await _download(data);
      final p = _lastPdfPath;
      if (p == null) return;
      await Share.shareXFiles([XFile(p)], text: 'My SolarMitra report');
      return;
    }
    await Share.shareXFiles([XFile(path)], text: 'My SolarMitra report');
  }

  String _friendly(Object e) {
    final s = e.toString();
    return s.length > 100 ? '${s.substring(0, 100)}…' : s;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined, color: AppColors.textSecondary, size: 72),
            const SizedBox(height: 16),
            const Text(
              'No scan data yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Run an AR scan of your roof to see your solar report.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/scan/setup'),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Start AR Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(BuildContext context, EnrichedScanResult data) {
    return Stack(
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
              const SizedBox(height: 16),
              _buildScanMetricsRow(context, data),
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
    );
  }

  Widget _buildSummaryHero(BuildContext context, EnrichedScanResult data) {
    final stateLabel = '${data.stateDisplayName} • ${data.pvgisFallback ? "Estimated Data" : "Live Data"}';

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
                      'System Size: ${data.systemSizeKw.toStringAsFixed(2)} kW',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Annual Generation: ${data.annualKwh.toStringAsFixed(0)} kWh',
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
                child: SolarPanel3DWidget(
                  panelCount: data.panelCount,
                  size: 80,
                  // Tiny hero tile — static render, no shimmer ticker.
                  animate: false,
                ),
              )
            ],
          ),
          if (data.pvgisFallback) ...[
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
                      'Solar irradiance estimated (PVGIS unavailable)',
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

  /// Shows the three values that came directly from the AR scan.
  Widget _buildScanMetricsRow(BuildContext context, EnrichedScanResult data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.view_in_ar, color: AppColors.primary, size: 16),
              SizedBox(width: 6),
              Text('From your AR scan',
                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _scanMetric('Panels', '${data.panelCount}')),
              Expanded(child: _scanMetric('Roof Area', '${data.totalAreaM2.toStringAsFixed(1)} m²')),
              Expanded(child: _scanMetric('Usable', '${data.usableAreaM2.toStringAsFixed(1)} m²')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFinancialGrid(BuildContext context, EnrichedScanResult data) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildGridCard('Gross Cost', '₹${_fmt(data.estimatedCost)}', AppColors.textPrimary),
        _buildGridCard('Govt. Subsidy', '₹${_fmt(data.totalSubsidy)}', AppColors.success),
        _buildGridCard('Net Cost', '₹${_fmt(data.netCost)}', AppColors.primary),
        _buildGridCard('Payback', '${data.paybackYears.toStringAsFixed(1)} years', AppColors.textPrimary),
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

  Widget _buildMonthlySavingsCard(BuildContext context, EnrichedScanResult data) {
    final monthlySavings = (data.annualSavingsInr / 12).round();
    final billBefore = UserSession.instance.monthlyBillInr?.round();
    // Post-solar bill = current bill − savings (floored at 0). Only render if we
    // actually know the user's current bill.
    final billAfter = billBefore == null ? null : (billBefore - monthlySavings).clamp(0, billBefore);

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
          if (billBefore != null && billAfter != null) ...[
            _buildBarChartRow('Before', billBefore, Colors.redAccent, 1.0),
            const SizedBox(height: 16),
            _buildBarChartRow('After', billAfter, AppColors.success, billBefore == 0 ? 0.0 : billAfter / billBefore),
          ] else
            const Text(
              'Enter your current monthly bill in Setup to see a before/after comparison.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
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

  Widget _buildProjectionCard(BuildContext context, EnrichedScanResult data) {
    final savings25yr = data.annualSavingsInr * 25 / 100000;
    final spots = List.generate(6, (i) {
      final yr = i * 5.0;
      return FlSpot(yr, data.annualSavingsInr * yr / 100000);
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

  Widget _buildEnvironmentalCard(BuildContext context, EnrichedScanResult data) {
    final co2Tonnes = data.annualKwh * 0.000820;
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

  Widget _buildSubsidyCard(BuildContext context, EnrichedScanResult data) {
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
          Text('Total Subsidy: ₹${_fmt(data.totalSubsidy)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Central: ₹${_fmt(data.centralSubsidy)}${data.stateSubsidy > 0 ? ' + ${data.stateDisplayName}: ₹${_fmt(data.stateSubsidy)}' : ''}',
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

  Widget _buildStickyBottomBar(BuildContext context, EnrichedScanResult data) {
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
            ElevatedButton.icon(
              onPressed: _downloading ? null : () => _download(data),
              icon: _downloading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_downloading ? 'Generating…' : 'Download PDF Report'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
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
