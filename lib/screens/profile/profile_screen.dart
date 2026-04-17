import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/user_session.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSession.instance;
    final name = (session.name == null || session.name!.isEmpty) ? 'Guest User' : session.name!;
    final email = (session.email == null || session.email!.isEmpty) ? '—' : session.email!;
    final initials = _initialsFrom(name);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SOLARSENSE AR', 
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 18)
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0).copyWith(bottom: 100),
        child: Column(
          children: [
            // Avatar Profile
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppColors.primary, Color(0xFFFFB690)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                    child: const Icon(Icons.edit, color: AppColors.primary, size: 16),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 32),

            // Bento Stats Grid
            Row(
              children: [
                Expanded(child: _buildBentoStat(Icons.view_in_ar, '3', 'SCANS', AppColors.primary)),
                const SizedBox(width: 16),
                Expanded(child: _buildBentoStat(Icons.analytics, '1', 'REPORT', const Color(0xFF006398))), // Tertiary
              ],
            ),
            const SizedBox(height: 32),

            // Menus
            _buildMenuGroup('General', [
              _buildMenuItem(Icons.history, 'Saved Scans', const Color(0xFFFFDBCA), AppColors.primary),
              _buildMenuItem(Icons.description, 'My Reports', const Color(0xFFCDE5FF), const Color(0xFF006398)), // Tertiary
              _buildMenuItem(Icons.notifications, 'Notifications', const Color(0xFFD8E3FB), const Color(0xFF545F73)), // Secondary
            ]),
            const SizedBox(height: 24),
            _buildMenuGroup('Preferences', [
              _buildMenuItem(Icons.translate, 'Language', const Color(0xFFE6E8EA), const Color(0xFF584237), trailing: const Text('English', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
              _buildMenuItem(Icons.help_outline, 'Help', const Color(0xFFE6E8EA), const Color(0xFF584237)),
              _buildMenuItem(Icons.verified_user_outlined, 'Privacy', const Color(0xFFE6E8EA), const Color(0xFF584237)),
            ]),
            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16)),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 48),
            
            // Footer
            const Column(
              children: [
                Text('SOLARSENSE AR PREMIUM', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                SizedBox(height: 4),
                Text('v1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            )
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBentoStat(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: color, width: 4)), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMenuGroup(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 1.5)),
        ),
        Column(children: items),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color bgColor, Color iconColor, {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
        trailing: trailing != null 
          ? Row(mainAxisSize: MainAxisSize.min, children: [trailing, const SizedBox(width: 8), const Icon(Icons.chevron_right, color: AppColors.textSecondary)])
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () {},
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border, width: 1))),
      child: BottomNavigationBar(
        currentIndex: 4,
        backgroundColor: Colors.white,
        elevation: 0,
        unselectedFontSize: 11,
        selectedFontSize: 11,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/home');
          if (index == 1) Navigator.pushReplacementNamed(context, '/scan/setup');
          if (index == 2) Navigator.pushReplacementNamed(context, '/providers');
          if (index == 3) Navigator.pushReplacementNamed(context, '/report');
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
