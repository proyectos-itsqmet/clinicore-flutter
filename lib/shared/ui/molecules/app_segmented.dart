import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The single-select toggle group with a sliding thumb.
///
/// Geometry from the boards: a `tint` track with a `line` hairline, 4px of
/// inner padding, fully pilled; the thumb is one track wide, `surface`, with
/// `0 2px 8px rgb(12 43 75 / .16)`, sliding on `transform 300ms var(--e)`.
/// Labels are 14px/700, `ink` when selected and `ink-2` when not, crossfading
/// over 200ms.
///
/// ## Why the width logic is adaptive
///
/// The two boards disagree, and the Angular component ships both: mobile uses
/// **fixed 116px tracks inside a horizontal scroller**, desktop uses **equal
/// `1fr` tracks**. The mobile board scrolls because its own three labels come
/// to 356px inside a 350px content box, and because those labels are API data
/// that no fixed box can be trusted to fit.
///
/// Here the control measures itself and picks: if `count * 116` fits, the
/// tracks share the width equally (the desktop behaviour, which looks right
/// and needs no scroll affordance); if it does not fit, it falls back to fixed
/// 116px tracks and scrolls (the mobile behaviour, which never clips a
/// label). Neither board is violated and the control can never overflow its
/// parent — which is the actual bug this logic exists to prevent.
///
/// This is deliberately NOT the ARIA tab pattern, for the same reason the
/// Angular component gave up on it: without a matching tab panel, a
/// half-declared pattern is worse than none. It is a single-select group of
/// toggles.
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

  /// The Especialidades section overrides the track to white because it sits
  /// on the cream band, where `tint` would fight the warm ground.
  final AppSegmentedTone tone;

  /// The mobile board's track width, and the floor below which this control
  /// scrolls instead of squeezing.
  static const double _trackMin = 116;

  /// `p-1` — the inset the thumb sits in.
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
                  // The thumb. Decoration only — it is not an owned element
                  // of anything, so it stays out of the semantics tree.
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

        // The mobile board's `.segscroll`: the overflow is a safety valve for
        // long labels, not a scroll affordance to advertise — hence no
        // scrollbar.
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
