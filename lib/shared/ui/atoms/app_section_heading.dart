import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import 'app_kicker.dart';

/// The section opener: kicker, heading, optional intro.
///
/// Every section in the boards starts with the same three-part stack at a
/// 20px gap. Bundling it into one atom is what keeps a screen's rhythm from
/// drifting — the moment each screen assembles its own kicker + h2 by hand,
/// one of them ends up at 16px of gap and nobody notices for a month.
class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading({
    super.key,
    required this.title,
    this.kicker,
    this.kickerTone = AppKickerTone.muted,
    this.lead,
    this.titleColor,
    this.leadColor,
  });

  final String title;
  final String? kicker;
  final AppKickerTone kickerTone;
  final String? lead;

  /// For a heading over dark photography, where `ink` would disappear.
  final Color? titleColor;
  final Color? leadColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.section,
      children: <Widget>[
        if (kicker != null) AppKicker(text: kicker!, tone: kickerTone),
        Text(
          title,
          style: titleColor == null
              ? AppTypography.h2
              : AppTypography.h2.copyWith(color: titleColor),
        ),
        if (lead != null)
          Text(
            lead!,
            style: leadColor == null
                ? AppTypography.lead
                : AppTypography.lead.copyWith(color: leadColor),
          ),
      ],
    );
  }
}
