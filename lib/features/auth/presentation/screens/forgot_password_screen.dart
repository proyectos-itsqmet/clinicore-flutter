import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../blocs/recovery/recovery_bloc.dart';
import '../widgets/auth_form_shell.dart';
import '../widgets/recovery_flow_listeners.dart';

/// Step 1 of 3 — the address to mail the code to.
///
/// ## Email only, not cedula
///
/// Login takes either, but `RecoverPasswordInitBody` has one field and it is
/// `@Email`. That is not an oversight on the server: the code has to be
/// delivered somewhere, and a cedula is not a delivery address.
///
/// ## The 404 is shown, not hidden
///
/// `initPasswordRecovery` answers 404 "No existe un usuario con ese correo"
/// when the address belongs to nobody, and this screen surfaces that verbatim.
///
/// The usual argument against it is account enumeration — a stranger can learn
/// which addresses are registered. That argument is real, and it loses here:
/// this is a clinic. A patient who mistyped their own address and is told
/// "listo, revisa tu correo" will wait for a mail that is never coming, and
/// then miss an appointment. The honest answer costs an enumeration oracle;
/// the vague one costs a consultation. If the clinic ever decides otherwise,
/// the change belongs on the SERVER — always answering 200 — not here.
///
/// Navigation is wired through [RecoveryFlowListeners], which explains why it
/// must react to step changes and not to status changes.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<RecoveryBloc>().add(
      RecoveryEmailSubmitted(_email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RecoveryFlowListeners(
      onStepChanged: (BuildContext context, RecoveryState state) {
        if (state.step == RecoveryStep.code) {
          context.push(AppPath.recoveryCodeScreen);
        }
      },
      child: BlocBuilder<RecoveryBloc, RecoveryState>(
        builder: (BuildContext context, RecoveryState state) {
          return AuthFormShell(
            kicker: 'Paso 1 de 3',
            title: 'Recuperemos tu acceso.',
            subtitle:
                'Te enviamos un codigo de 6 digitos al correo con el que te '
                'registraste.',
            onBack: () => context.pop(),
            footer: AuthFooterLink(
              message: 'Ya la recordaste?',
              actionLabel: 'Volver al inicio',
              onTap: () => context.go(AppPath.loginScreen),
            ),
            children: <Widget>[
              Form(
                key: _formKey,
                child: AppTextField(
                  label: 'Correo',
                  controller: _email,
                  hint: 'tu@correo.com',
                  prefixIcon: AppIcons.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  enabled: !state.isSubmitting,
                  autofillHints: const <String>[AutofillHints.username],
                  validator: Validators.email,
                  onSubmitted: (_) => _submit(),
                ),
              ),

              AppButton(
                label: 'Enviar codigo',
                size: AppButtonSize.lg,
                fullWidth: true,
                isLoading: state.isSubmitting,
                trailing: const Icon(AppIcons.arrowRight),
                onPressed: _submit,
              ),

              // The clock starts the moment the mail is sent, so saying so
              // before the patient leaves the app to check it is worth a line.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.md,
                children: <Widget>[
                  const Icon(AppIcons.info, size: 16, color: AppColors.ink3),
                  Expanded(
                    child: Text(
                      'El codigo vence en 5 minutos. Si no llega, revisa la '
                      'carpeta de correo no deseado.',
                      style: AppTypography.cap,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
