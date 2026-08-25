import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// The app's icon vocabulary.
///
/// Every icon the UI uses is named here once, by MEANING rather than by
/// shape — `appointments`, not `calendarCheck`. Two reasons, and the second
/// is the one that matters:
///
/// 1. Swapping the icon for a concept is a one-line change in this file
///    instead of a search across twenty screens.
/// 2. It makes an inconsistency impossible to miss. If "history" is
///    `clockCounterClockwise` in the nav and `fileText` on a card, that shows
///    up here as two entries for one idea — whereas spread across screens it
///    just looks like two unrelated icons.
///
/// **Style: Regular.** The design boards draw their icons as stroked SVG
/// paths at `stroke-width: 2` on a 24 viewBox. Phosphor's Regular weight is
/// the closest match in the family; Bold reads as heavier than the boards and
/// Fill contradicts them outright. Bold is used only where the board itself
/// draws a heavier stroke (2.2+), which in practice means chevrons.
///
/// `PhosphorIconData` is a `typedef` for [IconData] in this package version,
/// so these values pass anywhere an [IconData] is expected.
abstract final class AppIcons {
  // ==========================================================
  // NAVIGATION — the four bottom tabs
  // ==========================================================

  /// "Agendar" — booking a new appointment.
  static const IconData booking = PhosphorIconsRegular.calendarPlus;

  /// "Mis citas" — appointments already booked.
  static const IconData appointments = PhosphorIconsRegular.calendarCheck;

  /// "Historial" — past consultations. A clock running backwards, which is
  /// the same metaphor the web app's "Mi historia" tile uses.
  static const IconData history = PhosphorIconsRegular.clockCounterClockwise;

  /// "Mi perfil".
  static const IconData profile = PhosphorIconsRegular.userCircle;

  // ==========================================================
  // PROFILE ROWS
  // ==========================================================

  /// "Mi informacion" — identity data.
  static const IconData personalInfo = PhosphorIconsRegular.identificationCard;

  /// "Terminos y condiciones".
  static const IconData terms = PhosphorIconsRegular.scroll;

  /// "Politica de privacidad". A shield, not a padlock: the padlock is
  /// already taken by the password field and reusing it would say "secret"
  /// where this means "protected".
  static const IconData privacy = PhosphorIconsRegular.shieldCheck;

  static const IconData signOut = PhosphorIconsRegular.signOut;

  // ==========================================================
  // AUTH
  // ==========================================================

  static const IconData email = PhosphorIconsRegular.envelopeSimple;
  static const IconData password = PhosphorIconsRegular.lockKey;
  static const IconData identityCard = PhosphorIconsRegular.identificationCard;
  static const IconData person = PhosphorIconsRegular.user;
  static const IconData phone = PhosphorIconsRegular.phone;
  static const IconData biometrics = PhosphorIconsRegular.fingerprint;

  /// The password-visibility toggle.
  static const IconData reveal = PhosphorIconsRegular.eye;
  static const IconData conceal = PhosphorIconsRegular.eyeSlash;

  // ==========================================================
  // CLINICAL
  // ==========================================================

  static const IconData specialty = PhosphorIconsRegular.stethoscope;
  static const IconData prescription = PhosphorIconsRegular.pill;
  static const IconData results = PhosphorIconsRegular.fileText;
  static const IconData vitals = PhosphorIconsRegular.heartbeat;
  static const IconData emergency = PhosphorIconsRegular.firstAidKit;
  static const IconData location = PhosphorIconsRegular.mapPin;

  /// "Agendar" step 3's "elegir fecha" affordance — a single, PICKED day.
  /// Distinct from [booking] (calendar-plus: creating something new) and
  /// [appointments] (calendar-check: something already booked).
  static const IconData calendar = PhosphorIconsRegular.calendar;

  // ==========================================================
  // FEEDBACK AND CHROME
  // ==========================================================

  static const IconData success = PhosphorIconsRegular.checkCircle;
  static const IconData warning = PhosphorIconsRegular.warningCircle;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData whatsapp = PhosphorIconsRegular.whatsappLogo;

  /// Bold, because the boards draw their chevrons at `stroke-width: 2.2`.
  static const IconData chevronRight = PhosphorIconsBold.caretRight;
  static const IconData chevronLeft = PhosphorIconsBold.caretLeft;
  static const IconData arrowRight = PhosphorIconsBold.arrowRight;
}
