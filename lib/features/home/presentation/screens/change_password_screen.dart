import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../../shared/ui/organisms/organisms.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../blocs/password/password_bloc.dart';

/// "Cambiar contrasena" — reached from "Mi perfil".
///
/// A pushed full screen rather than a bottom sheet, unlike
/// `ContactEditSheet`. The sheet exists because editing contact data is
/// better done while still looking at the values being replaced; a password
/// has nothing behind it worth keeping in view, and the live checklist plus
/// two fields plus the keyboard is more height than a sheet should claim.
///
/// ## The session survives
///
/// `PUT /api/patients/change-password` re-encodes the stored hash and nothing
/// else. The JWT this app holds is stateless, so it keeps working and the
/// patient stays signed in — see [PasswordBloc]. That is deliberately
/// different from the RECOVERY flow, which ends at the login screen because
/// the server clears its cookie there on purpose.
///
/// ## What this screen cannot ask for, and why it does not pretend to
///
/// There is NO "contrasena actual" field, because the server has nowhere to
/// put it: `ChangePasswordBody` carries `password` and `repeatedPassword`
/// only, and `PatientController.changeMyPassword` verifies nothing beyond the
/// token. Adding the field client-side would be theatre — it would tell the
/// patient their old password protects them when the server never checks it.
/// The note under the form says what actually protects the change instead.
/// See `ApiEndpoints.patientChangePassword` for what closing that gap takes.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PasswordBloc>(
      create: (_) => sl<PasswordBloc>(),
      child: const _ChangePasswordView(),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Drives the live checklist.
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

    context.read<PasswordBloc>().add(
      PasswordChangeSubmitted(
        password: _password.text,
        repeatedPassword: _confirm.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordBloc, PasswordState>(
      listenWhen: (PasswordState previous, PasswordState current) =>
          previous.status != current.status &&
          (current.isChanged || current.isSessionExpired),
      listener: (BuildContext context, PasswordState state) {
        // A dead token is not this screen's problem to solve — the router
        // already knows where an unauthenticated patient belongs.
        if (state.isSessionExpired) {
          context.read<AuthBloc>().add(const AuthSessionExpired());
          return;
        }

        // The confirmation is shown by the messenger ABOVE this route, so it
        // survives the pop and lands on "Mi perfil" — a snackbar posted into
        // a screen that is leaving goes with it.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Listo, tu contrasena quedo actualizada.'),
            ),
          );
        Navigator.of(context).pop();
      },
      builder: (BuildContext context, PasswordState state) {
        final bool saving = state.isSubmitting;

        return PopScope(
          // Blocked while the request is in flight: the server may already
          // have written the new password, and a patient who backed out
          // mid-write would not know which one is live. Same rule
          // `ResetPasswordScreen` applies at the equivalent moment.
          canPop: !saving,
          child: AppScreen(
            topBar: AppTopBar(
              title: 'Cambiar contrasena',
              onBack: saving ? null : () => Navigator.of(context).pop(),
            ),
            footer: AppButton(
              label: 'Guardar contrasena',
              size: AppButtonSize.lg,
              fullWidth: true,
              isLoading: saving,
              onPressed: saving ? null : _submit,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.section,
              children: <Widget>[
                const SizedBox(height: AppSpacing.section),

                Text(
                  'Elegi una contrasena nueva. Vas a usarla la proxima vez que '
                  'ingreses; esta sesion sigue abierta.',
                  style: AppTypography.body,
                ),

                // Reported HERE, above the fields it belongs to — not as a
                // snackbar that slides away before it is read. The message is
                // the server's own whenever it sent one: for a rejected
                // password it knows more than this app does.
                if (state.status == PasswordStatus.failure &&
                    state.failure != null)
                  Text(
                    state.failure!.message,
                    style: AppTypography.cap.copyWith(
                      color: AppColors.emergency,
                    ),
                  ),

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
                        enabled: !saving,
                        autofillHints: const <String>[
                          AutofillHints.newPassword,
                        ],
                        validator: Validators.password,
                      ),
                      AppTextField(
                        label: 'Repite la contrasena',
                        controller: _confirm,
                        hint: 'La misma de arriba',
                        prefixIcon: AppIcons.password,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        enabled: !saving,
                        autofillHints: const <String>[
                          AutofillHints.newPassword,
                        ],
                        validator: (String? value) =>
                            Validators.confirmPassword(value, _password.text),
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                  ),
                ),

                PasswordRulesCard(value: _password.text),

                // Honest about what actually guards this change. See the
                // class doc: the server does not ask for the current
                // password, so saying "por tu seguridad ingresa la actual"
                // next to a field that does nothing would be worse than
                // saying nothing.
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.cardPad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.md,
                    children: <Widget>[
                      const Icon(
                        AppIcons.info,
                        size: 16,
                        color: AppColors.ink3,
                      ),
                      Expanded(
                        child: Text(
                          'El cambio se aplica a esta cuenta, con la sesion '
                          'que tenes abierta ahora. Si crees que alguien mas '
                          'uso tu telefono, cerra sesion en todos tus '
                          'dispositivos y avisa en recepcion.',
                          style: AppTypography.cap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
