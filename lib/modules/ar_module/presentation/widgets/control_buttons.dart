import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../application/controllers/ar_controller.dart';

/// Bottom control button bar — adapts to the current [ARScanMode].
class ControlButtons extends StatelessWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ARController>(
      builder: (context, ctrl, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.88)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Obstacle chip list ────────────────────────────────────
              if (ctrl.obstacleIds.isNotEmpty) ...[
                _ObstacleChips(
                  ids: ctrl.obstacleIds,
                  onRemove: ctrl.removeObstacleById,
                ),
                const SizedBox(height: 10),
              ],

              // ── Mode-aware action row ─────────────────────────────────
              _buildActionRow(context, ctrl),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionRow(BuildContext context, ARController ctrl) {
    switch (ctrl.mode) {
      case ARScanMode.scanning:
        return _scanningRow(context, ctrl);
      case ARScanMode.definingCorners:
        return _cornerRow(context, ctrl);
      case ARScanMode.complete:
      case ARScanMode.addingObstacle:
        return _completeRow(context, ctrl);
    }
  }

  // ── Scanning buttons ──────────────────────────────────────────────────────

  Widget _scanningRow(BuildContext context, ARController ctrl) {
    return Row(
      children: [
        Expanded(
          child: _ARButton(
            id: 'btn_back_home',
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            color: const Color(0xFF1A1A2E),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ARButton(
            id: 'btn_mode_toggle',
            icon: ctrl.quickMode
                ? Icons.auto_awesome_rounded
                : Icons.touch_app_rounded,
            label: ctrl.quickMode ? 'Quick' : 'Manual',
            color: ctrl.quickMode
                ? const Color(0xFF00875A)
                : const Color(0xFF37474F),
            onPressed: ctrl.toggleQuickMode,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _HintBubble(
            text: ctrl.quickMode
                ? 'Tap once to auto-place panels'
                : 'Tap 4 rooftop corners to start',
          ),
        ),
      ],
    );
  }

  // ── Corner-defining buttons ───────────────────────────────────────────────

  Widget _cornerRow(BuildContext context, ARController ctrl) {
    return Row(
      children: [
        Expanded(
          child: _ARButton(
            id: 'btn_undo_corner',
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: const Color(0xFF37474F),
            onPressed: ctrl.undoLastCorner,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ARButton(
            id: 'btn_reset_corners',
            icon: Icons.refresh_rounded,
            label: 'Restart',
            color: const Color(0xFF212121),
            onPressed: ctrl.resetScan,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _ARButton(
            id: 'btn_corner_hint',
            icon: Icons.touch_app_rounded,
            label: 'Tap corner ${ctrl.cornerCount + 1} on plane',
            color: const Color(0xFF1565C0),
            onPressed: null,
          ),
        ),
      ],
    );
  }

  // ── Complete / obstacle buttons ───────────────────────────────────────────

  Widget _completeRow(BuildContext context, ARController ctrl) {
    final inObstacleMode = ctrl.mode == ARScanMode.addingObstacle;
    return Row(
      children: [
        // Add / cancel obstacle
        Expanded(
          child: _ARButton(
            id: 'btn_obstacle_toggle',
            icon: inObstacleMode ? Icons.close_rounded : Icons.add_box_rounded,
            label: inObstacleMode ? 'Cancel' : 'Obstacle',
            color: inObstacleMode
                ? const Color(0xFFD32F2F)
                : const Color(0xFF37474F),
            onPressed: ctrl.toggleObstacleMode,
          ),
        ),
        const SizedBox(width: 10),

        // Reset
        Expanded(
          child: _ARButton(
            id: 'btn_reset',
            icon: Icons.refresh_rounded,
            label: 'Reset',
            color: const Color(0xFF212121),
            onPressed: () => _showResetDialog(context, ctrl),
          ),
        ),
        const SizedBox(width: 10),

        // Confirm
        Expanded(
          child: _ARButton(
            id: 'btn_confirm',
            icon: Icons.check_circle_rounded,
            label: 'Confirm',
            color: const Color(0xFF00875A),
            onPressed: () {
              ctrl.confirmLayout();
              _showConfirmSnack(context);
            },
          ),
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context, ARController ctrl) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Scan?',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'This will clear all corners, panels, and obstacles.',
          style: GoogleFonts.outfit(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ctrl.resetScan();
            },
            child: Text('Reset',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFF5252),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConfirmSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Layout confirmed — data ready for backend',
            style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF00875A),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── AR Button ─────────────────────────────────────────────────────────────────

class _ARButton extends StatelessWidget {
  const _ARButton({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final String id;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hint bubble ──────────────────────────────────────────────────────────────

class _HintBubble extends StatelessWidget {
  const _HintBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF00E5FF), size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Obstacle chip list ────────────────────────────────────────────────────────

class _ObstacleChips extends StatelessWidget {
  const _ObstacleChips({required this.ids, required this.onRemove});
  final List<String> ids;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: ids.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text('Obstacle ${i + 1}',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 11)),
          avatar: const Icon(Icons.close, color: Colors.white70, size: 14),
          backgroundColor: const Color(0xFF37474F),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
          onPressed: () => onRemove(ids[i]),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
