import 'package:flutter/material.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../../shared/ui/organisms/organisms.dart';

/// One numbered clause of a legal document.
@immutable
class LegalClause {
  const LegalClause({required this.title, required this.body});

  final String title;
  final List<String> body;
}

/// The reading layout for the terms and the privacy policy.
///
/// Long-form legal text is the one place in this app where the type scale
/// matters more than the layout, so this does very little: `body` at 16/1.6
/// on the page ground, a numbered `h3` per clause, and generous space between
/// them. No cards — a card per clause would turn a document into a list and
/// make it harder to read straight through, which is the only way anyone ever
/// reads one of these.
///
/// The banner at the top exists because of what it says. **The clause text
/// these screens ship with is structural placeholder copy.** It describes the
/// shape a Terms document and a Privacy Policy need, in the right order, with
/// the right headings — but it is NOT legal text and must be replaced by the
/// clinic's own counsel before release. Shipping invented terms for a health
/// application is not a cosmetic problem: in Ecuador a health provider is
/// bound by the Ley Organica de Proteccion de Datos Personales, and consent
/// collected against text nobody authorised is not consent.
///
/// The banner is deliberately hard to miss and deliberately easy to delete —
/// pass `showDraftNotice: false` once the real text is in.
class LegalDocument extends StatelessWidget {
  const LegalDocument({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.clauses,
    this.showDraftNotice = true,
  });

  final String title;

  /// Shown as a pill under the heading. A legal document with no date is
  /// unciteable.
  final String lastUpdated;

  final String intro;
  final List<LegalClause> clauses;
  final bool showDraftNotice;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      topBar: AppTopBar(
        title: title,
        onBack: () => Navigator.of(context).pop(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.section,
        children: <Widget>[
          const SizedBox(height: AppSpacing.section),

          Text(title, style: AppTypography.h2),
          Align(
            alignment: Alignment.centerLeft,
            child: AppPill(
              label: 'Actualizado: $lastUpdated',
              tone: AppPillTone.plain,
              dense: true,
            ),
          ),
          Text(intro, style: AppTypography.lead),

          if (showDraftNotice) const _DraftNotice(),

          for (int i = 0; i < clauses.length; i++) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text('${i + 1}. ${clauses[i].title}', style: AppTypography.h3),
            for (final String paragraph in clauses[i].body)
              Text(paragraph, style: AppTypography.body),
          ],

          const SizedBox(height: AppSpacing.sectionY),
        ],
      ),
    );
  }
}

/// The "this is not the real text yet" banner.
///
/// `gold` rather than `emergency`: this is a caution to the team building the
/// app, not an error shown to a patient in the middle of something. The
/// emergency red is reserved for the 24/7 line and for actual failures.
class _DraftNotice extends StatelessWidget {
  const _DraftNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: <Widget>[
          const AppIconTile(
            icon: AppIcons.warning,
            size: 34,
            tone: AppIconTileTone.gold,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: <Widget>[
                Text(
                  'Texto de estructura, no texto legal',
                  style: AppTypography.h3.copyWith(fontSize: 15),
                ),
                Text(
                  'Este documento tiene la forma y el orden correctos, pero '
                  'su contenido debe ser redactado y aprobado por el area '
                  'legal de la clinica antes de publicar la app.',
                  style: AppTypography.cap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
