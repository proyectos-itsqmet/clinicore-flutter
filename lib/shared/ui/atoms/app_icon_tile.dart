import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// The tone of an icon tile.
enum AppIconTileTone {
  /// `tint` fill with a `blue-text` glyph — the default everywhere.
  tint,

  /// White-at-20% fill with a white glyph, for a tile sitting on the
  /// emergency red or on a dark card.
  onDark,

  /// `cream` fill with a `gold-ink` glyph, for the warm band.
  gold,

  /// `ok`-at-12% fill with an `ok` glyph, for confirmed states.
  ok,
}

/// The rounded, tinted square that holds an icon.
///
/// `design/Mobile.dc.html` uses it at exactly 38x38 with a 12px radius and a
/// 20px glyph in every task-rail tile. It is a separate atom because that
/// trio (box size / radius / glyph size) has to stay proportional — bump the
/// box to 44 and leave the glyph at 20 and the icon starts floating in the
/// middle of a mostly-empty square.
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.tone = AppIconTileTone.tint,
    this.size = 38,
    this.radius = AppRadii.tileSm,
  });

  final IconData icon;
  final AppIconTileTone tone;

  /// The box. The glyph follows at `size * _glyphRatio`.
  final double size;
  final double radius;

  /// 20/38 — the ratio the mobile board draws.
  static const double _glyphRatio = 20 / 38;

  Color get _fill => switch (tone) {
    AppIconTileTone.tint => AppColors.tint,
    AppIconTileTone.onDark => AppColors.surface.withValues(alpha: 0.2),
    AppIconTileTone.gold => AppColors.cream,
    AppIconTileTone.ok => AppColors.ok.withValues(alpha: 0.12),
  };

  Color get _glyph => switch (tone) {
    AppIconTileTone.tint => AppColors.blueText,
    AppIconTileTone.onDark => AppColors.surface,
    AppIconTileTone.gold => AppColors.goldInk,
    AppIconTileTone.ok => AppColors.ok,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
      child: Icon(icon, size: size * _glyphRatio, color: _glyph),
    );
  }
}
