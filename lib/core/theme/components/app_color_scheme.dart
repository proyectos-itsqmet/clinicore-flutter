import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// The Material [ColorScheme] for the app.
///
/// This design system predates Material 3's role names and does not map onto
/// them cleanly — it has three ink levels, a separate fill blue and text
/// blue, and a warm/cool surface pair. So the scheme below is written by
/// hand from the tokens rather than seeded from one colour: a `fromSeed`
/// would invent tonal palettes the palette board never approved.
///
/// The scheme exists so the framework's own widgets (dialogs, snackbars,
/// cursors, selection handles) land on brand colours. Every widget in
/// `shared/ui` reads [AppColors] directly instead.
abstract final class AppColorScheme {
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,

    // Action. `blue` is the FILL and carries white at 4.94:1 (AA).
    primary: AppColors.blue,
    onPrimary: AppColors.surface,
    primaryContainer: AppColors.tint,
    onPrimaryContainer: AppColors.blueText,

    // Warm. Gold never carries a white label (1.58:1), so `onSecondary` is
    // ink — this is the one pairing in the system that is easy to get wrong.
    secondary: AppColors.gold,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.cream,
    onSecondaryContainer: AppColors.goldInk,

    // Anchor.
    tertiary: AppColors.navyDeep,
    onTertiary: AppColors.surface,
    tertiaryContainer: AppColors.navy,
    onTertiaryContainer: AppColors.surface,

    // Signals.
    error: AppColors.emergency,
    onError: AppColors.surface,

    // Surfaces.
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.field,
    surfaceContainer: AppColors.field,
    surfaceContainerHigh: AppColors.cream,
    surfaceContainerHighest: AppColors.tint,
    onSurfaceVariant: AppColors.ink2,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    shadow: AppColors.navyDeep,
    scrim: AppColors.navyDeep,
    inverseSurface: AppColors.navyDeep,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.blueSoft,
  );
}
