/// The design system's flat token sheet.
///
/// These six files are the Flutter side of the Angular app's
/// `shared/tokens/theme.css` + `tokens.json`. There is no code generation
/// between the two projects: if a value changes on one side it must be
/// changed on the other by hand, which is exactly what the Angular token
/// sheet's own header warns about.
///
/// Import this barrel, never a single token file, so a widget always has the
/// whole vocabulary available and nobody is tempted to inline a value that
/// already has a name two files over.
library;

export 'app_colors.dart';
export 'app_motion.dart';
export 'app_radii.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_typography.dart';
