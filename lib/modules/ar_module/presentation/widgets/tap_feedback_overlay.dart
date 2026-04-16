import 'package:flutter/material.dart';

// ── Tap Feedback Widget ───────────────────────────────────────────────────────

class TapFeedbackOverlay extends StatefulWidget {
  const TapFeedbackOverlay({super.key, required this.tapPosition, required this.onComplete});

  final Offset tapPosition;
  final VoidCallback onComplete;

  @override
  State<TapFeedbackOverlay> createState() => _TapFeedbackOverlayState();
}

class _TapFeedbackOverlayState extends State<TapFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.tapPosition.dx - 25,
      top: widget.tapPosition.dy - 25,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF),
                      width: 3.0,
                    ),
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
