part of 'registration_bloc.dart';

sealed class RegistrationEvent extends Equatable {
  const RegistrationEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Step 1: the email and cedula the account will be filed under.
class RegistrationIdentitySubmitted extends RegistrationEvent {
  const RegistrationIdentitySubmitted({
    required this.email,
    required this.cedula,
  });

  final String email;
  final String cedula;

  @override
  List<Object?> get props => <Object?>[email, cedula];
}

/// Step 2: the six-digit code from the email.
class RegistrationCodeSubmitted extends RegistrationEvent {
  const RegistrationCodeSubmitted(this.code);

  final String code;

  @override
  List<Object?> get props => <Object?>[code];

  @override
  String toString() => 'RegistrationCodeSubmitted(<redacted>)';
}

/// Mails a new code — and, more importantly, refreshes the 300-second token.
class RegistrationCodeResendRequested extends RegistrationEvent {
  const RegistrationCodeResendRequested();
}

/// Step 3: everything `PatientDTO` still needs.
///
/// [firstName] and [lastName] are separate because the DTO has two fields, and
/// splitting a single "nombre completo" input on whitespace guesses wrong the
/// moment someone has two surnames — which in Ecuador is everybody.
///
/// [birthday] is required, not optional, because the server marks it
/// `@NotNull`. A registration form without it fails at the last step.
class RegistrationProfileSubmitted extends RegistrationEvent {
  const RegistrationProfileSubmitted({
    required this.firstName,
    required this.lastName,
    required this.birthday,
    required this.password,
    this.gender,
    this.phone,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String firstName;
  final String lastName;
  final DateTime birthday;
  final String password;
  final Gender? gender;
  final String? phone;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  @override
  List<Object?> get props => <Object?>[
    firstName,
    lastName,
    birthday,
    password,
    gender,
    phone,
    address,
    emergencyContactName,
    emergencyContactPhone,
  ];

  @override
  String toString() =>
      'RegistrationProfileSubmitted($firstName $lastName, '
      'password: <redacted>)';
}

class RegistrationFailureDismissed extends RegistrationEvent {
  const RegistrationFailureDismissed();
}

/// Back to step 1, forgetting everything. Used when the flash token expires.
class RegistrationRestarted extends RegistrationEvent {
  const RegistrationRestarted();
}
