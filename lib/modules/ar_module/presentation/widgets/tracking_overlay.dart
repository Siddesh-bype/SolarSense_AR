import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../application/controllers/tracking_controller.dart';

// ── Tracking Overlay ───────────────────────────────────────────────────────────

/// A non-blocking, semi-transparent overlay that communicates ARCore tracking
/// state to the user in real time.
///
/// Sits above the ARView but uses [IgnorePointer] so it never consumes touches.
/// Animates between states with cross-fade + slide transitions.
class TrackingOverlay extends StatelessWidget {
  const TrackingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ARTrackingController>(
      builder: (_, ctrl, __) {
        // Hide the overlay once tracking is fully ready —
        // the main AROverlayUI takes over at that point.
        if (ctrl.state == TrackingState.trackingReady) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          child: Positioned.fill(
            child: _TrackingBanner(ctrl: ctrl),
          ),
        );
      },
    );
  }
}

// ── Banner ─────────────────────────────────────────────────────────────────────

class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner({required this.ctrl});
  final ARTrackingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Subtle darkening vignette — does NOT cover the full screen.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Centred status card.
        Center(child: _StatusCard(ctrl: ctrl)),
      ],
    );
  }
}

// ── Status card ────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.ctrl});
  final ARTrackingController ctrl;

  _TrackingConfig get _cfg {
    switch (ctrl.state) {
      case TrackingState.warmingUp:
        return const _TrackingConfig(
          emoji: '🔄',
          headline: 'Initialising AR…',
          subtext: 'Move your device slowly to begin scanning',
          accentColor: Color(0xFF00E5FF),
          pulseColor: Color(0xFF00E5FF),
        );
      case TrackingState.notTracking:
        return const _TrackingConfig(
          emoji: '🔄',
          headline: 'Move device slowly',
          subtext: 'Searching for a flat surface to track',
          accentColor: Color(0xFFFF9800),
          pulseColor: Color(0xFFFF9800),
        );
      case TrackingState.limitedTracking:
        return const _TrackingConfig(
          emoji: '⚠️',
          headline: 'Keep scanning surface…',
          subtext: 'Point at a larger flat area (e.g. a rooftop)',
          accentColor: Color(0xFFFFD600),
          pulseColor: Color(0xFFFFD600),
        );
      case TrackingState.trackingReady:
        // Should never render — parent hides the overlay at this state.
        return const _TrackingConfig(
          emoji: '✅',
          headline: 'Surface detected',
          subtext: 'Tap to place solar panels',
          accentColor: Color(0xFF69FF47),
          pulseColor: Color(0xFF69FF47),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final showProgress = ctrl.state == TrackingState.limitedTracking ||
        ctrl.state == TrackingState.warmingUp;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _CardContent(
        key: ValueKey(ctrl.state),
        cfg: cfg,
        progress: ctrl.scanProgress,
        showProgress: showProgress,
      ),
    );
  }
}

// ── Card content ───────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  const _CardContent({
    super.key,
    required this.cfg,
    required this.progress,
    required this.showProgress,
  });

  final _TrackingConfig cfg;
  final double progress;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cfg.accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: cfg.pulseColor.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated pulsing icon.
          _PulsingIcon(emoji: cfg.emoji, color: cfg.accentColor),
          const SizedBox(height: 12),

          // Headline.
          Text(
            cfg.headline,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          // Subtext.
          Text(
            cfg.subtext,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 13,
              height: 1.45,
            ),
          ),

          // Scan progress indicator (only shown during warm-up / limited).
          if (showProgress) ...[
            const SizedBox(height: 16),
            _ScanProgressBar(
              progress: progress,
              color: cfg.accentColor,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Scan progress bar ──────────────────────────────────────────────────────────

class _ScanProgressBar extends StatelessWidget {
  const _ScanProgressBar({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Scanning Surface',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
            ),
            Text(
              '$pct%',
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pulsing icon ───────────────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.emoji, required this.color});
  final String emoji;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.12),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 24),
          ),
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

// ── Config data class ──────────────────────────────────────────────────────────

class _TrackingConfig {
  const _TrackingConfig({
    required this.emoji,
    required this.headline,
    required this.subtext,
    required this.accentColor,
    required this.pulseColor,
  });

  final String emoji;
  final String headline;
  final String subtext;
  final Color accentColor;
  final Color pulseColor;
}

// ── Ready banner (shown briefly when tracking becomes stable) ──────────────────

/// A brief "✅ Surface detected. Tap to place panels" toast that auto-hides.
///
/// Show it via an [OverlayEntry] or simply as part of the scan-to-ready
/// transition — consumed by [ARScreen] with a delayed hide.
class TrackingReadyBanner extends StatelessWidget {
  const TrackingReadyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2B1A).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF69FF47).withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF69FF47).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Surface detected. Tap to place panels',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF69FF47),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the user tries to tap before tracking is ready.
class SurfaceNotReadySnack extends StatelessWidget {
  const SurfaceNotReadySnack({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF9800).withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF9800), size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Surface not ready yet — keep scanning',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
