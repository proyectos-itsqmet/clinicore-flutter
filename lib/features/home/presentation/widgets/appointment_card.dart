import 'package:flutter/material.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';

/// How an appointment currently stands.
enum AppointmentStatus {
  /// Confirmed and in the future.
  confirmed,

  /// Booked but waiting on something — a payment, an insurer authorisation.
  pending,

  /// Already attended.
  attended,

  /// Cancelled by either side.
  cancelled,
}

/// One appointment, as a card.
///
/// The date is a block on the left rather than a line of text, because the
/// date is what the user scans a list of appointments for. It reuses the
/// booking day chip's vocabulary — `tint` fill, 16px radius, weekday over a
/// tabular figure — so a date looks like a date everywhere in the app.
///
/// The status is an [AppPill], not a coloured card. A card that turns red for
/// a cancellation shouts; a pill states. And the pill's tone map below is the
/// palette board's, not a guess: `ok` for confirmed, warm `gold` for waiting,
/// `plain` for the past, and only an actual cancellation gets the emergency
/// red — on white, as text, never as a fill.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.weekday,
    required this.day,
    required this.month,
    required this.specialty,
    required this.doctor,
    required this.time,
    required this.location,
    this.status = AppointmentStatus.confirmed,
    this.onTap,
    this.actions,
  });

  final String weekday;
  final String day;
  final String month;
  final String specialty;
  final String doctor;
  final String time;
  final String location;
  final AppointmentStatus status;
  final VoidCallback? onTap;

  /// Trailing controls — "Reprogramar", "Cancelar". Rendered under a hairline
  /// so they read as actions on the card rather than more of its content.
  final List<Widget>? actions;

  String get _statusLabel => switch (status) {
    AppointmentStatus.confirmed => 'Confirmada',
    AppointmentStatus.pending => 'Por confirmar',
    AppointmentStatus.attended => 'Atendida',
    AppointmentStatus.cancelled => 'Cancelada',
  };

  AppPillTone get _statusTone => switch (status) {
    AppointmentStatus.confirmed => AppPillTone.ok,
    AppointmentStatus.pending => AppPillTone.gold,
    AppointmentStatus.attended => AppPillTone.plain,
    AppointmentStatus.cancelled => AppPillTone.plain,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xl,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xl,
            children: <Widget>[
              _DateBlock(weekday: weekday, day: day, month: month),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.md,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            specialty,
                            style: AppTypography.h3.copyWith(fontSize: 17),
                          ),
                        ),
                        AppPill(
                          label: _statusLabel,
                          tone: _statusTone,
                          dense: true,
                        ),
                      ],
                    ),
                    Text(doctor, style: AppTypography.meta),
                    const SizedBox(height: AppSpacing.xxs),
                    _MetaLine(icon: AppIcons.appointments, text: time),
                    _MetaLine(icon: AppIcons.location, text: location),
                  ],
                ),
              ),
            ],
          ),
          if (actions != null && actions!.isNotEmpty) ...<Widget>[
            const AppHairline(),
            Row(spacing: AppSpacing.md, children: actions!),
          ],
        ],
      ),
    );
  }
}

/// The date block: the day chip's treatment, but static.
class _DateBlock extends StatelessWidget {
  const _DateBlock({
    required this.weekday,
    required this.day,
    required this.month,
  });

  final String weekday;
  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.tint,
        borderRadius: AppRadii.tileLgAll,
      ),
      child: Column(
        spacing: AppSpacing.xxs,
        children: <Widget>[
          Text(
            weekday,
            style: AppTypography.cap.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.blueText,
            ),
          ),
          AppFigure(value: day, size: 22, color: AppColors.ink),
          Text(
            month,
            style: AppTypography.cap.copyWith(
              fontSize: 11,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.sm,
      children: <Widget>[
        Icon(icon, size: 14, color: AppColors.ink3),
        Expanded(
          child: Text(
            text,
            style: AppTypography.cap,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
