part of 'login_bloc.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Asked once on init, to decide whether the fingerprint button appears.
class LoginBiometricAvailabilityRequested extends LoginEvent {
  const LoginBiometricAvailabilityRequested();
}

/// The form passed its own validators and wants to go.
class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.identity, required this.password});

  /// Either an email or a cedula. `LoginParams.fromIdentity` decides which.
  final String identity;

  final String password;

  @override
  List<Object?> get props => <Object?>[identity, password];

  @override
  String toString() => 'LoginSubmitted($identity, password: <redacted>)';
}

/// Unlock with fingerprint or face instead of typing.
class LoginBiometricRequested extends LoginEvent {
  const LoginBiometricRequested();
}

/// The screen has shown the error; clear it so it does not reappear on the
/// next rebuild.
class LoginFailureDismissed extends LoginEvent {
  const LoginFailureDismissed();
}
