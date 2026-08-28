import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

enum AppCardTone { surface, field, emergency }

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    this.child,
    this.media,
    this.onTap,
    this.tone = AppCardTone.surface,
    this.padding = EdgeInsets.zero,
    this.borderRadius = AppRadii.signature,
    this.showShadow = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget? child;
  final Widget? media;
  final VoidCallback? onTap;
  final AppCardTone tone;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool showShadow;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  Color get _fill => switch (widget.tone) {
    AppCardTone.surface => AppColors.surface,
    AppCardTone.field => AppColors.field,
    AppCardTone.emergency => AppColors.emergency,
  };

  Color get _border => switch (widget.tone) {
    AppCardTone.surface => AppColors.line,
    AppCardTone.field => AppColors.line,
    AppCardTone.emergency => AppColors.emergency,
  };

  Color get _ink =>
      widget.tone == AppCardTone.emergency ? AppColors.surface : AppColors.ink;

  @override
  Widget build(BuildContext context) {
    final Widget surface = AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.easeBrand,
      transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: widget.borderRadius,
        border: Border.all(color: _border),
        boxShadow: widget.showShadow ? AppShadows.lift1 : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: _ink),
        child: Column(
          crossAxisAlignment: widget.crossAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.media != null) widget.media!,
            if (widget.child != null)
              Padding(padding: widget.padding, child: widget.child),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return surface;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Semantics(button: true, child: surface),
    );
  }
}
