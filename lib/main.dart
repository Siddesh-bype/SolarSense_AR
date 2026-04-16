import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

// Placeholder imports for unused routes right now
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_register_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/scan/setup_scan_screen.dart';
import 'screens/scan/ar_camera_screen.dart';
import 'screens/scan/analysis_loading_screen.dart';
import 'screens/report/financial_report_screen.dart';
import 'screens/vendors/vendor_connect_screen.dart';
import 'screens/vendors/provider_scheme_screen.dart';
import 'screens/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SolarSenseApp());
}

class SolarSenseApp extends StatelessWidget {
  const SolarSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SolarSense AR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/auth': (context) => const LoginRegisterScreen(),
        '/home': (context) => const DashboardScreen(),
        '/scan/setup': (context) => const SetupScanScreen(),
        '/scan/ar': (context) => const ARCameraScreen(),
        '/scan/loading': (context) => const AnalysisLoadingScreen(),
        '/report': (context) => const FinancialReportScreen(),
        '/vendors': (context) => const VendorConnectScreen(),
        '/providers': (context) => const ProviderSchemeScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
