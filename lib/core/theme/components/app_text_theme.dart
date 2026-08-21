import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// The design system's scale mapped onto Material's [TextTheme].
///
/// Material has thirteen slots; this system has eight named levels. The map
/// below is intentionally lossy — its only job is to make sure that a
/// framework widget which reaches for `titleMedium` gets something from this
/// design system instead of Roboto 16.
///
/// Application code should use [AppTypography] by name (`AppTypography.h2`),
/// not these slots. Reaching for `bodyLarge` when you mean `lead` loses the
/// intent, and the next person cannot tell whether the choice was deliberate.
abstract final class AppTextTheme {
  static const TextTheme textTheme = TextTheme(
    // Display / headline slots take the display family.
    displayLarge: AppTypography.h1,
    displayMedium: AppTypography.h1,
    displaySmall: AppTypography.h2,
    headlineLarge: AppTypography.h2,
    headlineMedium: AppTypography.h2,
    headlineSmall: AppTypography.h3,
    titleLarge: AppTypography.h3,
    titleMedium: AppTypography.h3,
    titleSmall: AppTypography.meta,

    // Body slots take the sans family.
    bodyLarge: AppTypography.lead,
    bodyMedium: AppTypography.body,
    bodySmall: AppTypography.cap,

    labelLarge: AppTypography.button,
    labelMedium: AppTypography.meta,
    labelSmall: AppTypography.kicker,
  );
}
