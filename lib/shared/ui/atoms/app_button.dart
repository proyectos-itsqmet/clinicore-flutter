import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import 'app_beam.dart';
import 'app_glass.dart';

/// Visual treatment of the button.
///
/// [primary] is the only one that carries the rotating border beam and the
/// coloured CTA halo — that pairing is what marks the single most important
/// action on a screen, so a screen with two primary buttons has a hierarchy
/// problem, not a styling problem.
enum AppButtonVariant {
  /// Blue fill + rotating beam + `--shadow-cta`. One per screen.
  primary,

  /// WhatsApp green with INK text. Never white: white on `#25D366`
  /// measures 2.4:1, ink measures 7.83:1.
  whatsapp,

  /// Translucent, for use over the dark hero photography.
  glass,

  /// 2px blue outline, transparent fill, `blue-text` label.
  ghost,

  /// The 24/7 red. Reserved for actual emergencies, not for destructive
  /// actions in general.
  emergency,
}

/// `md` follows `design/Mobile.dc.html`'s `.btn` (54px tall, 22px of
/// horizontal padding, 16px label). `lg` follows the Angular atom's large
/// step (58 / 30 / 17) for the one-button-per-screen auth submits.
enum AppButtonSize { md, lg }

/// The design system's single call-to-action control.
///
/// It knows nothing about what it submits or navigates to — appearance and
/// content arrive entirely through its parameters, exactly like the Angular
/// `app-button` it is ported from.
///
/// The press feedback is `transform: translateY(1px)` over 110ms on the brand
/// curve, and it is the app's ONLY press feedback: [AppTheme] switches the
/// Material ink ripple off globally so the two cannot fight each other.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.fullWidth = false,
    this.leading,
    this.trailing,
    this.isLoading = false,
  });

  final String label;

  /// Null disables the button. There is no separate `disabled` flag on
  /// purpose: a button with no callback IS disabled, and keeping the two in
  /// sync by hand is how you end up with a tappable no-op.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool fullWidth;

  /// Icons, drawn at the label's colour. The board's `.btn` gap is 10px.
  final Widget? leading;
  final Widget? trailing;

  /// Swaps the label for a spinner and blocks the callback. The button keeps
  /// its width so the layout does not jump.
  final bool isLoading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  double get _minHeight => switch (widget.size) {
    AppButtonSize.md => 54,
    AppButtonSize.lg => 58,
  };

  double get _padX => switch (widget.size) {
    AppButtonSize.md => 22,
    AppButtonSize.lg => 30,
  };

  double get _fontSize => switch (widget.size) {
    AppButtonSize.md => 16,
    AppButtonSize.lg => 17,
  };

  /// The label colour per variant. This is the pairing table from the palette
  /// board, and it is the part of a button that is genuinely easy to get
  /// wrong — see [AppButtonVariant.whatsapp].
  Color get _labelColor => switch (widget.variant) {
    AppButtonVariant.primary => AppColors.surface,
    AppButtonVariant.whatsapp => AppColors.ink,
    AppButtonVariant.glass => AppColors.surface,
    AppButtonVariant.ghost => AppColors.blueText,
    AppButtonVariant.emergency => AppColors.surface,
  };

  @override
  Widget build(BuildContext context) {
    final Widget content = _buildContent();

    return Opacity(
      // The Angular atom's `disabled:opacity-50`.
      opacity: _enabled || widget.isLoading ? 1 : 0.5,
      child: AnimatedContainer(
        duration: AppMotion.press,
        curve: AppMotion.easeBrand,
        // `.btn:active { transform: translateY(1px) }` — moved on the
        // outside so the CTA halo travels with the button, as it does in CSS.
        transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadii.pillAll,
          boxShadow: widget.variant == AppButtonVariant.primary && _enabled
              ? AppShadows.cta
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadii.pillAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: AppRadii.pillAll,
            onTap: _enabled ? widget.onPressed : null,
            onHighlightChanged: (value) {
              if (!_enabled) return;
              setState(() => _pressed = value);
            },
            child: _buildSurface(content),
          ),
        ),
      ),
    );
  }

  /// Wraps the label in the variant's own surface.
  Widget _buildSurface(Widget content) {
    return switch (widget.variant) {
      AppButtonVariant.primary => AppBeam(
        // The beam keeps spinning while loading — it is what says "working".
        animate: _enabled || widget.isLoading,
        child: content,
      ),
      AppButtonVariant.glass => AppGlass(child: content),
      AppButtonVariant.whatsapp => _solid(AppColors.wa, content),
      AppButtonVariant.emergency => _solid(AppColors.emergency, content),
      AppButtonVariant.ghost => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.pillAll,
          border: Border.all(color: AppColors.blue, width: 2),
        ),
        child: content,
      ),
    };
  }

  Widget _solid(Color fill, Widget content) => DecoratedBox(
    decoration: BoxDecoration(color: fill, borderRadius: AppRadii.pillAll),
    child: content,
  );

  Widget _buildContent() {
    final TextStyle style = AppTypography.button.copyWith(
      fontSize: _fontSize,
      color: _labelColor,
    );

    final Widget inner = widget.isLoading
        ? SizedBox(
            height: _fontSize + 2,
            width: _fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _labelColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            // `.btn { gap: 10px }`.
            spacing: AppSpacing.md,
            children: <Widget>[
              if (widget.leading != null)
                IconTheme.merge(
                  data: IconThemeData(color: _labelColor, size: _fontSize + 3),
                  child: widget.leading!,
                ),
              Flexible(
                child: Text(
                  widget.label,
                  style: style,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailing != null)
                IconTheme.merge(
                  data: IconThemeData(color: _labelColor, size: _fontSize + 3),
                  child: widget.trailing!,
                ),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _minHeight),
      child: SizedBox(
        width: widget.fullWidth ? double.infinity : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _padX),
          child: Center(child: inner),
        ),
      ),
    );
  }
}
