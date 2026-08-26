import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../blocs/recovery/recovery_bloc.dart';
import '../widgets/auth_form_shell.dart';
import '../widgets/recovery_flow_listeners.dart';

/// Step 3 of 3 — the new password, once the code is verified.
///
/// The rules are stated up front as a checklist that ticks itself as the user
/// types, rather than as an error that appears after they get it wrong. Same
/// information, opposite feeling — and it is the difference between a form
/// that helps and a form that scolds.
///
/// ## The 10-minute cliff
///
/// `recover-password/verify-otp` issues a token that lives 300 seconds, and
/// this screen's submission is what spends it. A patient who stops to think of
/// a good password can run it out — so a 401 here is not an error to show on
/// this form, it is a reason to go back one step. [RecoveryBloc] does that
/// translation; this screen just follows the step.
///
/// ## It does not navigate on success
///
/// The bloc moves to [RecoveryStep.done] and the listener sends the app to
/// login. There is no session to grant: `changePassword` clears the token
/// deliberately, so signing in with the new password is what proves it was
/// stored.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Drives the live checklist below.
    _password.addListener(_onTyped);
  }

  @override
  void dispose() {
    _password.removeListener(_onTyped);
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onTyped() => setState(() {});

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<RecoveryBloc>().add(
      RecoveryPasswordSubmitted(
        password: _password.text,
        repeatedPassword: _confirm.text,
      ),
    );
  }

  /// Guards both ways out of the last step: the header arrow and the device's
  /// own back gesture.
  ///
  /// Leaving here is not a normal `pop`. The verified code is spent — the
  /// server deleted it in `verifyRecoveryOtp` — so the code screen underneath
  /// is tied to something that no longer exists. Going back one screen would
  /// land the patient on a form whose every submission now fails.
  ///
  /// So it asks, and on confirmation it RESTARTS the flow at step 1, where a
  /// fresh code can actually be issued.
  Future<void> _confirmLeave() async {
    final bool leave =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Salir sin cambiarla?', style: AppTypography.h3),
            content: Text(
              'El codigo que verificaste ya se uso. Si sales, tenes que pedir '
              'uno nuevo y empezar de nuevo desde tu correo.',
              style: AppTypography.body,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Seguir aqui',
                  style: AppTypography.cap.copyWith(
                    color: AppColors.ink2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Salir y empezar de nuevo',
                  style: AppTypography.cap.copyWith(
                    color: AppColors.emergency,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!leave || !mounted) return;

    context.read<RecoveryBloc>().add(const RecoveryRestarted());
    context.go(AppPath.forgotPasswordScreen);
  }

  @override
  Widget build(BuildContext context) {
    return RecoveryFlowListeners(
      onStepChanged: (BuildContext context, RecoveryState state) {
        if (state.step == RecoveryStep.done) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Contrasena actualizada. Ingresa con la nueva.'),
              ),
            );
          // `go`, not `pop`: the two screens underneath belong to a flow that
          // is finished, and their tokens are spent.
          context.go(AppPath.loginScreen);
          return;
        }
        // The 10-minute token died and the bloc walked the flow back to the
        // code step.
        if (state.step == RecoveryStep.code) context.pop();
      },
      child: BlocBuilder<RecoveryBloc, RecoveryState>(
        builder: (BuildContext context, RecoveryState state) {
          // Back is blocked outright while the change is in flight: the server
          // may already have written the new password.
          if (state.isSubmitting) {
            return PopScope(
              canPop: false,
              child: _buildForm(context, state),
            );
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) return;
              _confirmLeave();
            },
            child: _buildForm(context, state),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, RecoveryState state) {
    return AuthFormShell(
      kicker: 'Paso 3 de 3',
      title: 'Elige una nueva.',
      subtitle: 'Cuando la guardes, ingresa de nuevo con ella.',
      onBack: state.isSubmitting ? null : _confirmLeave,
      children: <Widget>[
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.section,
            children: <Widget>[
              AppTextField(
                label: 'Contrasena nueva',
                controller: _password,
                hint: 'Minimo 8 caracteres',
                prefixIcon: AppIcons.password,
                obscure: true,
                textInputAction: TextInputAction.next,
                enabled: !state.isSubmitting,
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: Validators.password,
              ),
              AppTextField(
                label: 'Repite la contrasena',
                controller: _confirm,
                hint: 'La misma de arriba',
                prefixIcon: AppIcons.password,
                obscure: true,
                textInputAction: TextInputAction.done,
                enabled: !state.isSubmitting,
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),

        // The live checklist, shared with "Cambiar contrasena" so the two
        // screens can never disagree about what a valid password is.
        PasswordRulesCard(value: _password.text),

        AppButton(
          label: 'Guardar contrasena',
          size: AppButtonSize.lg,
          fullWidth: true,
          isLoading: state.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
