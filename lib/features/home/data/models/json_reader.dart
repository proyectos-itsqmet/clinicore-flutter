/// Tolerant readers for the QMS wire format.
///
/// Every model in this feature parses through these instead of casting. The
/// reason is a rule this app already states in `AuthResponseModel`: a client
/// that throws on a missing or oddly-typed key turns a cosmetic backend change
/// into a crash on a screen the patient needs.
///
/// The QMS backend gives three concrete reasons to be careful:
///
/// * **Money and ids come back as either `int` or `double`.** Jackson
///   serialises a `Float` field as `12.0` and a `Long` as `12`, and Dart will
///   not let you read one as the other.
/// * **Dates are date-only strings** (`"2026-08-24"`), not ISO instants.
///   `DateTime.parse` handles that, but it produces a LOCAL midnight, which is
///   what we want — see [readDate].
/// * **Times are `HH:mm:ss`**, and the seconds are never meaningful.
library;

String readString(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? readStringOrNull(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int readInt(Object? value, {int fallback = 0}) => switch (value) {
  final int v => v,
  final double v => v.toInt(),
  final String v => int.tryParse(v) ?? fallback,
  _ => fallback,
};

int? readIntOrNull(Object? value) => switch (value) {
  final int v => v,
  final double v => v.toInt(),
  final String v => int.tryParse(v),
  _ => null,
};

double readDouble(Object? value, {double fallback = 0}) => switch (value) {
  final double v => v,
  final int v => v.toDouble(),
  final String v => double.tryParse(v) ?? fallback,
  _ => fallback,
};

double? readDoubleOrNull(Object? value) => switch (value) {
  final double v => v,
  final int v => v.toDouble(),
  final String v => double.tryParse(v),
  _ => null,
};

bool readBool(Object? value, {bool fallback = false}) =>
    value is bool ? value : fallback;

/// A nested object, or an empty map when the server sent null.
///
/// Returning `{}` rather than null lets a caller keep chaining reads without a
/// null check per level — the leaf readers already tolerate a missing key.
Map<String, dynamic> readMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> readMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map<Object?, Object?>>().map(readMap).toList();
}

/// A date-only string (`"2026-08-24"`) or a full ISO instant.
///
/// `DateTime.parse('2026-08-24')` yields LOCAL midnight, not UTC midnight, and
/// that is the behaviour we want: the appointment is on the 24th in the
/// clinic's timezone, and converting through UTC is how a 00:00 appointment
/// starts displaying as the 23rd for anyone west of Greenwich.
DateTime? readDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

/// `"09:30:00"` becomes `"09:30"`.
///
/// The seconds are always zero — `Schedule.hour` is a `LocalTime` built from
/// whole minutes — and a slot chip that says `09:30:00` is three characters of
/// noise in a four-column grid.
String? readTime(Object? value) {
  final String? raw = readStringOrNull(value);
  if (raw == null) return null;
  final List<String> parts = raw.split(':');
  if (parts.length < 2) return raw;
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}
