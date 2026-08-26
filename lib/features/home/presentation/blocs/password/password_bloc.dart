import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/usecases/profile_usecases.dart';

part 'password_event.dart';
part 'password_state.dart';

/// Owns the "Cambiar contrasena" form.
///
/// ## Why this is not an event on `ProfileBloc`
///
/// [ProfileBloc] is a lazy SINGLETON shared by "Mi perfil" and "Mi
/// informacion", and it holds a record rather than a submission. Folding a
/// password change into it would put a form's transient state — a validation
/// error from a rejected password, a `saving` flag — into a bloc that outlives
/// every screen: the error from an abandoned attempt would still be sitting
/// there next time the patient opened "Mi informacion", under a completely
/// different heading.
///
/// So this follows the rule `injection.dart` already states for form blocs
/// ([LoginBloc], [RecoveryBloc]): a FACTORY, created with the screen and
/// closed with it, so an abandoned attempt leaves nothing behind.
///
/// ## The session survives a success
///
/// The server re-encodes the stored hash and nothing else — the JWT this app
/// is holding is stateless and keeps working. That is the opposite of the
/// RECOVERY flow, which clears its cookie on purpose, and it is why this bloc
/// never touches [AuthBloc] on success. A patient who changes their password
/// from inside the app stays signed in, which is what every other app does and
/// what makes the change feel like a setting rather than a lockout.
///
/// A [SessionExpiredFailure] is NOT swallowed either: it lands in the state
/// like any other failure and the screen forwards it to [AuthBloc], the same
/// contract every other bloc in this feature follows.
class PasswordBloc extends Bloc<PasswordEvent, PasswordState> {
  PasswordBloc({required this.changeMyPassword})
    : super(const PasswordState.initial()) {
    on<PasswordChangeSubmitted>(_onSubmitted);
  }

  final ChangeMyPassword changeMyPassword;

  Future<void> _onSubmitted(
    PasswordChangeSubmitted event,
    Emitter<PasswordState> emit,
  ) async {
    emit(state.copyWith(status: PasswordStatus.saving, clearFailure: true));

    final result = await changeMyPassword(
      ChangeMyPasswordParams(
        password: event.password,
        repeatedPassword: event.repeatedPassword,
      ),
    );

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: PasswordStatus.failure, failure: failure),
        (_) => state.copyWith(
          status: PasswordStatus.changed,
          clearFailure: true,
        ),
      ),
    );
  }
}
