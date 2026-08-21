import 'package:flutter/widgets.dart';

/// Viewport conveniences used by the screens.
///
/// These are the three [MediaQuery] reads that actually appear over and over
/// in this app, given a portrait-locked phone layout: how tall the keyboard
/// is, whether it is up at all, and where the safe area ends. Everything else
/// (breakpoints, orientation) is deliberately absent — the app does not
/// rotate, so a responsive helper here would be dead code pretending to be
/// architecture.
extension BuildContextViewport on BuildContext {
  /// Height taken by the on-screen keyboard, 0 when it is down.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  /// True while the soft keyboard is up. Auth screens use this to collapse
  /// their hero so the fields stay visible.
  bool get isKeyboardOpen => keyboardInset > 0;

  /// Bottom safe-area inset — the home indicator on iOS, the gesture bar on
  /// Android. The bottom navigation adds this to its own padding so it never
  /// sits under the system gesture area.
  double get bottomSafeInset => MediaQuery.paddingOf(this).bottom;

  /// Top safe-area inset — the notch / status bar. The auth hero draws behind
  /// it on purpose and pads its content by this amount.
  double get topSafeInset => MediaQuery.paddingOf(this).top;

  Size get screenSize => MediaQuery.sizeOf(this);
}
