import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../widgets/appointment_card.dart';

/// The "Mis citas" tab — what is booked.
///
/// Split into upcoming and past by a segmented control rather than by two
/// scrolling sections, because the two answer different questions ("when do I
/// have to be there?" vs "when was I last seen?") and mixing them makes the
/// first one harder.
///
/// The empty state is not an afterthought here: a new account has zero
/// appointments, and an empty tab that shows only background colour reads as
/// a failed load. It offers the way out — go book one.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  static const List<String> _filters = <String>['Proximas', 'Pasadas'];

  int _filter = 0;

  /// Sample data, labelled as such below — the same convention the design
  /// boards use for figures they cannot invent.
  static const List<AppointmentCard> _upcoming = <AppointmentCard>[
    AppointmentCard(
      weekday: 'Mie',
      day: '12',
      month: 'nov',
      specialty: 'Pediatria',
      doctor: 'Dr(a). [APELLIDO 1]',
      time: '09:00 / bloque de 30 min',
      location: 'Sede [NOMBRE]',
    ),
    AppointmentCard(
      weekday: 'Vie',
      day: '21',
      month: 'nov',
      specialty: 'Cardiologia',
      doctor: 'Dr(a). [APELLIDO 2]',
      time: '15:20 / bloque de 40 min',
      location: 'Sede [NOMBRE]',
      status: AppointmentStatus.pending,
    ),
  ];

  static const List<AppointmentCard> _past = <AppointmentCard>[
    AppointmentCard(
      weekday: 'Lun',
      day: '06',
      month: 'oct',
      specialty: 'Medicina general',
      doctor: 'Dr(a). [APELLIDO 3]',
      time: '08:20',
      location: 'Sede [NOMBRE]',
      status: AppointmentStatus.attended,
    ),
  ];

  List<AppointmentCard> get _visible => _filter == 0 ? _upcoming : _past;

  @override
  Widget build(BuildContext context) {
    final List<AppointmentCard> items = _visible;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.pad,
          right: AppSpacing.pad,
          top: AppSpacing.sectionY * 0.5,
          bottom: AppSpacing.sectionY * 0.5 + context.bottomSafeInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.section,
          children: <Widget>[
            const AppSectionHeading(kicker: 'Tus turnos', title: 'Mis citas.'),

            AppSegmented(
              options: _filters,
              selectedIndex: _filter,
              onChanged: (index) => setState(() => _filter = index),
            ),

            if (items.isEmpty)
              AppEmptyState(
                icon: AppIcons.appointments,
                title: _filter == 0
                    ? 'No tienes citas agendadas'
                    : 'Todavia no tienes citas pasadas',
                message: _filter == 0
                    ? 'Cuando reserves un turno lo vas a ver aca, con la '
                          'hora exacta y la sede.'
                    : 'Aca van a quedar las consultas que ya pasaron.',
                actionLabel: _filter == 0 ? 'Agendar una cita' : null,
                // Switches tabs instead of pushing a route: the booking
                // screen already exists as a branch, and pushing a second
                // copy over the shell would hide the nav the user needs.
                onAction: _filter == 0
                    ? () => StatefulNavigationShell.of(context).goBranch(0)
                    : null,
              )
            else ...<Widget>[
              for (final AppointmentCard item in items) item,
              Text('Datos de ejemplo.', style: AppTypography.cap),
            ],
          ],
        ),
      ),
    );
  }
}
