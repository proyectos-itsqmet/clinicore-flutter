import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/usecases/login_usecases.dart';

part 'login_event.dart';
part 'login_state.dart';

/// The login form.
///
/// It holds the SUBMISSION, not the text. The identity and password live in
/// the screen's `TextEditingController`s and arrive with
/// [LoginSubmitted] — which means no state rebuild per keystroke, and the
/// `Form`'s own validators stay the single source of truth for what a valid
/// field looks like. A bloc that mirrors every character is a bloc that
/// duplicates validation it will eventually disagree with.
///
/// On success it emits the session and stops. Telling [AuthBloc] about it is
/// the screen's job, through a `BlocListener` — blocs that reach into each
/// other are blocs that cannot be tested apart.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({
    required this.loginPatient,
    required this.canUnlockWithBiometrics,
    required this.unlockWithBiometrics,
  }) : super(const LoginState()) {
    on<LoginBiometricAvailabilityRequested>(_onAvailabilityRequested);
    on<LoginSubmitted>(_onSubmitted);
    on<LoginBiometricRequested>(_onBiometricRequested);
    on<LoginFailureDismissed>(_onFailureDismissed);
  }

  final LoginPatient loginPatient;
  final CanUnlockWithBiometrics canUnlockWithBiometrics;
  final UnlockWithBiometrics unlockWithBiometrics;

  Future<void> _onAvailabilityRequested(
    LoginBiometricAvailabilityRequested event,
    Emitter<LoginState> emit,
  ) async {
    final result = await canUnlockWithBiometrics(const NoParams());
    // A failure here means "no", not an error worth showing. The button is a
    // convenience; the password field is right there.
    emit(state.copyWith(biometricsAvailable: result.getOrElse(() => false)));
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(status: LoginStatus.submitting, clearFailure: true));

    final result = await loginPatient(
      LoginParams.fromIdentity(
        identity: event.identity,
        password: event.password,
      ),
    );

    emit(
      result.fold(
        (failure) =>
            state.copyWith(status: LoginStatus.failure, failure: failure),
        (session) =>
            state.copyWith(status: LoginStatus.success, session: session),
      ),
    );
  }

  Future<void> _onBiometricRequested(
    LoginBiometricRequested event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(status: LoginStatus.submitting, clearFailure: true));

    final result = await unlockWithBiometrics(const NoParams());

    emit(
      result.fold(
        (failure) => state.copyWith(
          // Back to idle rather than failure when the patient simply
          // cancelled the prompt: they did not fail at anything, and a red
          // banner for "you changed your mind" is noise. The message is still
          // carried so the screen can show it as a snackbar if it wants.
          status: LoginStatus.failure,
          failure: failure,
        ),
        (session) =>
            state.copyWith(status: LoginStatus.success, session: session),
      ),
    );
  }

  void _onFailureDismissed(
    LoginFailureDismissed event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(status: LoginStatus.idle, clearFailure: true));
  }
}
