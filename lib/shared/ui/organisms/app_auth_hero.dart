import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import '../atoms/atoms.dart';

class AppAuthHero extends StatelessWidget {
  const AppAuthHero({
    super.key,
    this.title,
    this.kicker,
    this.subtitle,
    this.collapsed = false,
    this.image,
    this.brandName = 'CliniCore',
    this.onBack,
  });

  final String? title;
  final String? kicker;
  final String? subtitle;
  final bool collapsed;
  final VoidCallback? onBack;
  final ImageProvider? image;
  final String brandName;
  static const List<double> _scrimStops = <double>[0, 0.34, 0.74, 1];
  static const List<double> _scrimAlphas = <double>[0.74, 0.58, 0.88, 0.96];

  @override
  Widget build(BuildContext context) {
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
                        if (title != null)
                          Text(
                            title!,
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
