/// Molecules — atoms composed into a reusable unit.
///
/// A molecule may know the SHAPE of the data it renders (a label plus a
/// value, an icon plus a title plus a chevron) but still not the domain. It
/// takes strings and callbacks, never an `Appointment` or a `Patient`. The
/// moment a widget in here imports something from `features/`, it is an
/// organism or it belongs to that feature.
library;

export 'app_action_tile.dart';
export 'app_card.dart';
export 'app_day_chip.dart';
export 'app_empty_state.dart';
export 'app_list_row.dart';
export 'app_segmented.dart';
export 'app_summary_row.dart';
export 'password_rules_card.dart';
