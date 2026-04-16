import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'modules/ar_module/application/controllers/ar_controller.dart';
import 'modules/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.black,
  ));
  runApp(const SolarSenseApp());
}

class SolarSenseApp extends StatelessWidget {
  const SolarSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ARController(),
      child: MaterialApp(
        title: 'SolarSense AR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            secondary: Color(0xFFFFD600),
            surface: Color(0xFF0A0E1A),
          ),
          scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
