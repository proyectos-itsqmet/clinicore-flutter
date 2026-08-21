/// Design system spacing.
///
/// The mobile board is 390px wide and gutters everything with a single `.pad`
/// rule — `padding-left: 20px; padding-right: 20px`. That 20 is the only
/// horizontal number in the whole layout, which is why it earns a name.
///
/// The rest is the board's own gap ladder. This is deliberately NOT a generic
/// 4pt scale invented here: every value below appears verbatim in
/// `design/Mobile.dc.html`.
abstract final class AppSpacing {
  /// `.pad` — the page gutter. Every screen's horizontal inset.
  static const double pad = 20;

  /// The nav/header gutter, which sits tighter than the page body
  /// (`header { padding: 12px 16px }`).
  static const double padChrome = 16;

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 7;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 14;
  static const double xxl = 16;
  static const double section = 20;

  /// Card inner padding: 16 in the task-rail tiles, 18 in content cards,
  /// 20 in the booking panel.
  static const double cardPadSm = 16;
  static const double cardPad = 18;
  static const double cardPadLg = 20;

  /// A section's vertical padding — the board's `padding: 48px 0`.
  static const double sectionY = 48;

  /// Minimum touch target. Every interactive atom in the boards bottoms out
  /// at 44 (`.pill`, the nav icon button, a `.seg` option) — the same floor
  /// Apple and Google both publish, so it is not a coincidence to round off.
  static const double touchMin = 44;
}
