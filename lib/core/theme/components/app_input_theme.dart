import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// The text field treatment.
///
/// READ THIS BEFORE CHANGING IT. The design boards contain no form controls
/// at all — the landing page and the waiting-room screen never ask the user
/// to type. So unlike every other value in `theme/`, this one is **derived,
/// not copied**, and the derivation is written down here so it can be argued
/// with instead of guessed at again:
///
/// * **Shape and border** come from `.chip` in its unselected state:
///   `background: surface`, `border: 1.5px solid line`, `border-radius: 16px`.
///   A field and an unselected chip are the same thing conceptually — an
///   empty slot waiting for input — so they look the same.
/// * **Height** comes from `.btn` (54px), not from `.chip` (46px). A field is
///   a primary-sized control that a thumb has to hit, and it sits in the same
///   vertical stack as the submit button; matching the button keeps that
///   stack even.
/// * **Focus** is [AppColors.blue] at 2px. The boards' focus ring is
///   `outline: 3px solid #0071CE; outline-offset: 3px`, which is a ring
///   *outside* the box — Material's [InputDecorator] draws its state on the
///   border itself, so the ring becomes a thicker border in the same colour.
///   The `focusColor`/`outline` distinction is preserved: an unfocused field
///   is never blue.
/// * **Error** is [AppColors.emergency], the system's only failure colour,
///   which carries white at 5.72:1 and reads as red on [AppColors.field].
///
/// Labels are NOT floating. The booking widget labels each input group with a
/// small kicker above it (`1 / Medico`, `2 / Dia`, `3 / Hora`), so
/// `AppTextField` renders its label the same way and this theme leaves
/// `labelStyle` for the cases where a framework widget supplies its own.
abstract final class AppInputTheme {
  /// Matches `.btn`'s `min-height: 54px`.
  static const double minHeight = 54;

  static final InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    isDense: false,
    constraints: const BoxConstraints(minHeight: minHeight),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xxl,
      vertical: AppSpacing.xxl,
    ),
    hintStyle: AppTypography.body.copyWith(
      color: AppColors.ink3,
      fontWeight: FontWeight.w400,
    ),
    labelStyle: AppTypography.meta.copyWith(color: AppColors.ink3),
    floatingLabelStyle: AppTypography.meta.copyWith(color: AppColors.blueText),
    helperStyle: AppTypography.cap,
    errorStyle: AppTypography.cap.copyWith(
      color: AppColors.emergency,
      fontWeight: FontWeight.w600,
    ),
    prefixIconColor: AppColors.ink3,
    suffixIconColor: AppColors.ink3,
    enabledBorder: _border(AppColors.line),
    border: _border(AppColors.line),
    focusedBorder: _border(AppColors.blue, width: 2),
    errorBorder: _border(AppColors.emergency),
    focusedErrorBorder: _border(AppColors.emergency, width: 2),
    disabledBorder: _border(AppColors.line),
  );

  static OutlineInputBorder _border(Color color, {double width = 1.5}) {
    return OutlineInputBorder(
      borderRadius: AppRadii.tileLgAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
