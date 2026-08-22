import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/usecases/password_reset_usecases.dart';

part 'recovery_event.dart';
part 'recovery_state.dart';

/// Password recovery, all three steps.
///
/// One bloc for the whole flow rather than one per screen, for the same reason
/// [RegistrationBloc] is one bloc: the steps share state that has to survive
/// navigation. Here it is the email — the server takes it from the flash token
/// so it is never re-sent, but the code screen still has to SHOW the patient
/// which address the mail went to.
///
/// It is provided by a `ShellRoute` around the three recovery routes, so it
/// lives exactly as long as the flow does.
///
/// ## Two cliffs, not one
///
/// Every step is on a clock, and they are different clocks:
///
/// * `recover-password/init` issues a **300-second** token. That is the window
///   to read the mail and type the code.
/// * `recover-password/verify-otp` swaps it for a **600-second** one. That is
///   the window to choose a new password.
///
/// Both expire as a 401, which [AuthRepositoryImpl] maps to
/// [SessionExpiredFailure]. Showing "sesion vencida" to someone who does not
/// have a session would be nonsense, so both handlers translate it: the flow
/// walks back to the step that can reissue the token, with a reason.
///
/// ## The OTP here is real
///
/// Unlike registration's, this code is actually checked —
/// `AuthService.initPasswordRecovery` calls `otpService.saveOtp`. Three wrong
/// tries block the address (`OtpData.excedioIntentos`), and the block is not
/// cleared by retrying step 2: it needs a new code from step 1. That is why
/// [RecoveryCodeResendRequested] exists and why a blocked code sends the flow
/// back rather than letting the patient keep guessing.
class RecoveryBloc extends Bloc<RecoveryEvent, RecoveryState> {
  RecoveryBloc({
    required this.initPasswordRecovery,
    required this.verifyRecoveryOtp,
    required this.changePassword,
  }) : super(const RecoveryState()) {
    on<RecoveryEmailSubmitted>(_onEmailSubmitted);
    on<RecoveryCodeSubmitted>(_onCodeSubmitted);
    on<RecoveryCodeResendRequested>(_onCodeResendRequested);
    on<RecoveryPasswordSubmitted>(_onPasswordSubmitted);
    on<RecoveryFailureDismissed>(_onFailureDismissed);
    on<RecoveryRestarted>(_onRestarted);
  }

  final InitPasswordRecovery initPasswordRecovery;
  final VerifyRecoveryOtp verifyRecoveryOtp;
  final ChangePassword changePassword;

  /// Step 1 — claim the address and get a code mailed.
  Future<void> _onEmailSubmitted(
    RecoveryEmailSubmitted event,
    Emitter<RecoveryState> emit,
  ) async {
    emit(state.copyWith(status: RecoveryStatus.submitting, clearFailure: true));

    final result = await initPasswordRecovery(
      InitPasswordRecoveryParams(email: event.email),
    );

    emit(
      result.fold(
        (failure) =>
            state.copyWith(status: RecoveryStatus.failure, failure: failure),
        (_) => state.copyWith(
          status: RecoveryStatus.idle,
          step: RecoveryStep.code,
          email: event.email,
        ),
      ),
    );
  }

  /// Step 2 — the code from the mail.
  Future<void> _onCodeSubmitted(
    RecoveryCodeSubmitted event,
    Emitter<RecoveryState> emit,
  ) async {
    emit(state.copyWith(status: RecoveryStatus.submitting, clearFailure: true));

    final result = await verifyRecoveryOtp(
      VerifyRecoveryOtpParams(otp: event.code),
    );

    emit(
      result.fold(
        (failure) => _mapStepFailure(
          failure,
          fallbackStep: RecoveryStep.email,
          expiredMessage:
              'Se agoto el tiempo para usar el codigo. Pedi uno nuevo: '
              'son cinco minutos desde que lo enviamos.',
        ),
        (_) => state.copyWith(
          status: RecoveryStatus.idle,
          step: RecoveryStep.password,
        ),
      ),
    );
  }

  /// Re-runs step 1 with the address already captured.
  ///
  /// This is the ONLY way out of a blocked code — three wrong tries lock the
  /// address until a new code is generated, so "reenviar" is a real recovery
  /// path here and not just a convenience.
  Future<void> _onCodeResendRequested(
    RecoveryCodeResendRequested event,
    Emitter<RecoveryState> emit,
  ) async {
    final String? email = state.email;
    if (email == null) return;

    emit(state.copyWith(status: RecoveryStatus.submitting, clearFailure: true));

    final result = await initPasswordRecovery(
      InitPasswordRecoveryParams(email: email),
    );

    emit(
      result.fold(
        (failure) =>
            state.copyWith(status: RecoveryStatus.failure, failure: failure),
        (_) => state.copyWith(status: RecoveryStatus.idle),
      ),
    );
  }

  /// Step 3 — the new password.
  Future<void> _onPasswordSubmitted(
    RecoveryPasswordSubmitted event,
    Emitter<RecoveryState> emit,
  ) async {
    emit(state.copyWith(status: RecoveryStatus.submitting, clearFailure: true));

    final result = await changePassword(
      ChangePasswordParams(
        password: event.password,
        repeatedPassword: event.repeatedPassword,
      ),
    );

    emit(
      result.fold(
        (failure) => _mapStepFailure(
          failure,
          // Back to the CODE step, not to the email step: the address is still
          // valid and still verified, so making them retype it would be
          // punishment for the clock running out.
          fallbackStep: RecoveryStep.code,
          expiredMessage:
              'Se agoto el tiempo para cambiar la contrasena. '
              'Verifica el codigo de nuevo.',
        ),
        (_) => state.copyWith(
          status: RecoveryStatus.idle,
          step: RecoveryStep.done,
        ),
      ),
    );
  }

  /// Turns an expired flash token into a step change instead of an error.
  ///
  /// A [SessionExpiredFailure] here is never about a session — there isn't one.
  /// It means the short-lived recovery token died, and the only useful answer
  /// is to move the patient to the step that can issue a new one. Anything else
  /// is a dead end: an error on a screen whose every submission will now fail.
  RecoveryState _mapStepFailure(
    Failure failure, {
    required RecoveryStep fallbackStep,
    required String expiredMessage,
  }) {
    if (failure is SessionExpiredFailure) {
      return state.copyWith(
        step: fallbackStep,
        status: RecoveryStatus.failure,
        failure: ValidationFailure(message: expiredMessage),
      );
    }
    return state.copyWith(status: RecoveryStatus.failure, failure: failure);
  }

  void _onFailureDismissed(
    RecoveryFailureDismissed event,
    Emitter<RecoveryState> emit,
  ) {
    emit(state.copyWith(status: RecoveryStatus.idle, clearFailure: true));
  }

  void _onRestarted(RecoveryRestarted event, Emitter<RecoveryState> emit) {
    emit(const RecoveryState());
  }
}
