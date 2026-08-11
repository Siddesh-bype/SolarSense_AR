import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/user_session.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _initialsFrom(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tt = Theme.of(context).textTheme;
    final session = UserSession.instance;
    final name =
        (session.name == null || session.name!.isEmpty) ? 'Guest User' : session.name!;
    final email = (session.email == null || session.email!.isEmpty) ? '—' : session.email!;
    final initials = _initialsFrom(name);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOLARSENSE',
          style: tt.titleMedium?.copyWith(
            color: AppColors.primaryDeep,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: c.onSurfaceMuted),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
            .copyWith(bottom: 100),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                      ),
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.edit, color: AppColors.primaryDeep, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(name,
                style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700, color: c.onSurface)),
            const SizedBox(height: 4),
            Text(email,
                style: tt.bodySmall?.copyWith(
                    color: c.onSurfaceMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: _bentoStat(Icons.view_in_ar, '3', 'SCANS', c.primary, c),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _bentoStat(Icons.analytics, '1', 'REPORT',
                      AppColors.goldDeep, c),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _menuGroup(tt, c, 'General', [
              _menuItem(c, Icons.history, 'Saved Scans', c.primary),
              _menuItem(c, Icons.description, 'My Reports', AppColors.goldDeep),
              _menuItem(c, Icons.notifications, 'Notifications', c.onSurfaceMuted),
            ]),
            const SizedBox(height: 24),
            _menuGroup(tt, c, 'Preferences', [
              _menuItem(c, Icons.translate, 'Language', c.onSurfaceMuted,
                  trailing: Text('English', style: TextStyle(color: c.onSurfaceMuted, fontSize: 13))),
              _menuItem(c, Icons.help_outline, 'Help', c.onSurfaceMuted),
              _menuItem(c, Icons.verified_user_outlined, 'Privacy', c.onSurfaceMuted),
            ]),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Logout',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                style: TextButton.styleFrom(
                  backgroundColor: c.error.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 48),

            Column(
              children: [
                Text('SOLARSENSE PREMIUM',
                    style: tt.labelSmall?.copyWith(
                      color: c.onSurfaceMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    )),
                const SizedBox(height: 4),
                Text('v1.0.0',
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceMuted)),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(context, c, tt),
    );
  }

  Widget _bentoStat(
      IconData icon, String value, String label, Color color, SolarPalette c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.onSurface)),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.onSurfaceMuted,
                  letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _menuGroup(TextTheme tt, SolarPalette c, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(title.toUpperCase(),
              style: tt.labelSmall?.copyWith(
                color: c.onSurfaceMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              )),
        ),
        Column(children: items),
      ],
    );
  }

  Widget _menuItem(SolarPalette c, IconData icon, String label, Color iconColor,
      {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.primarySoft.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, color: c.onSurface)),
        trailing: trailing != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  trailing,
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: c.onSurfaceMuted),
                ],
              )
            : Icon(Icons.chevron_right, color: c.onSurfaceMuted),
        onTap: () {},
      ),
    );
  }

  Widget _bottomNav(BuildContext context, SolarPalette c, TextTheme tt) {
    return BottomNavigationBar(
      currentIndex: 4,
      unselectedLabelStyle: tt.labelSmall,
      selectedLabelStyle: tt.labelSmall,
      onTap: (index) {
        if (index == 0) Navigator.pushReplacementNamed(context, '/home');
        if (index == 1) Navigator.pushReplacementNamed(context, '/scan/setup');
        if (index == 2) Navigator.pushReplacementNamed(context, '/providers');
        if (index == 3) Navigator.pushReplacementNamed(context, '/report');
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