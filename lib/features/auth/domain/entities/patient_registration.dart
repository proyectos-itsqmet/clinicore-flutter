import 'package:equatable/equatable.dart';

/// Wire values from `com.devluis.types.Gender`.
enum Gender {
  male('GENDER_MALE', 'Masculino'),
  female('GENDER_FEMALE', 'Femenino'),
  other('GENDER_OTHER', 'Otro');

  const Gender(this.apiValue, this.label);

  final String apiValue;

  /// What the patient sees, in Spanish.
  final String label;

  /// The options this app OFFERS, which is not the same list as [values].
  ///
  /// [other] is deliberately absent: the mobile form asks for **sex** as a
  /// clinical field and requires one of two answers.
  ///
  /// It stays in the enum rather than being deleted, and that distinction is
  /// the point — `GENDER_OTHER` is still a legal value of
  /// `com.devluis.types.Gender`, so a record created through the Angular panel
  /// can carry it. Deleting the case would make [fromApi] return null for
  /// those patients and the app would silently render them as having no sex on
  /// file. Narrow what you WRITE; keep parsing everything the server can SEND.
  static const List<Gender> selectable = <Gender>[male, female];

  static Gender? fromApi(String? raw) {
    if (raw == null) return null;
    for (final Gender gender in Gender.values) {
      if (gender.apiValue == raw) return gender;
    }
    return null;
  }
}

/// Everything `POST /auth/register-patient` needs.
///
/// This mirrors `PatientDTO` field for field, and the required/optional split
/// is the DTO's own Bean Validation, not a preference:
///
/// * `@NotBlank`: [email], [password], [firstName], [lastName], [cedula]
/// * `@NotNull`: [birthday]
/// * everything else is nullable on the server
///
/// [birthday] being required is the one that catches people out. A patient
/// record with no date of birth is clinically useless — dosing, reference
/// ranges and screening intervals all depend on age — so the server refuses
/// it, and any registration form that does not ask for it will fail at the
/// last step.
class PatientRegistration extends Equatable {
  const PatientRegistration({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.cedula,
    required this.birthday,
    this.gender,
    this.address,
    this.phone,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  /// Must be the SAME address used in `init-registration-patient`.
  /// `AuthService.completeRegistration` compares it against the flash token's
  /// subject and rejects a mismatch with "El email no pertenece al usuario
  /// autenticado".
  final String email;

  final String password;
  final String firstName;
  final String lastName;

  /// `ci` on the wire. Ten digits.
  final String cedula;

  /// Serialised as ISO `yyyy-MM-dd`, which is what Jackson expects for a
  /// `java.time.LocalDate`.
  final DateTime birthday;

  final Gender? gender;
  final String? address;
  final String? phone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  @override
  List<Object?> get props => <Object?>[
    email,
    password,
    firstName,
    lastName,
    cedula,
    birthday,
    gender,
    address,
    phone,
    emergencyContactName,
    emergencyContactPhone,
  ];

  @override
  String toString() =>
      'PatientRegistration($email, $cedula, password: <redacted>)';
}
