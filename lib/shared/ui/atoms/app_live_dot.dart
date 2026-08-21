import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The pulsing "live" dot that marks anything happening right now — an open
/// agenda, a turn being called, a doctor online.
///
/// ```css
/// .dot        { width: 9px; height: 9px; border-radius: 50%; background: live; }
/// .dot::after { inset: 0; background: live; animation: ping 2s ease-out infinite; }
/// @keyframes ping { from { transform: scale(1); opacity: .85 }
///                   to   { transform: scale(2.2); opacity: 0 } }
/// ```
///
/// `ease-out` is deliberate and is the whole character of the pulse: the ring
/// leaves fast and settles slowly, which reads as a heartbeat. On the brand
/// curve it reads as a loading spinner instead.
///
/// The ring grows to 2.2x the dot, so the widget must not clip — hence
/// [Clip.none] on the stack. If you wrap this in something that clips, the
/// pulse silently disappears and the dot just looks flat.
class AppLiveDot extends StatefulWidget {
  const AppLiveDot({super.key, this.size = 9, this.color = AppColors.live});

  final double size;

  /// `--color-live` by default. The FAB uses `--color-wa` with the same
  /// keyframe, which is why this is a parameter.
  final Color color;

  @override
  State<AppLiveDot> createState() => _AppLiveDotState();
}

class _AppLiveDotState extends State<AppLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.ping,
  )..repeat();

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        // The ring reaches 2.2x the dot and must be allowed out of the box.
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: 1 + 1.2 * _pulse.value, // 1 -> 2.2
              child: Opacity(
                opacity: (1 - _pulse.value) * 0.85, // .85 -> 0
                child: child,
              ),
            ),
            child: _Circle(size: widget.size, color: widget.color),
          ),
          _Circle(size: widget.size, color: widget.color),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
