import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalysisLoadingScreen extends StatefulWidget {
  const AnalysisLoadingScreen({super.key});

  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _progress = 0;
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {"text": "Calculating energy generation...", "icon": Icons.check_circle, "color": Colors.white30},
    {"text": "Analyzing shadows...", "icon": Icons.satellite_alt, "color": Colors.blueAccent},
    {"text": "Computing PM Surya Ghar subsidy...", "icon": Icons.sync, "color": Colors.orangeAccent},
    {"text": "Optimizing ROI projection...", "icon": Icons.pending, "color": Colors.white30},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _simulateProgress();
  }

  void _simulateProgress() async {
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          _progress = i / 100;
          if (i == 30) _currentStep = 1;
          if (i == 60) _currentStep = 2;
          if (i == 85) _currentStep = 3;
        });
      }
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/report');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Particles
          Positioned.fill(child: Opacity(opacity: 0.5, child: CustomPaint(painter: AbstractParticlePainter()))),
          // Gradient Mesh
          Positioned.fill(
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0F172A), const Color(0xFF1E293B).withValues(alpha: 0.2), const Color(0xFF0F172A)], begin: Alignment.topRight, end: Alignment.bottomLeft))),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.solar_power, color: Colors.orange, size: 28),
                          const SizedBox(width: 8),
                          Text('SOLARSENSE AR', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: Colors.orange, fontSize: 18, letterSpacing: 1.2)),
                        ],
                      ),
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueGrey.shade800.withValues(alpha: 0.5), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white54, size: 20))
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Central Progress Visual
                        SizedBox(
                          width: 250, height: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange.withValues(alpha: 0.2), width: 3))),
                              AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) => Transform.rotate(
                                  angle: _controller.value * 2 * 3.14159,
                                  child: Container(width: 220, height: 220, decoration: const BoxDecoration(shape: BoxShape.circle, border: Border(top: BorderSide(color: Colors.orange, width: 3), right: BorderSide(color: Colors.orange, width: 3)))),
                                ),
                              ),
                              Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withValues(alpha: 0.05), boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.1), blurRadius: 40)])),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.light_mode, color: Colors.orange, size: 56),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text('${(_progress * 100).toInt()}', style: GoogleFonts.manrope(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -2)),
                                      Text('%', style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white60)),
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Dynamic Status Narrative
                        Column(
                          children: List.generate(_steps.length, (index) {
                            final isActive = index == _currentStep;
                            final isPast = index < _currentStep;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: isActive ? 1.0 : (isPast ? 0.4 : 0.2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_steps[index]["icon"], color: isActive ? _steps[index]["color"] : Colors.white, size: isActive ? 20 : 14),
                                    const SizedBox(width: 12),
                                    Text(_steps[index]["text"], style: isActive ? GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white) : GoogleFonts.inter(fontSize: 14, color: Colors.white)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        )
                      ],
                    ),
                  ),
                ),

                // Bottom Dashboard Progress Bento Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        height: 6, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.blueGrey.shade800, borderRadius: BorderRadius.circular(3)),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progress,
                            child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF9d4300), Color(0xFFf97316)]), borderRadius: BorderRadius.circular(3), boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 12)])),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Contextual Bento Insight
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance, color: Colors.lightBlueAccent, size: 20)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PM Surya Ghar Yojana', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text("We're verifying your roof area against central government subsidy brackets for maximum savings.", style: GoogleFonts.inter(fontSize: 12, color: Colors.white60, height: 1.5)),
                                ],
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class AbstractParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.orange.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.15), 3, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.45), 4, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.75), 2, paint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.25), 3.5, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.85), 2.5, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
