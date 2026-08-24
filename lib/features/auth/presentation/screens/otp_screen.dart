import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../blocs/registration/registration_bloc.dart';
import '../widgets/auth_form_shell.dart';
import '../widgets/otp_field.dart';
import '../widgets/registration_flow_listeners.dart';

/// Step 2 of 3 — the code from the email.
///
/// ## The code is verified now
///
/// It was not, and the note that used to live here said so at length. Three
/// things were missing and all three are done: the route `/auth/verify-otp`
/// exists, `AuthService.initRegistration` calls `otpService.saveOtp` (so the
/// store `validate` compares against is no longer permanently empty), and
/// `RegistrationBloc._onCodeSubmitted` calls the endpoint instead of advancing
/// locally.
///
/// ## Two kinds of error on one screen
///
/// [_error] is LOCAL and only about shape — six digits. It renders under the
/// field, before anything is sent.
///
/// A rejection from the server ("El código no es válido") arrives as a bloc
/// failure and goes to the snackbar via `RegistrationFlowListeners`, the same
/// path step 1 and step 3 use. Keeping the two apart is deliberate: one says
/// "you mistyped", the other says "the server disagrees", and collapsing them
/// into one string would lose which.
///
/// ## Three tries, and then the code is dead
///
/// `OtpData.excedioIntentos()` blocks at 3 failures and the block lives with
/// the stored code, so retrying here cannot clear it. "Reenviar codigo" is the
/// only way out — it re-runs step 1, which mails a new code AND refreshes the
/// 300-second token, so it is the escape hatch for both failure modes at once.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _code = TextEditingController();

  /// Long enough to stop someone using the clinic's mail server as a weapon,
  /// short enough that a patient whose mail was slow does not give up.
  static const int _resendSeconds = 30;

  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _submit() {
    final String? problem = Validators.otp(_code.text);
    setState(() => _error = problem);
    if (problem != null) return;

    context.read<RegistrationBloc>().add(RegistrationCodeSubmitted(_code.text));
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationFlowListeners(
      onStepChanged: (BuildContext context, RegistrationState state) {
        if (state.step == RegistrationStep.profile) {
          context.push(AppPath.registerProfileScreen);
          return;
        }
        // The 300-second token expired and the bloc walked the flow back.
        if (state.step == RegistrationStep.identity) context.pop();
      },
      child: BlocBuilder<RegistrationBloc, RegistrationState>(
        builder: (context, state) {
        final String target = state.email ?? 'tu correo';

        return AuthFormShell(
          kicker: 'Paso 2 de 3',
          title: 'Escribe el codigo.',
          subtitle: 'Lo enviamos a $target.',
          onBack: () => context.pop(),
          footer: AuthFooterLink(
            message: 'Correo equivocado?',
            actionLabel: 'Cambialo',
            onTap: () => context.pop(),
          ),
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.lg,
              children: <Widget>[
                const AppKicker(text: 'Codigo de 6 digitos', size: 11),
                OtpField(controller: _code, onCompleted: (_) => _submit()),
                if (_error != null)
                  Text(
                    _error!,
                    style: AppTypography.cap.copyWith(
                      color: AppColors.emergency,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),

            AppButton(
              label: 'Continuar',
              size: AppButtonSize.lg,
              fullWidth: true,
              isLoading: state.isSubmitting,
              trailing: const Icon(AppIcons.arrowRight),
              onPressed: _submit,
            ),

            Center(
              child: _secondsLeft > 0
                  // While the countdown runs this is a status, not a control —
                  // which is exactly what a pill is for.
                  ? AppPill(
                      label: 'Puedes reenviar en ${_secondsLeft}s',
                      tone: AppPillTone.plain,
                      dense: true,
                    )
                  : AppButton(
                      label: 'Reenviar codigo',
                      variant: AppButtonVariant.ghost,
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              _startCountdown();
                              context.read<RegistrationBloc>().add(
                                const RegistrationCodeResendRequested(),
                              );
                            },
                    ),
            ),
            ],
          );
        },
      ),
    );
  }
}

