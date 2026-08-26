import 'package:flutter/material.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/date_labels.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../../shared/ui/organisms/organisms.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/clinical_record.dart';
import '../../domain/entities/history_entry.dart';

/// What an unset optional field reads as, matching `PersonalInfoScreen`. Not
/// an empty string: a blank value next to a label looks like a rendering bug.
const String _missing = 'Sin registrar';

/// One visit, in full — everything the server documented about it.
///
/// ## Why a screen and not more rows on the card
///
/// "Historial" is a list a patient SCANS: they are looking for one visit
/// among several years of them, and what identifies it is the specialty, the
/// date and the doctor. Clinical notes, a full prescription and the visit's
/// administrative detail are what they read once they have FOUND it. Putting
/// all of that on every card makes the first job impossible in order to save
/// one tap on the second — a five-visit history becomes a page and a half of
/// scrolling before the second entry is even visible.
///
/// So the card answers "which visit was this" and this screen answers "what
/// happened in it". The split is the same one `PersonalInfoScreen` makes
/// against the profile tab.
///
/// ## It reads no data of its own
///
/// The entry arrives fully built from [HistoryBloc], which already joined the
/// turn, its encounter and its prescriptions. That is not just convenience:
/// `/api/encounters/me` and `/api/prescriptions/me` each write a
/// `ClinicalAccessLog` row server-side, so a detail screen that re-fetched
/// would put a second audited read into a medical trail every time a patient
/// opened a card they had already loaded.
///
/// ## Why [entry] is nullable
///
/// It travels as `GoRouterState.extra`, which is an in-memory hand-off: it
/// does NOT survive a cold start on the same URL, a deep link, or a process
/// death and restore. Rather than crash on a null cast, that case renders as
/// what it is — the visit is not in memory — with the way back to the list
/// that can load it. Making the field nullable is what forces that branch to
/// exist at all.
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.entry});

  final HistoryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final HistoryEntry? entry = this.entry;
    if (entry == null) return const _EntryUnavailable();

    final Appointment appointment = entry.appointment;
    final EncounterRecord? encounter = entry.encounter;

    // The encounter's own date is what the DOCTOR recorded as the visit date;
    // `finishedAt` is when the clinic closed the turn. Either is truer than
    // the schedule's day, which is only when it was meant to happen.
    final DateTime? when =
        encounter?.visitDate ?? appointment.finishedAt ?? appointment.date;

    return AppScreen(
      topBar: AppTopBar(
        title: 'Detalle de la visita',
        onBack: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.section,
        children: <Widget>[
          const SizedBox(height: AppSpacing.section),

          _Header(
            title:
                appointment.speciality ??
                appointment.serviceName ??
                'Consulta',
            subtitle: when == null ? 'Fecha no registrada' : longDate(when),
            doctor:
                encounter?.doctorFullName ??
                appointment.doctorName ??
                'Doctor no registrado',
          ),

          _Group(
            kicker: 'La visita',
            rows: <AppSummaryRow>[
              AppSummaryRow(
                label: 'Fecha',
                value: when == null ? _missing : longDate(when),
              ),
              AppSummaryRow(
                label: 'Hora',
                value: appointment.time ?? _missing,
              ),
              // The number the waiting room called. A patient asked to quote
              // it at reception has nowhere else in the app to find it once
              // the turn has left "Mis citas".
              AppSummaryRow(
                label: 'Turno',
                value: appointment.ticket.toString(),
              ),
              AppSummaryRow(
                label: 'Servicio',
                value: appointment.serviceName ?? _missing,
              ),
              AppSummaryRow(
                label: 'Sede',
                value: appointment.locationName ?? _missing,
              ),
            ],
          ),

          if (encounter == null)
            const _NotDocumentedYet()
          else
            _Group(
              kicker: 'La consulta',
              rows: <AppSummaryRow>[
                AppSummaryRow(
                  label: 'Atendida por',
                  value: encounter.doctorFullName ??
                      appointment.doctorName ??
                      _missing,
                ),
                if (encounter.createdAt != null)
                  AppSummaryRow(
                    label: 'Registrada el',
                    value: longDate(encounter.createdAt!),
                  ),
              ],
              // Motivo, diagnostico and the clinical notes are prose, not
              // values: a doctor writes paragraphs into them, and an
              // `AppSummaryRow` puts its value on the right of the label
              // where a paragraph has no room. They get stacked blocks
              // instead, which is the only shape that can hold three lines
              // without pushing the label off screen.
              blocks: <Widget>[
                _Prose(label: 'Motivo de consulta', body: encounter.reasonForVisit),
                _Prose(label: 'Diagnostico', body: encounter.diagnosis),
                if (encounter.clinicalNotes != null)
                  _Prose(
                    label: 'Notas del medico',
                    body: encounter.clinicalNotes!,
                  ),
              ],
            ),

          if (entry.prescriptions.isNotEmpty) ...<Widget>[
            const AppKicker(text: 'Receta digital', size: 11),
            for (final PrescriptionRecord prescription in entry.prescriptions)
              _PrescriptionCard(prescription: prescription),
          ],
        ],
      ),
    );
  }
}

/// The visit was not handed to this route — see the screen's doc.
///
/// It says the record could not be RECOVERED, never that it does not exist:
/// telling a patient their visit is gone when the app simply lost a reference
/// in memory is the same class of lie as an empty state over a failed
/// request.
class _EntryUnavailable extends StatelessWidget {
  const _EntryUnavailable();

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      topBar: AppTopBar(
        title: 'Detalle de la visita',
        onBack: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sectionY),
          AppEmptyState(
            icon: AppIcons.history,
            title: 'No pudimos abrir esta visita',
            message:
                'Volve al historial y tocala de nuevo para ver el detalle '
                'completo.',
            actionLabel: 'Volver al historial',
            onAction: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// The identity block: what the visit was, when, and with whom.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.doctor,
  });

  final String title;
  final String subtitle;
  final String doctor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: <Widget>[
          const AppIconTile(icon: AppIcons.specialty, size: 42),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: <Widget>[
                Text(title, style: AppTypography.h3.copyWith(fontSize: 17)),
                Text(subtitle, style: AppTypography.cap),
                const SizedBox(height: AppSpacing.xs),
                Text(doctor, style: AppTypography.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One prescription: when it was issued, its general note, and every
/// medication on it.
///
/// A prescription is immutable server-side — `PrescriptionController` has no
/// `PUT` and no `DELETE` — so nothing here is editable and nothing offers to
/// be.
class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({required this.prescription});

  final PrescriptionRecord prescription;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: <Widget>[
          if (prescription.createdAt != null)
            AppSummaryRow(
              label: 'Emitida',
              value: longDate(prescription.createdAt!),
            ),

          // Every medication gets its OWN row with its OWN dosage —
          // collapsing a prescription into one paragraph loses exactly the
          // detail a patient needs to take the drug correctly.
          for (int i = 0; i < prescription.items.length; i++) ...<Widget>[
            if (i > 0 || prescription.createdAt != null) const AppHairline(),
            _PrescriptionItemRow(item: prescription.items[i]),
          ],

          // The doctor's note for the prescription AS A WHOLE ("tomar con
          // comida", "suspender si hay sarpullido") — distinct from a single
          // medication's `instructions`, and lost entirely until now.
          if (prescription.notes != null) ...<Widget>[
            const AppHairline(),
            _Prose(label: 'Indicaciones', body: prescription.notes!),
          ],
        ],
      ),
    );
  }
}

/// One medication line: what it is, how much, how often, for how long — and
/// the instructions when the doctor left any.
class _PrescriptionItemRow extends StatelessWidget {
  const _PrescriptionItemRow({required this.item});

  final PrescriptionItemEntry item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: <Widget>[
        Row(
          spacing: AppSpacing.sm,
          children: <Widget>[
            const Icon(AppIcons.prescription, size: 16, color: AppColors.ink3),
            Expanded(
              child: Text(
                item.medication,
                style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        AppSummaryRow(label: 'Dosis', value: item.dosage),
        AppSummaryRow(label: 'Frecuencia', value: item.frequency),
        AppSummaryRow(label: 'Duracion', value: item.duration),
        if (item.instructions != null)
          Text(item.instructions!, style: AppTypography.cap),
      ],
    );
  }
}

/// A label above a paragraph, for the free-text fields a doctor writes.
class _Prose extends StatelessWidget {
  const _Prose({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: <Widget>[
        Text(label, style: AppTypography.meta),
        Text(body, style: AppTypography.body),
      ],
    );
  }
}

/// An attended turn nobody has written up yet.
///
/// Stated as a fact about the record rather than as an error, because it is
/// one: documenting a visit is a separate action the doctor takes after the
/// turn (`POST /api/encounters`), and a visit the clinic recorded is still a
/// visit before someone writes it up.
class _NotDocumentedYet extends StatelessWidget {
  const _NotDocumentedYet();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: <Widget>[
        const AppKicker(text: 'La consulta', size: 11),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: <Widget>[
              const Icon(AppIcons.info, size: 16, color: AppColors.ink3),
              Expanded(
                child: Text(
                  'Esta visita todavia no tiene resumen clinico cargado. '
                  'Cuando el medico registre el diagnostico y la receta, los '
                  'vas a ver aca.',
                  style: AppTypography.cap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled group of rows inside one card, with optional prose blocks under
/// them. Same shape `PersonalInfoScreen._Group` draws, extended with the
/// paragraph slot a clinical record needs.
class _Group extends StatelessWidget {
  const _Group({
    required this.kicker,
    required this.rows,
    this.blocks = const <Widget>[],
  });

  final String kicker;
  final List<AppSummaryRow> rows;

  /// Free-text sections rendered under [rows], separated by hairlines.
  final List<Widget> blocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: <Widget>[
        AppKicker(text: kicker, size: 11),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: <Widget>[
              for (int i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0) const AppHairline(),
                rows[i],
              ],
              for (int i = 0; i < blocks.length; i++) ...<Widget>[
                // A rule between every section, including the first one when
                // there are rows above it to separate from.
                if (i > 0 || rows.isNotEmpty) const AppHairline(),
                blocks[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
