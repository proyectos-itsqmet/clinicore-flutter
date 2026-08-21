import '../../domain/entities/patient_registration.dart';

/// `com.devluis.types.LoginPatientBody`.
///
/// `email` and `ci` are both optional on the server; `password` is
/// `@NotBlank`. `AuthService.loginPatient` checks `ci` FIRST and only falls
/// back to `email`, so sending both means the cedula wins — which is why
/// [toJson] omits whichever one is null instead of sending it as `null`.
class LoginRequestModel {
  const LoginRequestModel({this.email, this.cedula, required this.password});

  final String? email;
  final String? cedula;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (email != null) 'email': email,
    if (cedula != null) 'ci': cedula,
    'password': password,
  };
}

/// `com.devluis.types.InitRegistrationBody`.
///
/// Both fields are required, and the server validates `ci` against
/// `^[0-9]{10}$` before anything else. It also refuses the call outright if
/// either the cedula or the email already belongs to a patient, with a
/// specific message for each — those messages are worth surfacing verbatim.
class InitRegistrationRequestModel {
  const InitRegistrationRequestModel({
    required this.email,
    required this.cedula,
  });

  final String email;
  final String cedula;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'ci': cedula,
  };
}

/// `com.devluis.dto.PatientDTO`.
///
/// Two mapping details that are easy to get wrong and hard to debug:
///
/// 1. **`birthday` is a `java.time.LocalDate`**, so it must go out as
///    `yyyy-MM-dd` and nothing else. A full ISO-8601 timestamp
///    (`2026-08-21T00:00:00.000Z`) makes Jackson fail to deserialise the
///    whole DTO, and the resulting 400 says nothing about which field.
/// 2. **`gender` is an enum**, sent as its Java constant name
///    (`GENDER_MALE`), not as a display label.
///
/// Optional fields are omitted rather than sent as `null` — the server treats
/// absent and null the same, and omitting keeps the request readable in a log.
class PatientRegistrationRequestModel {
  const PatientRegistrationRequestModel(this.registration);

  final PatientRegistration registration;

  Map<String, dynamic> toJson() {
    final PatientRegistration r = registration;
    return <String, dynamic>{
      'email': r.email,
      'password': r.password,
      'firstName': r.firstName,
      'lastName': r.lastName,
      'ci': r.cedula,
      'birthday': _isoDate(r.birthday),
      if (r.gender != null) 'gender': r.gender!.apiValue,
      if (_present(r.address)) 'address': r.address,
      if (_present(r.phone)) 'phone': r.phone,
      if (_present(r.emergencyContactName))
        'emergencyContactName': r.emergencyContactName,
      if (_present(r.emergencyContactPhone))
        'emergencyContactPhone': r.emergencyContactPhone,
    };
  }

  /// `yyyy-MM-dd`. Written by hand rather than with `intl`'s `DateFormat`
  /// because a locale-aware formatter is exactly the wrong tool here: this is
  /// a wire format, and it must not change with the device's locale.
  static String _isoDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool _present(String? value) =>
      value != null && value.trim().isNotEmpty;
}
