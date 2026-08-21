part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Fired once, on app launch. Reads whatever session the device holds.
///
/// Until it resolves, [AuthState.status] is `unknown` — which is what the
/// router uses to hold the splash instead of flashing the login screen at a
/// patient who is already signed in.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// A form bloc obtained a session. Reported here so the router reacts.
class AuthSessionGranted extends AuthEvent {
  const AuthSessionGranted(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => <Object?>[session];
}

/// The patient chose to sign out.
class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// A request came back with a dead token.
///
/// Distinct from [AuthSignOutRequested] even though the handler is shared: in
/// a log, "the token expired" and "the patient tapped sign out" are different
/// stories, and only one of them is worth investigating.
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
