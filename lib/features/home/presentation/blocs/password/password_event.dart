part of 'password_bloc.dart';

sealed class PasswordEvent extends Equatable {
  const PasswordEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Submit the new password.
///
/// Both fields travel because the SERVER is what compares them —
/// `PatientController.changeMyPassword` answers 400 "Las contrasenas no
/// coinciden" itself. The form checks it first so the patient hears about a
/// typo before a round trip, but the server's answer is the one that decides.
class PasswordChangeSubmitted extends PasswordEvent {
  const PasswordChangeSubmitted({
    required this.password,
    required this.repeatedPassword,
  });

  final String password;
  final String repeatedPassword;

  @override
  List<Object?> get props => <Object?>[password, repeatedPassword];

  /// Bloc prints every transition in debug through `onTransition`, and an
  /// event's `toString` is what it prints. Without this the new password ends
  /// up in the console — and in whatever collects it.
  @override
  String toString() => 'PasswordChangeSubmitted(<redacted>)';
}
