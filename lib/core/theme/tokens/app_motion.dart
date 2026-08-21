import 'package:flutter/animation.dart';

/// Design system motion.
///
/// One curve for the whole system. The Angular token sheet is explicit: the
/// brand easing is used in "toda animacion que no sea deliberadamente lineal
/// o a pasos". Linear belongs only to the things that must not accelerate —
/// the spinning CTA beam, the marquees — and everything else gets
/// [easeBrand].
abstract final class AppMotion {
  /// `--ease-brand: cubic-bezier(.22, .61, .36, 1)`.
  static const Cubic easeBrand = Cubic(0.22, 0.61, 0.36, 1);

  /// `spin 2.8s linear infinite` — the primary CTA's border beam.
  static const Duration spin = Duration(milliseconds: 2800);

  /// `ping 2s ease-out infinite` — the live dot's pulse.
  static const Duration ping = Duration(seconds: 2);

  /// `ping 2.6s` — the same keyframe, with the FAB's own timing.
  static const Duration pingFab = Duration(milliseconds: 2600);

  /// `rise 460ms var(--e) both` — the system's single entrance animation.
  static const Duration rise = Duration(milliseconds: 460);

  /// `tickdraw 340ms var(--e) 120ms forwards` — the confirmation check.
  static const Duration tickDraw = Duration(milliseconds: 340);
  static const Duration tickDrawDelay = Duration(milliseconds: 120);

  /// `shimmer 1.6s ease-in-out infinite` — the skeleton sweep.
  static const Duration shimmer = Duration(milliseconds: 1600);

  /// `.card { transition: transform 210ms, box-shadow 210ms }`.
  static const Duration card = Duration(milliseconds: 210);

  /// `.chip { transition: ... border-radius 300ms var(--e) }` and
  /// `.seg-thumb { transition: transform 300ms var(--e) }` — the two places
  /// where the system morphs a shape rather than just recolouring it.
  static const Duration morph = Duration(milliseconds: 300);

  /// The chips' colour transitions (`180ms linear`).
  static const Duration tone = Duration(milliseconds: 180);

  /// `.btn`'s press feedback (`transform 110ms var(--e)`) and its
  /// `background-color 160ms linear`.
  static const Duration press = Duration(milliseconds: 110);
  static const Duration fill = Duration(milliseconds: 160);

  /// `.panel { transition: opacity 240ms linear, transform 320ms var(--e) }`.
  static const Duration panelFade = Duration(milliseconds: 240);
  static const Duration panelSlide = Duration(milliseconds: 320);
}
