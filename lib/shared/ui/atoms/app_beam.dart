import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The primary CTA's rotating border beam — the single most recognisable
/// thing this design system does, and the reason `AppButton.primary` is not
/// just a blue pill.
///
/// The CSS builds it out of two pseudo-elements on the same box:
///
/// ```css
/// .beam::before {                       /* the sweep */
///   background: conic-gradient(from 0deg,
///     transparent 0 66%, rgb(255 255 255 / .95) 78%, transparent 86% 100%);
///   animation: spin 2.8s linear infinite;
/// }
/// .beam::after {                        /* the fill, inset by 2px */
///   inset: 2px;
///   border-radius: inherit;
///   background-color: var(--color-blue);
/// }
/// ```
///
/// So the beam is not a border at all: it is a full-box rotating sweep with a
/// solid fill sitting 2px inside it. What you see as "a light travelling
/// round the edge" is the 2px of sweep the fill fails to cover. Reproducing
/// it as an animated border would look wrong at the corners, where the gap is
/// widest.
///
/// Two things carried across deliberately:
///
/// * **`linear`, not the brand curve.** A rotation that accelerates reads as
///   a stutter. The token sheet lists this as one of the three animations
///   that are intentionally not eased.
/// * **The sweep is drawn by a painter, not a rotated widget.** A rotated
///   child would have to be oversized to keep covering the corners (the CSS
///   does exactly that — `width: 220%; height: 420%`). A [SweepGradient] is
///   angular by construction, so rotating its *transform* covers the box at
///   every angle with no layout gymnastics.
class AppBeam extends StatefulWidget {
  const AppBeam({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.pillAll,
    this.fill = AppColors.blue,
    this.animate = true,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// The `::after` fill. Always a solid token colour — the beam reads as an
  /// edge highlight only if what it surrounds is opaque.
  final Color fill;

  /// Set to false for a disabled CTA: the shape stays, the motion stops.
  final bool animate;

  /// `inset: 2px` — the width of the visible beam.
  static const double edge = 2;

  @override
  State<AppBeam> createState() => _AppBeamState();
}

class _AppBeamState extends State<AppBeam> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.spin,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(AppBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // `.beam::before` — the sweep, under everything.
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _SweepPainter(turns: _controller.value),
                ),
              ),
            ),
          ),

          // `.beam::after` — the fill, inset by 2px, leaving the beam visible
          // as the ring the fill does not cover.
          Positioned.fill(
            left: AppBeam.edge,
            top: AppBeam.edge,
            right: AppBeam.edge,
            bottom: AppBeam.edge,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.fill,
                borderRadius: widget.borderRadius,
              ),
            ),
          ),

          // `.beam-label` — z-index 2, on top of both.
          widget.child,
        ],
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.turns});

  /// 0..1, one full revolution.
  final double turns;

  /// `rgb(255 255 255 / .95)`.
  static final Color _highlight = AppColors.surface.withValues(alpha: 0.95);
  static final Color _clear = AppColors.surface.withValues(alpha: 0);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // The conic-gradient's stops, verbatim: transparent through 66%, full
    // white at 78%, transparent again from 86%.
    final Paint paint = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(turns * 2 * math.pi),
        colors: <Color>[_clear, _clear, _highlight, _clear, _clear],
        stops: const <double>[0, 0.66, 0.78, 0.86, 1],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) => oldDelegate.turns != turns;
}
