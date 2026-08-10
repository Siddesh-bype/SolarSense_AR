import '../scan/setup_scan_screen.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/user_session.dart';

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
        vsync: this, duration: const Duration(milliseconds: 3000));
    _playAnimationSequence();
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

  final List<Map<String, dynamic>> _quickStats = [
    {"label": "Avg. Monthly Savings", "value": "₹1,800", "tone": "primary"},
    {"label": "Typical Payback", "value": "4.2 yrs", "tone": "ink"},
    {"label": "CO₂ Saved", "value": "4.5 T/yr", "tone": "success"},
  ];

  final List<Map<String, dynamic>> _howItWorks = [
    {"icon": Icons.camera_alt_outlined, "label": "Scan Roof", "step": "01"},
    {"icon": Icons.solar_power_outlined, "label": "Place Panels", "step": "02"},
    {"icon": Icons.bar_chart_outlined, "label": "Get Report", "step": "03"},
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _NotificationSheet(),
    );
  }

  Widget _buildStatsScroll(SolarPalette c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(_quickStats.length, (i) {
            return Expanded(
              child: Container(
                margin:
                    EdgeInsets.only(right: i == _quickStats.length - 1 ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                      _quickStats[i]["label"],
                      style: _tt.labelSmall?.copyWith(
                        color: c.onSurfaceMuted,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _quickStats[i]["value"],
                      style: _tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: _toneColor(_quickStats[i]["tone"], c),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
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
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              SetupScanScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF0B6B4F)],
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
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: 32),
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
                  const Icon(Icons.arrow_forward,
                      color: AppColors.goldDeep, size: 18),
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
                  double scale = 1.0 + (curve <= 0.5 ? curve * 0.1 : (1 - curve) * 0.1);
                  return Transform.scale(
                    scale: scale,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15 + curve * 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: curve * 0.16),
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
                                  child: Icon(_howItWorks[i]["icon"],
                                      color: AppColors.primaryDeep, size: 20),
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
                        if (i < _howItWorks.length - 1)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _howItWorksController,
                              builder: (context, child) => Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: c.primary
                                    .withValues(alpha: curve > 0.1 ? 0.9 : 0.2),
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
            child: const Icon(Icons.wb_sunny_outlined,
                color: AppColors.primaryDeep, size: 32),
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
            icon: Icon(Icons.assignment_ind), label: 'Subsidies & Pros'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

// ─── Notification Bottom Sheet ─────────────────────────────────────────────
class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  List<_Notif> _buildNotifs() {
    final bill = UserSession.instance.monthlyBillInr;
    final billStr = bill == null ? 'your current bill' : '₹${bill.toStringAsFixed(0)}';
    return [
      const _Notif(Icons.wb_sunny_outlined, 'Solar Tip',
          'Today is sunny — ideal for running your high-power appliances to save on bills.',
          '2 min ago', true),
      const _Notif(Icons.account_balance_outlined, 'PM Surya Ghar',
          'New subsidy window open: apply before 30 April to claim ₹78,000.',
          '1 hr ago', true),
      const _Notif(Icons.bar_chart_outlined, 'Report Ready',
          'Your last AR scan analysis has been processed. Tap to view.',
          '3 hrs ago', false),
      _Notif(Icons.bolt_outlined, 'Energy Alert',
          'Your estimated monthly bill of $billStr can be reduced by up to 72% with solar.',
          'Yesterday', false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final notifs = _buildNotifs();
    final c = AppColors.of(context);
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifications',
                      style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700, color: c.onSurface)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('2 new',
                        style: TextStyle(
                            color: AppColors.primaryDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifs.length,
                separatorBuilder: (context, index) =>
                    Divider(indent: 72, endIndent: 16, height: 1),
                itemBuilder: (_, i) {
                  final n = notifs[i];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (n.isNew ? c.primarySoft : c.surfaceMuted),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(n.icon,
                          color: n.isNew ? AppColors.primaryDeep : c.onSurfaceMuted,
                          size: 22),
                    ),
                    title: Row(
                      children: [
                        Text(n.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    n.isNew ? FontWeight.w700 : FontWeight.w600,
                                color: c.onSurface)),
                        if (n.isNew) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ]
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(n.body,
                            style: TextStyle(
                                fontSize: 13,
                                color: c.onSurfaceMuted,
                                height: 1.4)),
                        const SizedBox(height: 4),
                        Text(
                          n.time,
                          style: TextStyle(
                              fontSize: 11,
                              color: c.primary.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    tileColor:
                        n.isNew ? c.primarySoft.withValues(alpha: 0.35) : Colors.transparent,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notif {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final bool isNew;
  const _Notif(this.icon, this.title, this.body, this.time, this.isNew);
}