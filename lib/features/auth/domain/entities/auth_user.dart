import 'package:equatable/equatable.dart';

/// The role the backend assigns an account.
///
/// The wire values come from `com.devluis.types.Role`. They are kept verbatim
/// in [apiValue] because the API sends and receives exactly those strings —
/// mapping them to something prettier here would just mean mapping them back
/// at every boundary.
enum UserRole {
  admin('ROLE_ADMIN'),
  employee('ROLE_EMPLOYEE'),
  doctor('ROLE_DOCTOR'),
  patient('ROLE_PATIENT'),

  /// A role this version of the app does not know. Not an error: the backend
  /// is free to add roles, and a client that crashes on an unfamiliar one is
  /// a client that breaks on every backend release.
  unknown('');

  const UserRole(this.apiValue);

  final String apiValue;

  static UserRole fromApi(String? raw) {
    for (final UserRole role in UserRole.values) {
      if (role.apiValue == raw) return role;
    }
    return UserRole.unknown;
  }
}

/// The authenticated person.
///
/// These four fields are ALL the backend returns on login — `AuthResponse` is
/// `{ email, firstName, lastName, role, message }` and nothing more. No uuid,
/// no cedula, no phone. That is worth knowing before building a profile
/// screen against it: everything else has to come from another endpoint.
class AuthUser extends Equatable {
  const AuthUser({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;

  String get fullName => '$firstName $lastName'.trim();

  /// Up to two letters for the avatar. Falls back to the email's first
  /// character rather than rendering an empty circle.
  String get initials {
    final String first = firstName.trim();
    final String last = lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return (first[0] + last[0]).toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  /// This app is the patient-facing client. A doctor or operator account can
  /// authenticate against `login-patient`'s siblings but has no business in
  /// here, and the UI should say so rather than showing an empty patient
  /// dashboard.
  bool get isPatient => role == UserRole.patient;

  @override
  List<Object?> get props => <Object?>[email, firstName, lastName, role];
}
