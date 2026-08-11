import '../scan/setup_scan_screen.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/user_session.dart';
import '../../services/location_service.dart';
import '../../services/pvgis_service.dart';
import '../../services/subsidy_service.dart';
import '../../services/open_meteo_service.dart';
import '../../services/link_opener.dart';
import '../../widgets/notification_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _howItWorksController;

  @override
  void initState() {
    super.initState();
    _howItWorksController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _playAnimationSequence();
    _loadLiveData();
  }

  void _playAnimationSequence() async {
    while (mounted) {
      await _howItWorksController.forward(from: 0.0);
      if (mounted) await Future.delayed(const Duration(seconds: 15));
    }
  }

  @override
  void dispose() {
    _howItWorksController.dispose();
    super.dispose();
  }

  // ── Live solar data (PVGIS + Open-Meteo + location) ───────────────────────
  bool _liveLoading = true;
  bool _liveReady = false;
  double? _liveSavedMonthly;
  double? _livePaybackYears;
  double? _liveCo2T;
  double? _liveWm2;
  bool _liveIsDay = true;
  String _liveCity = '';
  String _liveCaption = 'Fetching live solar data…';

  final _pvgis = PvgisService();
  final _subsidy = SubsidyService();
  final _location = LocationService();
  final _openMeteo = OpenMeteoService();

  // Defaults so the dashboard always shows real numbers on first launch.
  static const double _kDefaultBill = 1200; // ₹/month assumed until a scan
  static const double _kDefaultTariff = 7.0; // ₹/kWh assumed until a scan

  Future<void> _loadLiveData() async {
    setState(() => _liveLoading = true);
    try {
      await _subsidy.init();
      double lat = UserSession.instance.lat ?? 0;
      double lon = UserSession.instance.lon ?? 0;
      String? stateKey = UserSession.instance.stateKey;
      if (lat == 0 && lon == 0) {
        final loc = await _location.getCurrentLatLon();
        lat = loc.lat;
        lon = loc.lon;
      }
      final placemark = await _location.reverseGeocode(lat, lon);
      final city = placemark?.city;
      stateKey ??= placemark?.stateKey;

      // 1) PVGIS real irradiance for the coordinates.
      final irr = await _pvgis.fetchIrradiance(lat, lon, stateKey);
      // 2) Open-Meteo live shortwave radiation right now.
      final live = await _openMeteo.fetchCurrentSolar(lat, lon);

      final tariff = UserSession.instance.avgTariffInr ?? _kDefaultTariff;
      final bill = UserSession.instance.monthlyBillInr ?? _kDefaultBill;
      final monthlyKwh = bill / tariff;
      final systemKw = monthlyKwh / (irr.peakSunHours * 30);
      final annualKwh = systemKw * irr.annualKwhPerKw;
      final sub = _subsidy.calculate(
        systemKw: systemKw,
        stateName: stateKey ?? 'maharashtra',
        annualKwh: annualKwh,
        avgTariff: tariff,
      );
      if (!mounted) return;
      setState(() {
        _liveSavedMonthly = bill * 0.72;
        _livePaybackYears = sub.paybackYears;
        _liveCo2T = annualKwh * 0.82 / 1000;
        _liveWm2 = live.shortwaveRadiation;
        _liveIsDay = live.isDay;
        _liveCity = city ?? '';
        _liveReady = true;
        _liveCaption = irr.isFallback
            ? 'Live • ${irr.peakSunHours} sun hrs/day (regional estimate)'
            : 'Live • ${irr.peakSunHours} sun hrs/day from PVGIS';
        if (_liveCity.isNotEmpty) {
          _liveCaption =
              'Live • $_liveCity • ${_liveCaption.replaceFirst('Live • ', '')}';
        }
      });
    } catch (_) {
      // Keep the idle placeholders — the scan continues to work regardless.
    } finally {
      if (mounted) setState(() => _liveLoading = false);
    }
  }

  List<Map<String, dynamic>> _buildQuickStats(SolarPalette c) {
    if (!_liveReady) {
      return const [
        {"label": "Live Irradiance", "value": "—", "tone": "primary"},
        {"label": "Avg. Monthly Savings", "value": "—", "tone": "ink"},
        {"label": "Typical Payback", "value": "—", "tone": "ink"},
        {"label": "CO₂ Saved", "value": "—", "tone": "success"},
      ];
    }
    final wm2 = _liveWm2;
    final wm2Str = wm2 == null
        ? '—'
        : (_liveIsDay ? '${wm2.toStringAsFixed(0)} W/m²' : 'Night ☾');
    return [
      {"label": "Live Irradiance", "value": wm2Str, "tone": "primary"},
      {
        "label": "Avg. Monthly Savings",
        "value": "₹${_liveSavedMonthly!.toStringAsFixed(0)}",
        "tone": "ink",
      },
      {
        "label": "Typical Payback",
        "value": "${_livePaybackYears!.toStringAsFixed(1)} yrs",
        "tone": "ink",
      },
      {
        "label": "CO₂ Saved",
        "value": "${_liveCo2T!.toStringAsFixed(1)} T/yr",
        "tone": "success",
      },
    ];
  }

  final List<Map<String, dynamic>> _howItWorks = [
    {
      "icon": Icons.camera_alt_outlined,
      "label": "Scan Roof",
      "step": "01",
      "route": "/scan/setup",
    },
    {
      "icon": Icons.solar_power_outlined,
      "label": "Place Panels",
      "step": "02",
      "route": "/scan/setup",
    },
    {
      "icon": Icons.bar_chart_outlined,
      "label": "Get Report",
      "step": "03",
      "route": "/report",
    },
  ];

  final List<Map<String, dynamic>> _schemeLinks = [
    {
      "title": "PM Surya Ghar Portal",
      "subtitle": "Apply for the central subsidy (up to ₹78,000)",
      "url": "https://pmsuryaghar.gov.in",
      "icon": Icons.account_balance_outlined,
    },
    {
      "title": "National Rooftop Portal",
      "subtitle": "Find installers & track DISCOM approvals",
      "url": "https://solarrooftop.gov.in",
      "icon": Icons.roofing_outlined,
    },
    {
      "title": "MNRE — New & Renewable Energy",
      "subtitle": "ALMM-approved panel list & policy updates",
      "url": "https://mnre.gov.in",
      "icon": Icons.verified_outlined,
    },
  ];

  TextTheme get _tt => Theme.of(context).textTheme;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(c),
              const SizedBox(height: 20),
              _buildStatsScroll(c),
              const SizedBox(height: 20),
              _buildHeroCta(c),
              const SizedBox(height: 28),
              _sectionTitle('How It Works'),
              _buildHowItWorksScroll(c),
              const SizedBox(height: 28),
              _sectionTitle('Subsidy & Scheme Links'),
              _buildSchemeLinks(c),
              const SizedBox(height: 28),
              _sectionTitle('Recent Scans'),
              _buildEmptyState(c),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(c),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: _tt.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.5,
          color: AppColors.of(context).onSurface,
        ),
      ),
    );
  }

  Widget _buildHeader(SolarPalette c) {
    final name = UserSession.instance.name;
    final greeting = name == null || name.isEmpty
        ? 'Welcome back'
        : 'Good morning, $name';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: _tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Plan your solar installation today',
                style: _tt.bodyMedium?.copyWith(color: c.onSurfaceMuted),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showNotifications,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: c.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_none, color: c.onSurface, size: 21),
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showNotificationsSheet(context);
  }

  Widget _buildStatsScroll(SolarPalette c) {
    final stats = _buildQuickStats(c);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(stats.length, (i) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: i == stats.length - 1 ? 0 : 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          stats[i]["label"],
                          style: _tt.labelSmall?.copyWith(
                            color: c.onSurfaceMuted,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          stats[i]["value"],
                          style: _tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _toneColor(stats[i]["tone"], c),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _liveReady ? AppColors.successSoft : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _liveLoading && !_liveReady
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _liveReady ? Icons.circle : Icons.circle_outlined,
                            size: 8,
                            color: _liveReady
                                ? AppColors.success
                                : c.onSurfaceMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _liveReady ? 'LIVE' : 'IDLE',
                            style: _tt.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _liveCaption,
                  style: _tt.bodySmall?.copyWith(color: c.onSurfaceMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_liveReady)
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/scan/setup'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Set up'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _toneColor(String tone, SolarPalette c) => switch (tone) {
    'primary' => AppColors.primaryDeep,
    'success' => AppColors.success,
    _ => c.onSurface,
  };

  Widget _buildHeroCta(SolarPalette c) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SetupScanScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutQuart,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFC2410C)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start AR Scan',
                      style: _tt.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Point camera at your rooftop',
                      style: _tt.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open AR Camera',
                    style: _tt.labelLarge?.copyWith(
                      color: AppColors.goldDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: AppColors.goldDeep,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksScroll(SolarPalette c) {
    return SizedBox(
      height: 140,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_howItWorks.length, (i) {
            double start = i * 0.25;
            return Expanded(
              child: AnimatedBuilder(
                animation: _howItWorksController,
                builder: (context, child) {
                  double curve = Curves.easeInOutSine.transform(
                    (_howItWorksController.value >= start &&
                            _howItWorksController.value <= start + 0.3)
                        ? (_howItWorksController.value - start) / 0.3
                        : 0.0,
                  );
                  double scale =
                      1.0 + (curve <= 0.5 ? curve * 0.1 : (1 - curve) * 0.1);
                  return Transform.scale(
                    scale: scale,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              _howItWorks[i]['route'] as String,
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15 + curve * 0.35,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: curve * 0.16,
                                    ),
                                    blurRadius: 12 + (curve * 8),
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: c.primarySoft,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      _howItWorks[i]["icon"],
                                      color: AppColors.primaryDeep,
                                      size: 20,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _howItWorks[i]["label"],
                                    textAlign: TextAlign.center,
                                    style: _tt.labelSmall?.copyWith(
                                      color: c.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _howItWorks[i]["step"],
                                    style: TextStyle(
                                      color: c.primary.withValues(alpha: 0.7),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (i < _howItWorks.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _howItWorksController,
                              builder: (context, child) => Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: c.primary.withValues(
                                  alpha: curve > 0.1 ? 0.9 : 0.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSchemeLinks(SolarPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(_schemeLinks.length, (i) {
          final link = _schemeLinks[i];
          return Container(
            margin: EdgeInsets.only(
              bottom: i == _schemeLinks.length - 1 ? 0 : 10,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: ListTile(
              onTap: () => openExternalLink(
                link['url'] as String,
                context: context,
                label: link['title'] as String,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  link['icon'] as IconData,
                  color: AppColors.primaryDeep,
                  size: 20,
                ),
              ),
              title: Text(
                link['title'] as String,
                style: _tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.onSurface,
                ),
              ),
              subtitle: Text(
                link['subtitle'] as String,
                style: _tt.bodySmall?.copyWith(color: c.onSurfaceMuted),
              ),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: AppColors.primaryDeep,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(SolarPalette c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.wb_sunny_outlined,
              color: AppColors.primaryDeep,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No scans yet',
            style: _tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start your first AR scan to see solar potential',
            textAlign: TextAlign.center,
            style: _tt.bodyMedium?.copyWith(color: c.onSurfaceMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/scan/setup'),
            child: const Text('Start Your First Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(SolarPalette c) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) Navigator.pushNamed(context, '/scan/setup');
        if (index == 2) Navigator.pushNamed(context, '/providers');
        if (index == 3) Navigator.pushNamed(context, '/report');
        if (index == 4) Navigator.pushNamed(context, '/profile');
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.camera), label: 'Scan'),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_ind),
          label: 'Subsidies & Pros',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
