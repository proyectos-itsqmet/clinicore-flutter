import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The confirmation check, drawing itself.
///
/// ```css
/// .tick { stroke-dasharray: 30; stroke-dashoffset: 30;
///         animation: tickdraw 340ms var(--e) 120ms forwards; }
/// @keyframes tickdraw { to { stroke-dashoffset: 0; } }
/// ```
///
/// This is the one animation in the system that marks a task completed, and
/// it earns a real implementation rather than a fade-in. CSS draws it with
/// `stroke-dashoffset`; Flutter's equivalent is [Path.computeMetrics] plus
/// [PathMetric.extractPath], which returns the first `t` of the path's length
/// — the same effect by the same mechanism.
///
/// The 120ms delay is not decoration either: it lets the surface behind the
/// check settle into its confirmed colour first, so the two things read as a
/// sequence ("booked" then "here is your proof") instead of a single flash.
class AppTick extends StatefulWidget {
  const AppTick({
    super.key,
    this.size = 21,
    this.color = AppColors.surface,
    this.strokeWidth = 2.8,
  });

  final double size;
  final Color color;

  /// `stroke-width: 2.8` on the boards' 24-unit viewBox, scaled with [size].
  final double strokeWidth;

  @override
  State<AppTick> createState() => _AppTickState();
}

class _AppTickState extends State<AppTick> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.tickDraw,
  );

  late final Animation<double> _draw = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.easeBrand,
  );

  @override
  void initState() {
    super.initState();
    // `animation-delay: 120ms`.
    Future<void>.delayed(AppMotion.tickDrawDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _draw,
        builder: (context, _) => CustomPaint(
          painter: _TickPainter(
            progress: _draw.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  /// The boards' viewBox, so the path below can be written in its own units.
  static const double _viewBox = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final double scale = size.width / _viewBox;

    // `d="m5 12.5 4.5 4.5L19 7.5"` — down into the corner, then up.
    final Path path = Path()
      ..moveTo(5 * scale, 12.5 * scale)
      ..lineTo(9.5 * scale, 17 * scale)
      ..lineTo(19 * scale, 7.5 * scale);

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }

    // The Flutter equivalent of animating `stroke-dashoffset` to 0.
    for (final PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
