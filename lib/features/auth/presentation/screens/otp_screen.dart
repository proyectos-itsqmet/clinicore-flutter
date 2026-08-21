import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../blocs/registration/registration_bloc.dart';
import '../widgets/auth_form_shell.dart';
import '../widgets/otp_field.dart';

/// Step 2 of 3 — the code from the email.
///
/// ## Read this before trusting the code
///
/// **The server does not check it.** `AuthService.initRegistration` generates
/// a code and mails it, but never calls `OtpService.saveOtp`, so the store it
/// would be compared against is always empty — and nothing anywhere calls
/// `OtpService.validate`, because there is no route that would. The flash token
/// issued alongside the mail is, on its own, enough to complete registration.
///
/// So this screen validates the SHAPE of the code (six digits) and advances.
/// It does not claim to have verified anything, and the notice below says so
/// on screen rather than only in a comment — a reviewer looking at the running
/// app should be able to see the gap.
///
/// The step is kept, rather than skipped, for two reasons. The resend action
/// refreshes the 5-minute token, which a patient who paused genuinely needs.
/// And when the verification endpoint lands, this is the handler that calls it:
/// `RegistrationCodeSubmitted` already carries the code into the bloc.
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
    return BlocConsumer<RegistrationBloc, RegistrationState>(
      listenWhen: (previous, current) =>
          previous.step != current.step || previous.status != current.status,
      listener: (context, state) {
        if (state.step == RegistrationStep.profile) {
          context.push(AppPath.registerProfileScreen);
          return;
        }
        // The 300-second token expired and the bloc walked the flow back.
        if (state.step == RegistrationStep.identity) {
          context.pop();
          return;
        }
        final failure = state.failure;
        if (state.status == RegistrationStatus.failure && failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
          context.read<RegistrationBloc>().add(
            const RegistrationFailureDismissed(),
          );
        }
      },
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

            const _PendingVerificationNotice(),

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
    );
  }
}

/// The on-screen version of this file's header note.
///
/// It is here, visible in the running app, because a gap this size should not
/// live only in a comment: anyone reviewing the build needs to know the code
/// is not being checked yet. `gold`, not `emergency` — this is a caution to
/// the team, not an error the patient caused.
///
/// Delete this widget the day `/auth/verify-otp` exists.
class _PendingVerificationNotice extends StatelessWidget {
  const _PendingVerificationNotice();

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
                  'Verificacion pendiente en el servidor',
                  style: AppTypography.h3.copyWith(fontSize: 15),
                ),
                Text(
                  'El backend todavia no valida este codigo: falta el '
                  'endpoint de verificacion. La app ya lo envia y el paso '
                  'queda listo para cuando exista.',
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
