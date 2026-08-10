import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enriched_scan_result.dart';
import '../../services/location_service.dart';
import '../../services/scan_orchestrator.dart';
import '../../services/user_session.dart';

class AnalysisLoadingScreen extends StatefulWidget {
  const AnalysisLoadingScreen({super.key});
  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _progress = 0;
  int _currentStep = 0;
  bool _hasError = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _steps = [
    {"text": "Fetching solar irradiance data...", "icon": Icons.wb_sunny, "color": AppColors.gold},
    {"text": "Calculating government subsidies...", "icon": Icons.account_balance, "color": AppColors.gold},
    {"text": "Finding best solar providers...", "icon": Icons.storefront, "color": AppColors.gold},
    {"text": "Building your report...", "icon": Icons.check_circle, "color": AppColors.gold},
  ];

  final _orchestrator = ScanOrchestrator();
  final _locationService = LocationService();
  final _session = UserSession.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAnalysis());
  }

  Future<void> _runAnalysis() async {
    setState(() { _hasError = false; _errorMessage = null; });
    try {
      final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? const {};
      final panelCount = (args['panelCount'] as num?)?.toInt() ?? 0;
      final systemKw = (args['systemKw'] as num?)?.toDouble() ?? 0.0;
      final areaSqm = (args['areaSqm'] as num?)?.toDouble() ?? 0.0;

      if (panelCount <= 0 || systemKw <= 0 || areaSqm <= 0) {
        throw StateError('AR scan did not produce valid panel layout. Please rescan.');
      }
      if (_session.stateKey == null || _session.monthlyBillInr == null) {
        throw StateError('Missing user setup data. Please complete the setup form.');
      }

      _setStep(0, 0.05);
      await _orchestrator.init();
      double lat = _session.lat ?? 0, lon = _session.lon ?? 0;
      if (lat == 0 && lon == 0) {
        final latLon = await _locationService.getCurrentLatLon();
        lat = latLon.lat; lon = latLon.lon;
      }
      _setStep(0, 0.20);

      _setStep(1, 0.35);

      final avgTariff = _session.avgTariffInr ?? 0;
      final roofType = _session.roofType;
      final usableRatio = switch (roofType) {
        'Flat' => 0.78,
        'Sloped' => 0.60,
        'Mixed' => 0.68,
        _ => 0.70,
      };

      final userAreaM2 = _session.roofAreaSqFt != null
          ? _session.roofAreaSqFt! * 0.092903
          : null;
      final effectiveTotalArea =
          (userAreaM2 != null && userAreaM2 < areaSqm) ? userAreaM2 : areaSqm;
      final usableAreaM2 = effectiveTotalArea * usableRatio;

      final monthlyBill = _session.monthlyBillInr ?? 0;
      final priceSensitivity = monthlyBill < 1500
          ? 'budget'
          : (monthlyBill > 4000 ? 'premium' : 'mid');

      EnrichedScanResult result = await _orchestrator.enrichScan(
        lat: lat,
        lon: lon,
        systemKw: systemKw,
        stateName: _session.stateKey!,
        totalAreaM2: effectiveTotalArea,
        usableAreaM2: usableAreaM2,
        panelCount: panelCount,
        avgTariff: avgTariff,
        priceSensitivity: priceSensitivity,
        cameraFrame: args['cameraFrame'] as Uint8List?,
        headingDeg: args['headingDeg'] as double?,
      );

      if (monthlyBill > 0) {
        final maxAnnualSavings = monthlyBill * 12.0;
        if (result.annualSavingsInr > maxAnnualSavings) {
          result = _capSavings(result, maxAnnualSavings);
        }
      }

      _setStep(2, 0.70);
      await Future.delayed(const Duration(milliseconds: 300));
      _setStep(3, 0.88);
      await Future.delayed(const Duration(milliseconds: 500));

      for (int i = 89; i <= 100; i++) {
        await Future.delayed(const Duration(milliseconds: 25));
        if (mounted) setState(() => _progress = i / 100);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/report', arguments: result);
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMessage = e.toString(); });
    }
  }

  void _setStep(int step, double progress) {
    if (!mounted) return;
    setState(() { _currentStep = step; _progress = progress; });
  }

  EnrichedScanResult _capSavings(EnrichedScanResult r, double maxSavings) {
    final capped = double.parse(maxSavings.toStringAsFixed(2));
    final newPayback = capped > 0
        ? double.parse((r.netCost / capped).toStringAsFixed(2))
        : r.paybackYears;
    return r.copyWith(annualSavingsInr: capped, paybackYears: newPayback);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    final deep = AppColors.goldDeep;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1B16),
      body: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.4, child: CustomPaint(painter: AbstractParticlePainter()))),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0B1B16),
                    const Color(0xFF123A2C).withValues(alpha: 0.55),
                    const Color(0xFF0B1B16),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.solar_power, color: AppColors.primaryDeep, size: 28),
                          const SizedBox(width: 8),
                          Text('SOLARMITRA',
                              style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                  fontSize: 18,
                                  letterSpacing: 1.2)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _hasError
                        ? _buildErrorView(gold, deep)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 250,
                                height: 250,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 220,
                                      height: 220,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.primaryDeep.withValues(alpha: 0.45), width: 3),
                                      ),
                                    ),
                                    AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) => Transform.rotate(
                                        angle: _controller.value * 2 * 3.14159,
                                        child: Container(
                                          width: 220,
                                          height: 220,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border(
                                              top: BorderSide(color: gold, width: 3),
                                              right: BorderSide(color: AppColors.primaryDeep, width: 3),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 150,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: gold.withValues(alpha: 0.06),
                                        boxShadow: [
                                          BoxShadow(
                                              color: AppColors.primaryDeep.withValues(alpha: 0.55),
                                              blurRadius: 50),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.light_mode, color: AppColors.gold, size: 56),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text('${(_progress * 100).toInt()}',
                                                style: GoogleFonts.manrope(
                                                    fontSize: 48,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: -2)),
                                            Text('%',
                                                style: GoogleFonts.manrope(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white60)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 48),
                              Column(
                                children: List.generate(_steps.length, (index) {
                                  final isActive = index == _currentStep;
                                  final isPast = index < _currentStep;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 300),
                                      opacity: isActive ? 1.0 : (isPast ? 0.4 : 0.2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_steps[index]["icon"],
                                              color: isActive
                                                  ? _steps[index]["color"]
                                                  : Colors.white,
                                              size: isActive ? 20 : 14),
                                          const SizedBox(width: 12),
                                          Text(_steps[index]["text"],
                                              style: isActive
                                                  ? GoogleFonts.manrope(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white)
                                                  : GoogleFonts.inter(
                                                      fontSize: 14, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF047857), AppColors.primaryDeep, Color(0xFFFBBF24)],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                      color: gold.withValues(alpha: 0.35), blurRadius: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: gold.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.account_balance, color: AppColors.gold, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PM Surya Ghar Yojana',
                                      style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "We're verifying your roof area against central government subsidy brackets for maximum savings.",
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: Colors.white60, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(Color gold, Color deep) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
        const SizedBox(height: 16),
        Text('Analysis failed',
            style: GoogleFonts.manrope(
                fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage ?? 'Please check your connection and try again.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white60),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _runAnalysis,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDeep,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class AbstractParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.gold.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.15), 3, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.45), 4, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.75), 2, paint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.25), 3.5, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.85), 2.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! AbstractParticlePainter;
}