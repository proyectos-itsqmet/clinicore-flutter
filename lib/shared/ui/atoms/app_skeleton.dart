import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The loading placeholder.
///
/// `shimmer 1.6s ease-in-out infinite` is the one animation in the token
/// sheet that is NOT in the design boards — it was added after them, on the
/// Angular side, and its note says so explicitly. It is reproduced here for
/// consistency with the web app rather than because a board specifies it.
///
/// The sweep runs on `ease-in-out`, so the highlight slows at both ends of
/// its travel. That is what stops a screen full of skeletons from reading as
/// a strobe.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.tileSmAll,
  });

  /// A skeleton line, sized like the text it stands in for.
  const AppSkeleton.line({super.key, this.width, this.height = 16})
    : borderRadius = AppRadii.pillAll;

  /// A skeleton card, carrying the signature corner so the shape of the page
  /// is already right before the data lands.
  const AppSkeleton.card({super.key, this.width, required this.height})
    : borderRadius = AppRadii.signature;

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  )..repeat();

  late final Animation<double> _sweep = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) {
            // -1 -> 2 so the highlight fully enters and fully leaves.
            final double t = -1 + _sweep.value * 3;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.tint,
                gradient: LinearGradient(
                  begin: Alignment(t - 1, 0),
                  end: Alignment(t + 1, 0),
                  colors: <Color>[
                    AppColors.tint,
                    AppColors.surface.withValues(alpha: 0.85),
                    AppColors.tint,
                  ],
                  stops: const <double>[0.35, 0.5, 0.65],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
