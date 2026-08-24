/// The date vocabulary the design boards use.
///
/// ## Why not `intl`
///
/// `intl` is already a dependency, so reaching for `DateFormat.E('es')` is the
/// obvious move. Two things make it the wrong one here:
///
/// 1. **It would throw.** `DateFormat` with a locale needs
///    `initializeDateFormatting('es')` to have run, and `main.dart` never calls
///    it. Adding that call is a real change with a bundle cost, for output we
///    would then have to correct anyway — see (2).
/// 2. **Its output is not the boards'.** `DateFormat.E('es')` yields `mié.`
///    and `MMM` yields `nov.` — accented, with a trailing period. Every date
///    chip in `design/Mobile.dc.html` is drawn as `Mie` and `nov`: no accent,
///    no period, weekday capitalised and month lowercase. Munging intl's
///    output back into that is more code than the two lists below, and it
///    hides where the strings actually come from.
///
/// The app is single-locale by construction — `app.dart` declares
/// `supportedLocales: [Locale('es')]` — so there is no second language these
/// tables would have to grow for. If one ever arrives, THAT is when
/// `initializeDateFormatting` earns its place.
library;

/// `DateTime.weekday` is 1..7 with Monday = 1, so index 0 is unused.
const List<String> _weekdays = <String>[
  '',
  'Lun',
  'Mar',
  'Mie',
  'Jue',
  'Vie',
  'Sab',
  'Dom',
];

/// `DateTime.month` is 1..12, so index 0 is unused.
const List<String> _months = <String>[
  '',
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// `Mie`. Capitalised, unaccented — the boards' date chip.
String weekdayLabel(DateTime date) => _weekdays[date.weekday];

/// `nov`. Lowercase, no trailing period.
String monthLabel(DateTime date) => _months[date.month];

/// `12`, always two digits, so a column of dates does not jitter.
String dayLabel(DateTime date) => date.day.toString().padLeft(2, '0');

/// `06 oct` — the history entry's date line.
String shortDate(DateTime date) => '${dayLabel(date)} ${monthLabel(date)}';

/// `12 nov 2026` — used where the year is not already a heading.
String longDate(DateTime date) => '${shortDate(date)} ${date.year}';
