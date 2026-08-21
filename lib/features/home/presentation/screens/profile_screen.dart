import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';

/// The "Mi perfil" tab.
///
/// An identity card at the top, then the three destinations, then the way
/// out. The order is deliberate: who you are, what you can read, and only at
/// the very bottom the action you cannot undo by accident.
///
/// "Cerrar sesion" is separated from the three rows by real space rather than
/// sitting fourth in the list — a destructive action one thumb-width below
/// "Politica de privacidad" gets tapped by mistake.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const AppSectionHeading(kicker: 'Tu cuenta', title: 'Mi perfil.'),

            const _IdentityCard(
              name: '[NOMBRE DEL PACIENTE]',
              cedula: '[CEDULA]',
            ),

            // The three destinations the brief asks for.
            AppListRow(
              icon: AppIcons.personalInfo,
              label: 'Mi informacion',
              supporting: 'Datos personales y de contacto',
              onTap: () => context.push(AppPath.personalInfoScreen),
            ),
            AppListRow(
              icon: AppIcons.terms,
              label: 'Terminos y condiciones',
              supporting: 'Lo que aceptaste al crear la cuenta',
              onTap: () => context.push(AppPath.termsScreen),
            ),
            AppListRow(
              icon: AppIcons.privacy,
              label: 'Politica de privacidad',
              supporting: 'Como tratamos tus datos de salud',
              onTap: () => context.push(AppPath.privacyScreen),
            ),

            // Real distance, not a fourth list item.
            const SizedBox(height: AppSpacing.xxl),

            AppListRow(
              icon: AppIcons.signOut,
              label: 'Cerrar sesion',
              danger: true,
              onTap: () => _confirmSignOut(context),
            ),

            Center(
              child: Text(
                'CliniCore / version de desarrollo',
                style: AppTypography.cap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Signing out on a shared phone loses nothing, but on a personal one it
  /// means re-entering a password to see tomorrow's appointment. Worth one
  /// tap of confirmation.
  Future<void> _confirmSignOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesion?'),
        content: const Text(
          'Vas a tener que ingresar de nuevo para ver tus citas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: AppTypography.button.copyWith(color: AppColors.ink2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cerrar sesion',
              style: AppTypography.button.copyWith(color: AppColors.emergency),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Report the intent; do NOT navigate. AuthBloc clears the token, the
    // router's refreshListenable notices the session is gone, and the guard
    // sends the app to login. One place decides where an unauthenticated
    // patient belongs — see AppRouter._redirect.
    context.read<AuthBloc>().add(const AuthSignOutRequested());
  }
}

/// The identity header: initials, name, cedula, role.
///
/// The avatar is initials on `navy-deep` rather than a photo placeholder. A
/// grey silhouette says "your profile is incomplete" about something the
/// patient was never asked for; initials say who you are with the data the
/// clinic already has.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.name, required this.cedula});

  final String name;
  final String cedula;

  /// Up to two initials from the display name. Falls back to a single glyph
  /// rather than rendering an empty circle.
  String get _initials {
    final List<String> parts = name
        .replaceAll(RegExp(r'[\[\]]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Row(
        spacing: AppSpacing.xl,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.navyDeep,
            ),
            child: Text(
              _initials,
              style: AppTypography.h3.copyWith(color: AppColors.surface),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: <Widget>[
                Text(name, style: AppTypography.h3.copyWith(fontSize: 17)),
                Text('Cedula $cedula', style: AppTypography.cap),
                const SizedBox(height: AppSpacing.xxs),
                const AppPill(label: 'Paciente', dense: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
