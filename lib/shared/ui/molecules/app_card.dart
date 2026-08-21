import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// `surface` — white, the default everywhere. `field` — the page tone, for a
/// card nested inside another card (the booking summary panel). `emergency` —
/// red fill and border with white text, the 24/7 tile.
enum AppCardTone { surface, field, emergency }

/// The universal surface of the design system.
///
/// Surface fill, a hairline border, `--shadow-lift-1`, and the **signature
/// asymmetric corner** — 24/24/8/24, the bottom-right pinched to 8px. Every
/// other card-shaped thing in this app composes this widget. Do not hand-roll
/// the corner anywhere else: it is the one shape the whole brand is built on,
/// and a single card with four equal corners reads as a bug.
///
/// ## About the touch feedback
///
/// The web card lifts 6px into `shadow-lift-2` on hover — but the CSS gates
/// that behind `@media (hover: hover) and (pointer: fine)`, i.e. it is
/// deliberately switched OFF for touch, so that the lift does not stick to a
/// card after a tap. That leaves the boards with no defined touch feedback
/// for a card at all.
///
/// Rather than invent one, a tappable card here reuses the only press
/// feedback this system defines anywhere — `.btn:active { transform:
/// translateY(1px) }`. It is a derivation, not a copy, and it is flagged as
/// such so the next person does not go looking for it in the boards.
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

  /// The content slot, wrapped in [padding].
  final Widget? child;

  /// A photo or figure above the content, clipped by the card's own corner.
  /// Left flush — media-led cards do not pad their image.
  final Widget? media;

  final VoidCallback? onTap;
  final AppCardTone tone;

  /// Content padding. Zero by default so a media-led card stays flush; the
  /// boards use 16 in the task rail, 18 in content cards, 20 in the booking
  /// panel — all in [AppSpacing].
  final EdgeInsetsGeometry padding;

  /// Overridable for the marquee cards, which the board draws with the
  /// signature fill and border but `border-radius: 16px` and no shadow.
  final BorderRadius borderRadius;

  /// The marquee cards set `box-shadow: none`.
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

  /// The default text colour inside the card. On the emergency tone
  /// everything flips to white — which is why the card sets it once here
  /// instead of every caller remembering.
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
