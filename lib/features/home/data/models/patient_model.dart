import '../../domain/entities/patient_profile.dart';
import 'json_reader.dart';

/// The backend's `com.devluis.dto.PatientDTO`.
///
/// ```json
/// { "uuid": "...", "email": "...", "password": null,
///   "firstName": "...", "lastName": "...", "ci": "1712345678",
///   "birthday": "1990-04-12", "gender": "GENDER_MALE",
///   "address": "...", "phone": "...",
///   "emergencyContactName": "...", "emergencyContactPhone": "..." }
/// ```
///
/// `password` is on the DTO and always arrives null: `PatientService.mapToDTO`
/// never sets it. It is deliberately NOT a field here — a model that carries a
/// password field is a model someone will eventually log.
class PatientModel {
  const PatientModel({
    required this.uuid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.cedula,
    this.birthday,
    this.gender,
    this.address,
    this.phone,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      uuid: readString(json['uuid']),
      email: readString(json['email']),
      firstName: readString(json['firstName']),
      lastName: readString(json['lastName']),
      cedula: readString(json['ci']),
      birthday: readDate(json['birthday']),
      gender: readStringOrNull(json['gender']),
      address: readStringOrNull(json['address']),
      phone: readStringOrNull(json['phone']),
      emergencyContactName: readStringOrNull(json['emergencyContactName']),
      emergencyContactPhone: readStringOrNull(json['emergencyContactPhone']),
    );
  }

  final String uuid;
  final String email;
  final String firstName;
  final String lastName;

  /// `ci` on the wire. Named for what it is everywhere else in this app.
  final String cedula;

  final DateTime? birthday;
  final String? gender;
  final String? address;
  final String? phone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  PatientProfile toEntity() => PatientProfile(
    uuid: uuid,
    email: email,
    firstName: firstName,
    lastName: lastName,
    cedula: cedula,
    birthday: birthday,
    gender: PatientGender.fromApi(gender),
    phone: phone,
    address: address,
    emergencyContactName: emergencyContactName,
    emergencyContactPhone: emergencyContactPhone,
  );
}

/// The body of `PUT /api/patients/me`.
///
/// SENDS ONLY WHAT THE SERVER WILL HONOUR — email plus the four contact
/// fields. `PatientService.updatePatient` copies exactly those and ignores
/// name, cedula, birthday and gender, so including them would be a request
/// that looks like it changed something and did not.
///
/// The one field that IS sent and is not strictly contact: `email`, because
/// the server treats it as changeable (it checks for a duplicate and reassigns
/// it). It is the patient's login, so it belongs to the patient.
///
/// `password` is never sent. The server would re-hash whatever arrives, and
/// changing a password is `PUT /api/patients/change-password`, a different
/// call with its own confirmation.
class PatientContactUpdateModel {
  const PatientContactUpdateModel(this.update);

  final PatientContactUpdate update;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': update.email,
    'phone': update.phone,
    'address': update.address,
    'emergencyContactName': update.emergencyContactName,
    'emergencyContactPhone': update.emergencyContactPhone,
  };
}
