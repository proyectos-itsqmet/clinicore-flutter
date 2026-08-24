import 'package:equatable/equatable.dart';

/// How the patient's sex is recorded, as the API spells it.
///
/// [unknown] is not a fifth option offered to anyone — it is what an
/// unrecognised wire value becomes, so a backend that adds `GENDER_X`
/// tomorrow shows a blank field instead of crashing the profile screen.
enum PatientGender {
  male,
  female,
  other,
  unknown;

  static PatientGender fromApi(String? value) => switch (value) {
    'GENDER_MALE' => PatientGender.male,
    'GENDER_FEMALE' => PatientGender.female,
    'GENDER_OTHER' => PatientGender.other,
    _ => PatientGender.unknown,
  };

  /// Empty for [unknown]: "Sexo: Desconocido" reads as a record about the
  /// patient, when it is really a record about our parser.
  String get label => switch (this) {
    PatientGender.male => 'Masculino',
    PatientGender.female => 'Femenino',
    PatientGender.other => 'Otro',
    PatientGender.unknown => '',
  };
}

/// The signed-in patient's own record.
///
/// ## The split down the middle is the point
///
/// **Identity** — [firstName], [lastName], [cedula], [birthday], [gender] — is
/// READ-ONLY, and not because the UI decided so: `PatientService.updatePatient`
/// on the server ignores those fields entirely. The medical history is filed
/// under them, and letting a patient edit their own cedula from a phone would
/// orphan their record. `PersonalInfoScreen` says that out loud instead of
/// greying the fields out, because a disabled field with no explanation reads
/// as a bug.
///
/// **Contact** — [email], [phone], [address], [emergencyContactName],
/// [emergencyContactPhone] — is editable, because the clinic needs it correct
/// and the patient is the only one who knows when it changed.
///
/// ## What is NOT here
///
/// Coverage — insurer, plan, affiliate number. `PersonalInfoScreen` shows that
/// group as sample data and will keep showing it that way: the tables
/// (`insurers`, `coverage_plans`, `patient_coverage`) do not exist on the
/// server. Inventing the fields here would make the screen look wired when it
/// is not.
class PatientProfile extends Equatable {
  const PatientProfile({
    required this.uuid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.cedula,
    this.birthday,
    this.gender = PatientGender.unknown,
    this.phone,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String uuid;

  // ---- Contacto (editable) ----
  final String email;
  final String? phone;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  // ---- Identidad (solo lectura) ----
  final String firstName;
  final String lastName;
  final String cedula;
  final DateTime? birthday;
  final PatientGender gender;

  String get fullName => '$firstName $lastName'.trim();

  /// Both halves of the emergency contact on one line, or null when neither is
  /// on file. A row that says "/" because only the phone is known is worse
  /// than a row that says nothing.
  String? get emergencyContact {
    final String name = emergencyContactName?.trim() ?? '';
    final String phone = emergencyContactPhone?.trim() ?? '';
    if (name.isEmpty && phone.isEmpty) return null;
    if (name.isEmpty) return phone;
    if (phone.isEmpty) return name;
    return '$name / $phone';
  }

  @override
  List<Object?> get props => <Object?>[
    uuid,
    email,
    firstName,
    lastName,
    cedula,
    birthday,
    gender,
    phone,
    address,
    emergencyContactName,
    emergencyContactPhone,
  ];
}

/// The subset of [PatientProfile] the server will actually accept on a write.
///
/// A separate type rather than "pass a `PatientProfile` and hope": the server
/// silently drops identity fields, so a caller sending a whole profile after
/// editing the name would get a 200 back and believe it worked. This shape
/// cannot express that mistake.
class PatientContactUpdate extends Equatable {
  const PatientContactUpdate({
    required this.email,
    this.phone,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String email;
  final String? phone;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  @override
  List<Object?> get props => <Object?>[
    email,
    phone,
    address,
    emergencyContactName,
    emergencyContactPhone,
  ];
}
