import 'dart:async';

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
import '../widgets/otp_field.dart';
import '../widgets/recovery_flow_listeners.dart';

/// Step 2 of 3 — the code from the mail.
///
/// The app has a second OTP screen, [OtpScreen] for registration, and the two
/// are now symmetric: both store a code server-side and both reject a wrong
/// one. They stay SEPARATE endpoints because they authorise different things —
/// this one hands out `ROLE_CHANGE_PASSWORD`, registration's hands out
/// `ROLE_PENDING_REGISTRATION` — and one token that did both would be a hole.
///
/// ## Three tries, and then the code is dead
///
/// `OtpData.excedioIntentos()` blocks at 3 failures, and the block lives with
/// the stored code — so retrying on this screen cannot clear it. The only way
/// out is a NEW code, which is why "Reenviar codigo" is a recovery path here
/// and not a convenience. The screen says so after the first failure rather
/// than letting someone burn all three tries without knowing the budget.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key});

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  final TextEditingController _code = TextEditingController();

  /// Long enough to stop someone using the clinic's mail server as a weapon,
  /// short enough that a patient whose mail was slow does not give up.
  static const int _resendSeconds = 30;

  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  String? _error;

  /// Counted locally, only to decide when to warn about the limit. The server
  /// owns the real count — this is a hint, never the gate.
  int _attempts = 0;

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

    context.read<RecoveryBloc>().add(RecoveryCodeSubmitted(_code.text));
  }

  void _resend() {
    setState(() {
      _attempts = 0;
      _error = null;
      _code.clear();
    });
    _startCountdown();
    context.read<RecoveryBloc>().add(const RecoveryCodeResendRequested());
  }

  @override
  Widget build(BuildContext context) {
    return RecoveryFlowListeners(
      onStepChanged: (BuildContext context, RecoveryState state) {
        if (state.step == RecoveryStep.password) {
          context.push(AppPath.recoveryPasswordScreen);
          return;
        }
        // The 5-minute token died and the bloc walked the flow back to step 1.
        if (state.step == RecoveryStep.email) context.pop();
      },
      child: BlocConsumer<RecoveryBloc, RecoveryState>(
        // The snackbar is [RecoveryFlowListeners]' job; this one only keeps the
        // local attempt counter, which is why it watches `status` and touches
        // no navigation.
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == RecoveryStatus.failure,
        listener: (context, state) => setState(() => _attempts++),
        builder: (context, state) {
        final String target = state.email ?? 'tu correo';

        return AuthFormShell(
          kicker: 'Paso 2 de 3',
          title: 'Escribe el código.',
          subtitle: 'Lo enviamos a $target.',
          onBack: () => context.pop(),
          footer: AuthFooterLink(
            message: '¿Correo equivocado?',
            actionLabel: 'Cámbialo',
            onTap: () => context.pop(),
          ),
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.lg,
              children: <Widget>[
                const AppKicker(text: 'Código de 6 dígitos', size: 11),
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

            // Only after a real rejection. Announcing "you have 3 tries" to
            // someone who has not failed yet is pressure, not help.
            if (_attempts > 0)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.md,
                children: <Widget>[
                  const Icon(
                    AppIcons.warning,
                    size: 16,
                    color: AppColors.goldDeep,
                  ),
                  Expanded(
                    child: Text(
                      'Despues de 3 intentos fallidos el código se bloquea y '
                      'hay que pedir uno nuevo.',
                      style: AppTypography.cap,
                    ),
                  ),
                ],
              ),

            AppButton(
              label: 'Verificar código',
              size: AppButtonSize.lg,
              fullWidth: true,
              isLoading: state.isSubmitting,
              trailing: const Icon(AppIcons.arrowRight),
              onPressed: _submit,
            ),

            Center(
              child: _secondsLeft > 0
                  ? AppPill(
                      label: 'Puedes reenviar en ${_secondsLeft}s',
                      tone: AppPillTone.plain,
                      dense: true,
                    )
                  : AppButton(
                      label: 'Reenviar código',
                      variant: AppButtonVariant.ghost,
                      onPressed: state.isSubmitting ? null : _resend,
                    ),
            ),
            ],
          );
        },
      ),
    );
  }
}
