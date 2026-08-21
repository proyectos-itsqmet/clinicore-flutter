/// Organisms — a whole region of a screen.
///
/// An organism composes molecules and atoms into something a user would name:
/// the bottom navigation, the page shell, the auth header. It may hold layout
/// decisions that only make sense at page scale (safe areas, backdrop blur,
/// what collapses when the keyboard opens).
///
/// It still takes its content from above. An organism that fetches or knows
/// about domain state belongs in `features/`.
library;

export 'app_auth_hero.dart';
export 'app_bottom_nav.dart';
export 'app_screen.dart';
export 'app_top_bar.dart';
