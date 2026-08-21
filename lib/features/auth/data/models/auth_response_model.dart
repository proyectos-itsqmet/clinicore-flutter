import '../../domain/entities/auth_user.dart';

/// The backend's `com.devluis.types.AuthResponse`.
///
/// ```json
/// { "email": "...", "firstName": "...", "lastName": "...",
///   "role": "ROLE_PATIENT", "message": "Login Exitoso" }
/// ```
///
/// Every field is nullable on the wire even though the server always fills
/// them, because a client that throws on a missing key turns a cosmetic
/// backend change into a crash. Missing strings become empty; an unknown role
/// becomes [UserRole.unknown].
class AuthResponseModel {
  const AuthResponseModel({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.message,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      email: _string(json['email']),
      firstName: _string(json['firstName']),
      lastName: _string(json['lastName']),
      role: _string(json['role']),
      message: json['message'] as String?,
    );
  }

  final String email;
  final String firstName;
  final String lastName;
  final String role;

  /// The server's own note — "Login Exitoso", "Registro culminado con éxito".
  /// Not shown anywhere: it is a status, and the app already knows the status
  /// from the fact that the call succeeded.
  final String? message;

  AuthUser toEntity() => AuthUser(
    email: email,
    firstName: firstName,
    lastName: lastName,
    role: UserRole.fromApi(role),
  );

  static String _string(Object? value) => value is String ? value : '';
}
