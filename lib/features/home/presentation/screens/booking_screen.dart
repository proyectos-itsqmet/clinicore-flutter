import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';

/// The "Agendar" tab — a direct port of the booking widget from
/// `design/Mobile.dc.html`'s AGENDA DEMO section.
///
/// Three numbered steps (doctor, day, time), then a summary panel that shows
/// the plan price before the user commits, then one primary action. The order
/// is the product's whole argument: "Elige, mira el valor y confirma."
///
/// Everything visual here comes from the board — the 22px gap between step
/// groups, the 11px step kickers, the 7px grid gaps, the four-column day and
/// time grids, the struck-through list price above the plan price, and the
/// confirmed state replacing the button rather than sitting next to it.
///
/// The data is sample data, labelled as such in the UI exactly as the board
/// labels its own ("Datos de ejemplo"). Wiring it to the availability
/// endpoint is the `blocs/` layer's job; the screen's contract is the shape
/// of the interaction, and that is complete.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const List<String> _types = <String>[
    'Consulta',
    'Control',
    'Telemedicina',
  ];

  static const List<String> _doctors = <String>[
    'Dr(a). [APELLIDO 1]',
    'Dr(a). [APELLIDO 2]',
    'Dr(a). [APELLIDO 3]',
  ];

  /// Weekday / date pairs, as the board draws them.
  static const List<(String, String)> _days = <(String, String)>[
    ('Lun', '10'),
    ('Mar', '11'),
    ('Mie', '12'),
    ('Jue', '13'),
    ('Vie', '14'),
    ('Sab', '15'),
    ('Lun', '17'),
  ];

  /// The board's own slot list, including the taken ones. A taken slot is
  /// shown struck through rather than removed: seeing that 08:40 is gone is
  /// what makes 09:00 feel like a real appointment instead of a suggestion.
  static const List<(String, bool)> _slots = <(String, bool)>[
    ('08:20', true),
    ('08:40', false),
    ('09:00', true),
    ('09:20', true),
    ('09:40', false),
    ('10:00', true),
    ('10:40', true),
    ('11:00', false),
    ('11:20', true),
    ('15:00', true),
    ('15:20', false),
    ('16:00', true),
  ];

  int _type = 0;
  int? _doctor;
  int? _day;
  int? _slot;
  bool _confirmed = false;

  bool get _complete => _doctor != null && _day != null && _slot != null;

  /// A new selection invalidates the booking — otherwise the confirmation
  /// would keep claiming a time the user has already moved away from.
  void _reset() => _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.pad,
          right: AppSpacing.pad,
          top: AppSpacing.sectionY * 0.5,
          // With `extendBody` on the shell, this is the nav bar's height.
          bottom: AppSpacing.sectionY * 0.5 + context.bottomSafeInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.section,
          children: <Widget>[
            const AppSectionHeading(
              kicker: 'Agenda en linea',
              title: 'Elige, mira el valor y confirma.',
            ),

            AppSegmented(
              options: _types,
              selectedIndex: _type,
              onChanged: (index) => setState(() {
                _type = index;
                _reset();
              }),
            ),

            // The board's white panel: `border-radius: 26px`, a `line`
            // hairline, `--shadow-lift-1`, 20px of padding and 22px between
            // step groups.
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadLg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.line),
                boxShadow: AppShadows.lift1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 22,
                children: <Widget>[
                  _Step(
                    label: '1 / Medico',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpacing.sm,
                      children: <Widget>[
                        for (int i = 0; i < _doctors.length; i++)
                          AppChip(
                            label: _doctors[i],
                            selected: _doctor == i,
                            expand: true,
                            onTap: () => setState(() {
                              _doctor = i;
                              _reset();
                            }),
                          ),
                      ],
                    ),
                  ),

                  _Step(
                    label: '2 / Dia',
                    child: _Grid(
                      children: <Widget>[
                        for (int i = 0; i < _days.length; i++)
                          AppDayChip(
                            weekday: _days[i].$1,
                            day: _days[i].$2,
                            selected: _day == i,
                            onTap: () => setState(() {
                              _day = i;
                              _reset();
                            }),
                          ),
                      ],
                    ),
                  ),

                  _Step(
                    label: '3 / Hora',
                    note:
                        'Los cupos tachados estan ocupados. '
                        'Datos de ejemplo.',
                    child: _Grid(
                      children: <Widget>[
                        for (int i = 0; i < _slots.length; i++)
                          AppChip(
                            label: _slots[i].$1,
                            selected: _slot == i,
                            disabled: !_slots[i].$2,
                            onTap: () => setState(() {
                              _slot = i;
                              _reset();
                            }),
                          ),
                      ],
                    ),
                  ),

                  _SummaryPanel(
                    doctor: _doctor == null ? '--' : _doctors[_doctor!],
                    day: _day == null
                        ? '--'
                        : '${_days[_day!].$1} ${_days[_day!].$2}',
                    time: _slot == null ? '--' : _slots[_slot!].$1,
                    complete: _complete,
                    confirmed: _confirmed,
                    onConfirm: () => setState(() => _confirmed = true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One numbered step: an 11px kicker, its control, and an optional note.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.child, this.note});

  final String label;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: <Widget>[
        AppKicker(text: label, size: 11),
        child,
        if (note != null) Text(note!, style: AppTypography.cap),
      ],
    );
  }
}

/// The board's `grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 7px`.
///
/// A [Wrap] would let a row of three sit at its natural width and break the
/// column alignment between the day grid and the time grid, so this stays a
/// real four-column grid.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  static const int _columns = 4;
  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    for (int i = 0; i < children.length; i += _columns) {
      final int end = (i + _columns).clamp(0, children.length);
      final List<Widget> cells = children.sublist(i, end);
      rows.add(
        Row(
          spacing: _gap,
          children: <Widget>[
            for (final Widget cell in cells) Expanded(child: cell),
            // Keeps a short final row's cells the same width as the rest,
            // instead of stretching them across the whole panel.
            for (int j = cells.length; j < _columns; j++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }

    return Column(spacing: _gap, children: rows);
  }
}

/// The nested summary: the field-toned panel inside the white one.
///
/// It uses [AppRadii.signatureSm] (`20px 20px 8px 20px`), which is the
/// signature corner at panel scale — the board nests the shape inside itself
/// rather than switching to a plain rectangle.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.doctor,
    required this.day,
    required this.time,
    required this.complete,
    required this.confirmed,
    required this.onConfirm,
  });

  final String doctor;
  final String day;
  final String time;
  final bool complete;
  final bool confirmed;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: AppRadii.signatureSm,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xl,
        children: <Widget>[
          Column(
            spacing: AppSpacing.md,
            children: <Widget>[
              AppSummaryRow(label: 'Medico', value: doctor),
              AppSummaryRow(label: 'Dia', value: day),
              AppSummaryRow(
                label: 'Hora',
                value: time,
                valueColor: complete ? AppColors.blueText : null,
              ),
            ],
          ),

          const AppHairline(),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: <Widget>[
              const AppSummaryRow(
                label: 'Consulta general',
                value: 'USD 30',
                strikethrough: true,
              ),
              AppSummaryRow(
                label: 'Con tu plan',
                value: 'USD 12',
                emphasis: const AppFigure(
                  value: 'USD 12',
                  size: 24,
                  color: AppColors.ok,
                ),
              ),
              Text('Valores aproximados.', style: AppTypography.cap),
            ],
          ),

          if (confirmed)
            _ConfirmedBar(time: time)
          else
            AppButton(
              label: 'Confirmar cita',
              fullWidth: true,
              // Disabled until all three steps are answered — the summary
              // above already shows exactly which one is still `--`.
              onPressed: complete ? onConfirm : null,
            ),
        ],
      ),
    );
  }
}

/// The confirmed state: the board's green pill, replacing the button.
///
/// It replaces rather than joins the CTA on purpose. Two controls where there
/// was one reads as "did it work?"; one control that changed reads as "done".
class _ConfirmedBar extends StatelessWidget {
  const _ConfirmedBar({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPad),
      decoration: const BoxDecoration(
        color: AppColors.ok,
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.md,
        children: <Widget>[
          const AppTick(),
          Text(
            'Reservado / $time',
            style: AppTypography.pill.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}
