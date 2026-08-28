import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../domain/entities/patient_profile.dart';
import '../blocs/profile/profile_bloc.dart';
import '../widgets/profile_scope.dart';

/// The "Mi perfil" tab.
///
/// An identity card at the top, then the account destinations, then the way
/// out. The order is deliberate: who you are, what you can read, and only at
/// the very bottom the action you cannot undo by accident.
///
/// "Cerrar sesion" is separated from those rows by real space rather than
/// sitting fourth in the list — a destructive action one thumb-width below
/// "Politica de privacidad" gets tapped by mistake.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScope(child: _ProfileView());
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

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

            // The identity card is the ONLY thing on this screen that needs
            // the record. The destinations and the sign-out below are
            // navigation, and gating them behind a fetch would leave a patient
            // with no connection unable to reach "Cerrar sesion".
            BlocBuilder<ProfileBloc, ProfileState>(
              builder: (BuildContext context, ProfileState state) {
                final PatientProfile? profile = state.profile;

                if (profile == null) {
                  // A failed load falls through to the skeleton rather than an
                  // error card: the name is context, not the point of the
                  // screen, and an error where a name goes reads as an account
                  // problem.
                  return const AppSkeleton.card(height: 104);
                }

                return _IdentityCard(
                  name: profile.fullName,
                  cedula: profile.cedula,
                );
              },
            ),

            // The destinations, ordered by how often they are needed: the
            // record first, then the one setting a patient actually changes,
            // then the assistant, then the two documents almost nobody
            // re-reads.
            AppListRow(
              icon: AppIcons.personalInfo,
              label: 'Mi información',
              supporting: 'Datos personales y de contacto',
              onTap: () => context.push(AppPath.personalInfoScreen),
            ),
            AppListRow(
              icon: AppIcons.password,
              label: 'Cambiar contraseña',
              supporting: 'Elige una nueva para tu cuenta',
              onTap: () => context.push(AppPath.changePasswordScreen),
            ),

            // Same label as the login screen on purpose: it is the same
            // assistant, and naming it twice invites the patient to wonder
            // whether it is a second, different thing.
            //
            // The supporting line stays on what the assistant actually knows.
            // It is public and anonymous — it answers about services, prices
            // and locations, never about this patient's record. Promising
            // "consulta tus citas" here would be a lie the first time somebody
            // asks.
            AppListRow(
              icon: AppIcons.assistant,
              label: 'Consultar al asistente',
              supporting: 'Servicios, precios, sedes y horarios',
              onTap: () => context.push(AppPath.assistantScreen),
            ),
            AppListRow(
              icon: AppIcons.terms,
              label: 'Términos y condiciones',
              supporting: 'Lo que aceptaste al crear la cuenta',
              onTap: () => context.push(AppPath.termsScreen),
            ),
            AppListRow(
              icon: AppIcons.privacy,
              label: 'Política de privacidad',
              supporting: 'Cómo tratamos tus datos de salud',
              onTap: () => context.push(AppPath.privacyScreen),
            ),

            // Real distance, not a fourth list item.
            const SizedBox(height: AppSpacing.xxl),

            AppListRow(
              icon: AppIcons.signOut,
              label: 'Cerrar sesión',
              danger: true,
              onTap: () => _confirmSignOut(context),
            ),

            Center(
              child: Text(
                'CliniCore / versión de desarrollo',
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
        title: const Text('¿Cerrar sesión?'),
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
              'Cerrar sesión',
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
