part of 'recovery_bloc.dart';

sealed class RecoveryEvent extends Equatable {
  const RecoveryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Step 1: the address to mail the code to.
///
/// The server looks it up across patients, doctors and operators, so a doctor
/// can recover from this same screen.
class RecoveryEmailSubmitted extends RecoveryEvent {
  const RecoveryEmailSubmitted(this.email);

  final String email;

  @override
  List<Object?> get props => <Object?>[email];
}

/// Step 2: the six-digit code from the mail.
class RecoveryCodeSubmitted extends RecoveryEvent {
  const RecoveryCodeSubmitted(this.code);

  final String code;

  @override
  List<Object?> get props => <Object?>[code];

  @override
  String toString() => 'RecoveryCodeSubmitted(<redacted>)';
}

/// Mails a new code and refreshes the 300-second token.
///
/// Also the only escape from a code blocked by three wrong tries.
class RecoveryCodeResendRequested extends RecoveryEvent {
  const RecoveryCodeResendRequested();
}

/// Step 3: the new password, twice.
///
/// Both values travel because the server is what compares them — see
/// `ChangePasswordBody`.
class RecoveryPasswordSubmitted extends RecoveryEvent {
  const RecoveryPasswordSubmitted({
    required this.password,
    required this.repeatedPassword,
  });

  final String password;
  final String repeatedPassword;

  @override
  List<Object?> get props => <Object?>[password, repeatedPassword];

  @override
  String toString() => 'RecoveryPasswordSubmitted(<redacted>)';
}

class RecoveryFailureDismissed extends RecoveryEvent {
  const RecoveryFailureDismissed();
}

/// Back to step 1, forgetting everything.
class RecoveryRestarted extends RecoveryEvent {
  const RecoveryRestarted();
}
