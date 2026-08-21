import 'package:flutter/painting.dart';

/// Design system corner radii.
///
/// From the design brief: "tarjeta 24 con esquina firma asimetrica
/// 24/24/8/24" / "panel de foto 28-32" / "pildora 999" / "tile de icono
/// 12-16".
abstract final class AppRadii {
  /// Card radius, and the 3 corners that respect the signature shape.
  static const double card = 24;

  /// The 4th corner (bottom-right) of the signature shape.
  static const double cardNub = 8;

  /// Smaller photo/feature panel — low end of the 28-32 range.
  static const double panelSm = 28;

  /// Larger standalone panel (e.g. the booking widget) — high end.
  static const double panelLg = 32;

  /// Pills, buttons, chips-as-pill.
  static const double pill = 9999;

  /// Icon tile — low end of the 12-16 range.
  static const double tileSm = 12;

  /// Icon tile — high end of the 12-16 range.
  static const double tileLg = 16;

  /// THE shape of this design system: `border-radius: 24px 24px 8px 24px`.
  ///
  /// Three corners at [card], the bottom-right pinched to [cardNub]. Every
  /// card-shaped surface composes this instead of redrawing it — if you find
  /// yourself hand-rolling a `BorderRadius.only` for a card, you are about
  /// to break the signature.
  static const BorderRadius signature = BorderRadius.only(
    topLeft: Radius.circular(card),
    topRight: Radius.circular(card),
    bottomRight: Radius.circular(cardNub),
    bottomLeft: Radius.circular(card),
  );

  /// The signature shape at panel scale — `20px 20px 8px 20px`, which the
  /// boards use for inner summary panels and the hero status strip.
  static const BorderRadius signatureSm = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomRight: Radius.circular(cardNub),
    bottomLeft: Radius.circular(20),
  );

  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius tileSmAll = BorderRadius.all(
    Radius.circular(tileSm),
  );
  static const BorderRadius tileLgAll = BorderRadius.all(
    Radius.circular(tileLg),
  );
  static const BorderRadius panelSmAll = BorderRadius.all(
    Radius.circular(panelSm),
  );
  static const BorderRadius panelLgAll = BorderRadius.all(
    Radius.circular(panelLg),
  );
}
