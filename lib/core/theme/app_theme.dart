import 'package:flutter/material.dart';

import 'components/app_color_scheme.dart';
import 'components/app_input_theme.dart';
import 'components/app_text_theme.dart';
import 'tokens/tokens.dart';

/// The app's single [ThemeData].
///
/// There is no dark theme, and that is a design decision rather than an
/// omission: the palette board defines one set of surfaces (field / surface /
/// cream / tint) with contrast ratios measured against them. A dark variant
/// would need its own measured palette, not an inverted copy of this one.
///
/// Two things here are worth reading rather than skimming:
///
/// 1. **The ripple is switched off.** [NoSplash.splashFactory] is not a taste
///    call — the boards define exactly one press feedback for every
///    interactive element (`.btn:active { transform: translateY(1px) }`), and
///    a Material ink ripple on top of it would be a second, contradictory
///    signal. The atoms in `shared/ui` implement the translate instead.
///
/// 2. **`::selection` survives the port.** The one piece of loose UI chrome in
///    the CSS (`--color-selection`) maps 1:1 onto
///    [TextSelectionThemeData.selectionColor], so text selection in the app
///    looks like text selection on the site.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: AppColorScheme.light,
    textTheme: AppTextTheme.textTheme,
    fontFamily: AppTypography.sans,
    scaffoldBackgroundColor: AppColors.field,
    canvasColor: AppColors.field,
    dividerColor: AppColors.line,
    inputDecorationTheme: AppInputTheme.inputDecorationTheme,

    // See the class doc: the design's press feedback is a 1px translate, and
    // the atoms own it. A ripple would be a competing signal.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.blue,
      selectionColor: AppColors.selection,
      selectionHandleColor: AppColors.blue,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.field,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTypography.h3,
      iconTheme: IconThemeData(color: AppColors.ink, size: 22),
    ),

    iconTheme: const IconThemeData(color: AppColors.ink2, size: 22),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navyDeep,
      contentTextStyle: AppTypography.body.copyWith(
        color: AppColors.surface,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: AppColors.goldDeep,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.signatureSm),
      insetPadding: const EdgeInsets.all(AppSpacing.padChrome),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.signature),
      titleTextStyle: AppTypography.h3,
      contentTextStyle: AppTypography.body,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadii.panelLg),
          topRight: Radius.circular(AppRadii.panelLg),
        ),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.blue,
      linearTrackColor: AppColors.tint,
      circularTrackColor: AppColors.tint,
    ),

    // The design has no switches or checkboxes drawn, so these follow the
    // action tokens rather than inventing a new treatment.
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.blue
            : AppColors.surface,
      ),
      checkColor: const WidgetStatePropertyAll(AppColors.surface),
      side: const BorderSide(color: AppColors.line, width: 1.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(AppColors.surface),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.blue
            : AppColors.line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
