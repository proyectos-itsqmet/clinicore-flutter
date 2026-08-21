import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../widgets/auth_form_shell.dart';

/// Password recovery — currently unavailable, and this screen says so.
///
/// ## Why there is no form here
///
/// The QMS backend has no password recovery. `AuthController` exposes
/// `login-patient`, `mobile/login-patient`, `init-registration-patient` and
/// `register-patient`, and nothing else; there is no `forgot-password`, no
/// `reset-password`, and no token-by-mail flow to hang them on.
///
/// A form would therefore be a lie. The patient would type their address, tap
/// "Enviar codigo", get a spinner and then either an error or — worse, if
/// someone had stubbed it optimistically — a success message for a mail that
/// was never sent. Then they would wait. For a clinic, that is not a rough
/// edge: it is a patient who cannot get to tomorrow's appointment.
///
/// So the screen tells the truth and points at the channel that does exist.
/// The domain side is finished and waiting — `RequestPasswordReset` and
/// `ConfirmPasswordReset` are written, registered in the service locator, and
/// return `NotImplementedOnServerFailure` — so restoring the form when the two
/// endpoints ship means putting the fields back and deleting this notice.
/// `reset_password_screen.dart` is already built for the second half.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthFormShell(
      kicker: 'Recuperar acceso',
      title: 'Te ayudamos por telefono.',
      subtitle: 'Todavia no podemos restablecer la contrasena desde la app.',
      onBack: () => context.pop(),
      footer: AuthFooterLink(
        message: 'Ya la recordaste?',
        actionLabel: 'Volver al inicio',
        onTap: () => context.pop(),
      ),
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: <Widget>[
              Row(
                spacing: AppSpacing.lg,
                children: <Widget>[
                  const AppIconTile(icon: AppIcons.info, size: 34),
                  Expanded(
                    child: Text(
                      'Que hacer mientras tanto',
                      style: AppTypography.h3.copyWith(fontSize: 16),
                    ),
                  ),
                ],
              ),
              Text(
                'Llama a la clinica al [NUMERO] o acercate a recepcion con '
                'tu cedula. El personal puede restablecer tu contrasena en '
                'el momento.',
                style: AppTypography.body.copyWith(fontSize: 15),
              ),
              const AppHairline(),
              Text(
                'Si tu correo sigue activo y recuerdas tu cedula, tambien '
                'puedes ingresar con la cedula en lugar del correo.',
                style: AppTypography.cap,
              ),
            ],
          ),
        ),

        // Visible in the running app on purpose: a gap this size should not
        // live only in a code comment. `gold` and not `emergency` — this is a
        // note for the team, not an error the patient caused.
        AppCard(
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
                      'Pendiente en el servidor',
                      style: AppTypography.h3.copyWith(fontSize: 15),
                    ),
                    Text(
                      'El backend no tiene endpoints de recuperacion de '
                      'contrasena. La app ya tiene el flujo armado y lo '
                      'habilita en cuanto existan.',
                      style: AppTypography.cap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        AppButton(
          label: 'Volver a ingresar',
          size: AppButtonSize.lg,
          fullWidth: true,
          variant: AppButtonVariant.ghost,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
