import 'package:equatable/equatable.dart';
// `flutter_bloc` re-exports `Bloc` and `Emitter`. Importing `package:bloc`
// directly would work but it is only a transitive dependency here, which the
// `depend_on_referenced_packages` lint rightly complains about.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/usecases/session_usecases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Owns the answer to "is anyone signed in?".
///
/// This bloc is deliberately small and deliberately long-lived. It holds ONE
/// piece of state, it is created once at the top of the app, and it is what
/// the router listens to in order to decide whether a location is reachable.
///
/// It does NOT handle forms. Signing in is [LoginBloc]'s job and registering
/// is [RegistrationBloc]'s; both report their result here with
/// [AuthSessionGranted]. Folding those flows into this class is the usual way
/// an auth bloc turns into a 400-line god object with eight loading flags —
/// and it breaks the one property that makes this one useful, which is that
/// its state never flickers through `submitting` while the router is watching.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.restoreSession, required this.signOut})
    : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthSessionGranted>(_onSessionGranted);

    // Both end the session and both do it the same way. They stay separate
    // EVENTS because the difference is worth reading in a log — "the patient
    // signed out" and "the token died" are different stories — but there is
    // no reason for two handlers.
    on<AuthSignOutRequested>(_onSessionEnded);
    on<AuthSessionExpired>(_onSessionEnded);
  }

  final RestoreSession restoreSession;
  final SignOut signOut;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await restoreSession(const NoParams());

    // A failure reading storage is treated as "not signed in" rather than
    // surfaced. There is nothing the patient can do about a keychain error on
    // launch, and the recovery — show the login screen — is the same either
    // way.
    emit(
      result.fold(
        (failure) => const AuthState.unauthenticated(),
        (session) => session == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(session),
      ),
    );
  }

  void _onSessionGranted(AuthSessionGranted event, Emitter<AuthState> emit) {
    emit(AuthState.authenticated(event.session));
  }

  /// Ends the session, whether the patient asked or the token died.
  ///
  /// Clears local storage as well as the in-memory state. A session the server
  /// has stopped honouring is not worth keeping on the device: leaving it
  /// there means the next launch restores a token that 401s on every screen,
  /// which looks like the app being broken rather than the session being over.
  Future<void> _onSessionEnded(AuthEvent event, Emitter<AuthState> emit) async {
    await signOut(const NoParams());
    emit(const AuthState.unauthenticated());
  }
}
