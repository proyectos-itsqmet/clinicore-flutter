import 'dart:ui' show Color;

/// Design system colours — the Flutter mirror of the Angular app's
/// `shared/tokens/theme.css`.
///
/// THIS IS THE ONLY FILE IN THE ENTIRE APP WHERE A LITERAL COLOUR MAY
/// APPEAR. Every other file (atoms, molecules, organisms, features) must
/// reach these values through this class. If you are about to type
/// `Color(0x...)` anywhere else, stop: either the token already exists, or
/// the design has grown a new role and it belongs here first.
///
/// Source of truth: `design/Palette.dc.html` (roles + measured contrast
/// ratios) and `design/Mobile.dc.html` (the same `:root` block).
///
/// Values are grouped by ROLE, exactly like the "Sistema de color" section
/// of `Palette.dc.html` ("agrupado por rol, nunca por matiz") — do not
/// re-sort this file alphabetically or by hue.
abstract final class AppColors {
  // ==========================================================
  // SURFACES (Palette.dc.html: "Superficies")
  // ==========================================================

  /// Page background.
  static const Color field = Color(0xFFFAF7F3);

  /// Card background.
  static const Color surface = Color(0xFFFFFFFF);

  /// Warm section band (e.g. Especialidades).
  static const Color cream = Color(0xFFFFF1E0);

  /// Cool fill for icon tiles and chips.
  static const Color tint = Color(0xFFEAF2FC);

  /// Card borders, hairlines.
  static const Color line = Color(0xFFE4DCD2);

  // ==========================================================
  // INK (Palette.dc.html: "Tinta")
  // ==========================================================

  /// Primary text, headings. 15.53:1 on [surface], 14.55:1 on [field] (AAA).
  static const Color ink = Color(0xFF13243F);

  /// Body copy (lead, body). 7.24:1 on [surface] (AAA).
  static const Color ink2 = Color(0xFF41587A);

  /// Metadata, secondary text. 5.77:1 on [surface] (AA).
  static const Color ink3 = Color(0xFF526785);

  // ==========================================================
  // ANCHOR (Palette.dc.html: "Anclaje")
  // ==========================================================

  /// Dark institutional backgrounds.
  static const Color navy = Color(0xFF123E68);

  /// Hero background, scrim. White on top measures 14.36:1 (AAA).
  static const Color navyDeep = Color(0xFF0C2B4B);

  // ==========================================================
  // ACTION (Palette.dc.html: "Acción")
  // ==========================================================

  /// Primary CTA fill; white label on top measures 4.94:1 (AA).
  static const Color blue = Color(0xFF0071CE);

  /// Links and icons on light backgrounds. 5.97:1 on [surface] (AA).
  ///
  /// Never use [blue] for text on a light surface — it is a FILL token.
  static const Color blueText = Color(0xFF0064B8);

  /// Fills; ring progress arcs.
  static const Color blueBright = Color(0xFF1799DC);

  /// Soft chips and states; the hero eyebrow tone.
  static const Color blueSoft = Color(0xFFA8CBF0);

  // ==========================================================
  // WARM (Palette.dc.html: "Cálido")
  // ==========================================================

  /// Live turn number, kickers, the "cupos" figure.
  ///
  /// Carries [ink] at 9.86:1 (AAA) and NEVER a white label — white on gold
  /// measures 1.58:1 and fails outright. For light ink on a dark ground use
  /// [goldDeep]; for dark ink on gold or cream use [goldInk].
  static const Color gold = Color(0xFFFFC600);

  /// Ink on top of gold or cream in kickers. 5.74:1 on [cream] (AA).
  static const Color goldInk = Color(0xFF7A5A06);

  /// Gold on dark backgrounds. 6.54:1 on [navyDeep].
  static const Color goldDeep = Color(0xFFE0A800);

  // ==========================================================
  // SIGNALS (Palette.dc.html: "Señales")
  // ==========================================================

  /// 24/7 emergency button and card; white on top measures 5.72:1 (AA).
  ///
  /// Unusable on [navyDeep] (2.19:1) — use [goldDeep] for a caution label
  /// on a dark surface.
  static const Color emergency = Color(0xFFCC0B39);

  /// WhatsApp button. Carries [ink] at 7.83:1 (AAA).
  static const Color wa = Color(0xFF25D366);

  /// Review stars fill — same value as [gold], distinct role.
  static const Color star = Color(0xFFFFC600);

  /// Review star outline: gold-on-white is 1.6:1 (FAIL), this ring
  /// measures 3.68:1 and is what actually makes the star legible.
  static const Color starRing = Color(0xFFA87F00);

  /// Confirmations, correct state.
  static const Color ok = Color(0xFF0E7C55);

  /// Live dot, pulse.
  static const Color live = Color(0xFF34D399);

  // ==========================================================
  // CHROME
  // One-off UI-chrome colour from the design boards that isn't part of a
  // named palette role but still must not leak out as a literal.
  // ==========================================================

  /// Text selection background.
  static const Color selection = Color(0xFFFFF0B8);
}
