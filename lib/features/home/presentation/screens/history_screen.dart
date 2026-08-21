import 'package:flutter/material.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';

/// The "Historial" tab — the clinical record.
///
/// Grouped by year, newest first, because that is how a person looks for a
/// past consultation ("that was the year of the surgery"). Within a year the
/// entries stay in reverse date order.
///
/// Each entry is a consultation, and each says what it LEFT the patient with
/// — a prescription, a lab result, a referral — as [AppPill]s. That is the
/// thing people come to a medical history for; the diagnosis text is context.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  /// Sample data, labelled as such in the UI.
  static const List<_HistoryYear> _years = <_HistoryYear>[
    _HistoryYear(
      year: '2026',
      entries: <_HistoryEntry>[
        _HistoryEntry(
          date: '06 oct',
          specialty: 'Medicina general',
          doctor: 'Dr(a). [APELLIDO 3]',
          summary:
              'Consulta por sintomas respiratorios. Signos vitales normales, '
              'sin fiebre al momento de la consulta.',
          outputs: <String>['Receta digital', 'Laboratorio'],
        ),
        _HistoryEntry(
          date: '18 ago',
          specialty: 'Cardiologia',
          doctor: 'Dr(a). [APELLIDO 2]',
          summary:
              'Control anual. Electrocardiograma sin hallazgos, presion '
              'dentro de rango.',
          outputs: <String>['Electrocardiograma'],
        ),
      ],
    ),
    _HistoryYear(
      year: '2025',
      entries: <_HistoryEntry>[
        _HistoryEntry(
          date: '02 dic',
          specialty: 'Pediatria',
          doctor: 'Dr(a). [APELLIDO 1]',
          summary: 'Control de nino sano y esquema de vacunacion al dia.',
          outputs: <String>['Certificado'],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool empty = _years.every((year) => year.entries.isEmpty);

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
            const AppSectionHeading(
              kicker: 'Tu historia',
              title: 'Historial clinico.',
              lead: 'Todo lo que paso, en un solo lugar y siempre contigo.',
            ),

            if (empty)
              const AppEmptyState(
                icon: AppIcons.history,
                title: 'Tu historial esta vacio',
                message:
                    'Despues de tu primera consulta vas a encontrar aca el '
                    'resumen, las recetas y los resultados.',
              )
            else ...<Widget>[
              for (final _HistoryYear year in _years) ...<Widget>[
                AppKicker(text: year.year, size: 11),
                for (final _HistoryEntry entry in year.entries)
                  _EntryCard(entry: entry),
              ],
              Text('Datos de ejemplo.', style: AppTypography.cap),
            ],
          ],
        ),
      ),
    );
  }
}

@immutable
class _HistoryYear {
  const _HistoryYear({required this.year, required this.entries});

  final String year;
  final List<_HistoryEntry> entries;
}

@immutable
class _HistoryEntry {
  const _HistoryEntry({
    required this.date,
    required this.specialty,
    required this.doctor,
    required this.summary,
    required this.outputs,
  });

  final String date;
  final String specialty;
  final String doctor;
  final String summary;

  /// What the visit produced. This is the part a patient comes back for.
  final List<String> outputs;
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {},
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: <Widget>[
          Row(
            spacing: AppSpacing.lg,
            children: <Widget>[
              const AppIconTile(icon: AppIcons.specialty, size: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: <Widget>[
                    Text(
                      entry.specialty,
                      style: AppTypography.h3.copyWith(fontSize: 17),
                    ),
                    Text(
                      '${entry.date} / ${entry.doctor}',
                      style: AppTypography.cap,
                    ),
                  ],
                ),
              ),
              const Icon(
                AppIcons.chevronRight,
                size: 16,
                color: AppColors.ink3,
              ),
            ],
          ),
          Text(entry.summary, style: AppTypography.body.copyWith(fontSize: 15)),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String output in entry.outputs)
                AppPill(label: output, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}
