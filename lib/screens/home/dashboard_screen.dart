import '../scan/setup_scan_screen.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _howItWorksController;

  @override
  void initState() {
    super.initState();
    _howItWorksController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
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
    {"label": "Avg. Monthly Savings", "value": "₹1,800", "color": AppColors.primary},
    {"label": "Typical Payback", "value": "4.2 yrs", "color": AppColors.text},
    {"label": "CO₂ Saved", "value": "4.5 T/yr", "color": AppColors.success},
  ];

  final List<Map<String, dynamic>> _howItWorks = [
    {"icon": Icons.camera_alt_outlined, "label": "Scan Roof", "step": "01"},
    {"icon": Icons.solar_power_outlined, "label": "Place Panels", "step": "02"},
    {"icon": Icons.bar_chart_outlined, "label": "Get Report", "step": "03"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStatsScroll(),
              const SizedBox(height: 20),
              _buildHeroCta(),
              const SizedBox(height: 28),
              _buildSectionTitle('How It Works'),
              _buildHowItWorksScroll(),
              const SizedBox(height: 28),
              _buildSectionTitle('Recent Scans'),
              _buildEmptyState(),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Good morning, Durgesh', style: TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              SizedBox(height: 3),
              Text('Plan your solar installation today', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
          GestureDetector(
            onTap: _showNotifications,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none, color: AppColors.navy, size: 20),
                  Positioned(top: 8, right: 10, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _NotificationSheet(),
    );
  }

  Widget _buildStatsScroll() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(_quickStats.length, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == _quickStats.length - 1 ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.card, 
                  borderRadius: BorderRadius.circular(16), 
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_quickStats[i]["label"], style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(_quickStats[i]["value"], style: TextStyle(color: _quickStats[i]["color"], fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeroCta() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => SetupScanScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)), child: child));
          },
          transitionDuration: const Duration(milliseconds: 600),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Start AR Scan', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                    SizedBox(height: 4),
                    Text('Point camera at your rooftop', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                  ],
                ),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 36)),
                )
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 46,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Open AR Camera', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: AppColors.primary, size: 16),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.5)),
    );
  }

  Widget _buildHowItWorksScroll() {
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
                    (_howItWorksController.value >= start && _howItWorksController.value <= start + 0.3) 
                    ? (_howItWorksController.value - start) / 0.3 
                    : 0.0
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
                            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: curve * 0.2), blurRadius: 12 + (curve * 8), offset: const Offset(0, 4))]),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Center(child: Icon(_howItWorks[i]["icon"], color: AppColors.primary, size: 20))),
                                const Spacer(),
                                Text(_howItWorks[i]["label"], textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navy, fontSize: 11, fontWeight: FontWeight.w600)),
                                Text(_howItWorks[i]["step"], style: TextStyle(color: AppColors.primary.withValues(alpha: 0.60), fontSize: 16, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                        if (i < _howItWorks.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: AnimatedBuilder(
                              animation: _howItWorksController,
                              builder: (context, child) {
                                return Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: AppColors.primary.withValues(alpha: curve > 0.1 ? 0.9 : 0.2),
                                );
                              }
                            ),
                          ),
                      ],
                    ),
                  );
                }
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(
        children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(22)), child: const Center(child: Icon(Icons.wb_sunny_outlined, color: AppColors.primary, size: 32))),
          const SizedBox(height: 12),
          const Text('No scans yet', style: TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Start your first AR scan to see solar potential', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/scan/setup'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Start Your First Scan', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border, width: 1))),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.white,
        elevation: 0,
        unselectedFontSize: 11,
        selectedFontSize: 11,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) Navigator.pushNamed(context, '/scan/setup');
          if (index == 2) Navigator.pushNamed(context, '/providers');
          if (index == 3) Navigator.pushNamed(context, '/report');
          if (index == 4) Navigator.pushNamed(context, '/profile');
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

// ─── Notification Bottom Sheet ─────────────────────────────────────────────
class _NotificationSheet extends StatelessWidget {
  final List<_Notif> _notifs = const [
    _Notif(Icons.wb_sunny_outlined, 'Solar Tip', 'Today is sunny — ideal for running your high-power appliances to save on bills.', '2 min ago', true),
    _Notif(Icons.account_balance_outlined, 'PM Surya Ghar', 'New subsidy window open: apply before 30 April to claim ₹78,000.', '1 hr ago', true),
    _Notif(Icons.bar_chart_outlined, 'Report Ready', 'Your last AR scan analysis has been processed. Tap to view.', '3 hrs ago', false),
    _Notif(Icons.bolt_outlined, 'Energy Alert', 'Your estimated monthly bill of ₹2,500 can be reduced by 72% with solar.', 'Yesterday', false),
  ];

  const _NotificationSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notifications', style: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('2 new', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            // List
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifs.length,
                separatorBuilder: (context, index) => const Divider(indent: 72, endIndent: 16, height: 1),
                itemBuilder: (_, i) {
                  final n = _notifs[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (n.isNew ? AppColors.primary : AppColors.textSecondary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(n.icon, color: n.isNew ? AppColors.primary : AppColors.textSecondary, size: 22),
                    ),
                    title: Row(
                      children: [
                        Text(n.title, style: TextStyle(fontSize: 14, fontWeight: n.isNew ? FontWeight.w700 : FontWeight.w600, color: AppColors.navy)),
                        if (n.isNew) ...[
                          const SizedBox(width: 6),
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                        ]
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(n.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                        const SizedBox(height: 4),
                        Text(n.time, style: TextStyle(fontSize: 11, color: AppColors.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                      ],
                    ),
                    isThreeLine: true,
                    tileColor: n.isNew ? AppColors.primary.withValues(alpha: 0.03) : Colors.transparent,
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
