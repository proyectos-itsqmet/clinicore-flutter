import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.tone = AppSegmentedTone.tint,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final AppSegmentedTone tone;
  static const double _trackMin = 116;
  static const double _inset = 4;

  static const double _minHeight = 44;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int count = options.length;
        final double available = constraints.maxWidth - _inset * 2;
        final bool fits = available.isFinite && available >= _trackMin * count;
        final double track = fits ? available / count : _trackMin;

        final Widget control = SizedBox(
          width: track * count + _inset * 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone == AppSegmentedTone.tint
                  ? AppColors.tint
                  : AppColors.surface,
              borderRadius: AppRadii.pillAll,
              border: Border.all(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_inset),
              child: Stack(
                children: <Widget>[
                  AnimatedPositioned(
                    duration: AppMotion.morph,
                    curve: AppMotion.easeBrand,
                    left: track * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: track,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.pillAll,
                          boxShadow: AppShadows.thumb,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < count; i++)
                        SizedBox(
                          width: track,
                          child: Semantics(
                            button: true,
                            selected: i == selectedIndex,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(i),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: _minHeight,
                                ),
                                alignment: Alignment.center,
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: AppTypography.pill.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: i == selectedIndex
                                        ? AppColors.ink
                                        : AppColors.ink2,
                                  ),
                                  child: Text(
                                    options[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        if (fits) return control;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: control,
          ),
        );
      },
    );
  }
}

enum AppSegmentedTone { tint, surface }
