import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

/// The dark header the auth screens sit under.
///
/// It is the mobile board's hero, reduced to the parts that survive without a
/// full-bleed photograph:
///
/// * the `navy-deep` ground,
/// * the scrim — `linear-gradient(178deg, rgb(12 43 75 / .74) 0%,
///   rgb(12 43 75 / .58) 34%, rgb(12 43 75 / .88) 74%,
///   rgb(12 43 75 / .96) 100%)` — which over the flat ground reads as a soft
///   vertical shading, and over a photo does what it does on the site,
///   * the brand mark and wordmark at 16px/800 in `display`,
/// * a `soft` kicker with the live dot,
/// * `h1` in white and `lead` in **tint**, which is the board's own choice for
///   body copy on dark (`#EAF2FC`) — not white at reduced opacity.
///
/// Pass [image] once `assets/images/` has a hero photograph and the Ken Burns
/// drift (`scale 1 -> 1.09` over 14s, alternating) comes with it. Until then
/// the gradient carries the header on its own, which is why the scrim is
/// reproduced exactly rather than replaced with a flat fill.
///
/// ## Collapsing
///
/// When the keyboard is up the hero drops everything but the brand row. A
/// 300px header and a 280px keyboard do not fit on a 390x844 phone at the
/// same time, and the thing the user needs to see is the field they are
/// typing into. The collapse runs on [AppMotion.panelSlide], the same
/// duration the boards use for a panel change.
class AppAuthHero extends StatelessWidget {
  const AppAuthHero({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.collapsed = false,
    this.image,
    this.brandName = 'CliniCore',
    this.onBack,
  });

  final String title;
  final String? kicker;
  final String? subtitle;

  /// True while the keyboard is up.
  final bool collapsed;

  /// Shows the back affordance beside the brand mark. It is the mobile
  /// board's own nav button — a 44x44 circle filled with
  /// `rgb(255 255 255 / .18)`, which is the [AppGlass] fill without the blur,
  /// because there is nothing behind it worth blurring on a flat scrim.
  final VoidCallback? onBack;

  /// Optional hero photograph, drawn under the scrim.
  final ImageProvider? image;

  final String brandName;

  /// `linear-gradient(178deg, ...)` — the 2 degrees off vertical are what stop
  /// the scrim reading as a mechanical fade.
  static const List<double> _scrimStops = <double>[0, 0.34, 0.74, 1];
  static const List<double> _scrimAlphas = <double>[0.74, 0.58, 0.88, 0.96];

  @override
  Widget build(BuildContext context) {
    // The hero bleeds under the status bar, so the status bar's glyphs have to
    // flip to light for as long as it is on screen. `AnnotatedRegion` scopes
    // that to this widget: leave the auth flow and the app's default dark
    // glyphs come back on their own, with nothing to remember to reset.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: AnimatedSize(
        duration: AppMotion.panelSlide,
        curve: AppMotion.easeBrand,
        alignment: Alignment.topCenter,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.navyDeep),
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              if (image != null)
                Positioned.fill(
                  child: Image(
                    image: image!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.28, -0.24), // 64% 38%
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: _scrimStops,
                      colors: <Color>[
                        for (final double a in _scrimAlphas)
                          AppColors.navyDeep.withValues(alpha: a),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pad,
                    AppSpacing.xxl,
                    AppSpacing.pad,
                    AppSpacing.sectionY * 0.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.xxl,
                    children: <Widget>[
                      _BrandRow(name: brandName, onBack: onBack),
                      if (!collapsed) ...<Widget>[
                        if (kicker != null)
                          AppKicker(
                            text: kicker!,
                            tone: AppKickerTone.soft,
                            leading: const AppLiveDot(),
                          ),
                        Text(
                          title,
                          style: AppTypography.h1.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            // The board's body-on-dark colour.
                            style: AppTypography.lead.copyWith(
                              color: AppColors.tint,
                            ),
                          ),
                      ],
                    ],
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

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.name, this.onBack});

  final String name;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 9,
      children: <Widget>[
        if (onBack != null) _HeroBackButton(onTap: onBack!),
        const AppBrandMark(size: 26),
        Text(
          name,
          style: const TextStyle(
            fontFamily: AppTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.224, // -.014em x 16
            color: AppColors.surface,
          ),
        ),
      ],
    );
  }
}

/// The mobile board's nav button: a 44x44 circle at
/// `background-color: rgb(255 255 255 / .18)` with a white glyph.
class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Volver',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppSpacing.touchMin,
          height: AppSpacing.touchMin,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withValues(alpha: 0.18),
          ),
          child: const Icon(
            AppIcons.chevronLeft,
            size: 18,
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }
}
