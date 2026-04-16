import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAnimatedIcon(),
                      const SizedBox(height: 24),
                      const Text(
                        'SolarSense AR',
                        style: TextStyle(color: AppColors.navy, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      ),
                      const Text(
                        'Smart Solar Planning',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'Powered by AI & Augmented Reality',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return SizedBox(
      width: 140, height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.5)),
            ),
          ),
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/logo.png',
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          )
        ],
      ),
    );
  }
}
