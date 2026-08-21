import 'package:clinicore_flutter/core/error/exceptions.dart';
import 'package:clinicore_flutter/core/network/api_error_mapper.dart';
import 'package:clinicore_flutter/features/auth/data/models/auth_request_models.dart';
import 'package:clinicore_flutter/features/auth/data/models/auth_response_model.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/auth_user.dart';
import 'package:clinicore_flutter/features/auth/domain/entities/patient_registration.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the wire format.
///
/// These are the cheapest tests in the project and they guard the most
/// expensive class of bug: a serialisation mistake comes back as a 400 with a
/// message about the whole DTO, and finding out WHICH field was wrong means
/// reading Java.
void main() {
  group('PatientRegistrationRequestModel', () {
    PatientRegistration registration({
      Gender? gender,
      String? phone,
      String? address,
    }) {
      return PatientRegistration(
        email: 'ana@clinica.ec',
        password: 'clinica1',
        firstName: 'Ana',
        lastName: 'Nunez',
        cedula: '1712345675',
        birthday: DateTime(1990, 3, 7),
        gender: gender,
        phone: phone,
        address: address,
      );
    }

    test('serialises birthday as yyyy-MM-dd and nothing else', () {
      // `PatientDTO.birthday` is a java.time.LocalDate. A full ISO-8601
      // timestamp makes Jackson fail to deserialise the WHOLE DTO, and the
      // resulting 400 does not say which field caused it.
      final json = PatientRegistrationRequestModel(registration()).toJson();

      expect(json['birthday'], '1990-03-07');
      expect(json['birthday'], isNot(contains('T')));
    });

    test('pads single-digit months and days', () {
      final model = PatientRegistrationRequestModel(
        PatientRegistration(
          email: 'a@b.ec',
          password: 'clinica1',
          firstName: 'A',
          lastName: 'B',
          cedula: '1712345675',
          birthday: DateTime(2001, 1, 5),
        ),
      );

      expect(model.toJson()['birthday'], '2001-01-05');
    });

    test('maps the cedula onto the wire name `ci`', () {
      final json = PatientRegistrationRequestModel(registration()).toJson();

      expect(json['ci'], '1712345675');
      expect(json.containsKey('cedula'), isFalse);
    });

    test('sends gender as the Java constant, not the label', () {
      final json = PatientRegistrationRequestModel(
        registration(gender: Gender.female),
      ).toJson();

      expect(json['gender'], 'GENDER_FEMALE');
      expect(json['gender'], isNot('Femenino'));
    });

    test('omits absent and blank optionals instead of sending null', () {
      final json = PatientRegistrationRequestModel(
        registration(phone: '  ', address: null),
      ).toJson();

      expect(json.containsKey('gender'), isFalse);
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('address'), isFalse);
      expect(json.containsKey('emergencyContactName'), isFalse);
    });

    test('always sends the six required fields', () {
      final json = PatientRegistrationRequestModel(registration()).toJson();

      for (final String key in <String>[
        'email',
        'password',
        'firstName',
        'lastName',
        'ci',
        'birthday',
      ]) {
        expect(json.containsKey(key), isTrue, reason: '$key is @NotBlank');
      }
    });
  });

  group('LoginRequestModel', () {
    test('sends only the identity it was given', () {
      // AuthService.loginPatient checks `ci` first and falls back to `email`.
      // Sending both means the cedula silently wins.
      expect(
        const LoginRequestModel(
          cedula: '1712345675',
          password: 'x',
        ).toJson().containsKey('email'),
        isFalse,
      );
      expect(
        const LoginRequestModel(
          email: 'a@b.ec',
          password: 'x',
        ).toJson().containsKey('ci'),
        isFalse,
      );
    });
  });

  group('AuthResponseModel', () {
    test('reads the backend shape', () {
      final model = AuthResponseModel.fromJson(<String, dynamic>{
        'email': 'ana@clinica.ec',
        'firstName': 'Ana',
        'lastName': 'Nunez',
        'role': 'ROLE_PATIENT',
        'message': 'Login Exitoso',
      });

      expect(model.toEntity().role, UserRole.patient);
      expect(model.toEntity().fullName, 'Ana Nunez');
      expect(model.toEntity().initials, 'AN');
    });

    test('survives missing keys instead of throwing', () {
      // A client that crashes on a cosmetic backend change is a client that
      // breaks on every backend release.
      final model = AuthResponseModel.fromJson(<String, dynamic>{});

      expect(model.email, '');
      expect(model.toEntity().role, UserRole.unknown);
      expect(model.toEntity().initials, '?');
    });

    test('an unfamiliar role is unknown, not an error', () {
      final model = AuthResponseModel.fromJson(<String, dynamic>{
        'role': 'ROLE_NUTRITIONIST',
      });

      expect(model.toEntity().role, UserRole.unknown);
      expect(model.toEntity().isPatient, isFalse);
    });

    test('falls back to the email for initials', () {
      final model = AuthResponseModel.fromJson(<String, dynamic>{
        'email': 'zoe@clinica.ec',
      });

      expect(model.toEntity().initials, 'Z');
    });
  });

  group('mapDioException', () {
    DioException badResponse(int status, Object? body) {
      final RequestOptions options = RequestOptions(path: '/auth/x');
      return DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: body,
        ),
      );
    }

    test('401 and 403 become UnauthorizedException', () {
      expect(
        mapDioException(badResponse(401, null)),
        isA<UnauthorizedException>(),
      );
      expect(
        mapDioException(badResponse(403, null)),
        isA<UnauthorizedException>(),
      );
    });

    test(
      'other 4xx become BadRequestException, 5xx become ServerException',
      () {
        expect(
          mapDioException(badResponse(400, null)),
          isA<BadRequestException>(),
        );
        // The login endpoint answers a wrong password with 404, which is why
        // this class carries the status through.
        expect(
          mapDioException(badResponse(404, null)),
          isA<BadRequestException>(),
        );
        expect(mapDioException(badResponse(500, null)), isA<ServerException>());
      },
    );

    test('prefers the server message over ours', () {
      // Helper.getResponseMessage answers `{"message": "..."}`, and those
      // strings are written for the patient.
      final AppException mapped = mapDioException(
        badResponse(400, <String, dynamic>{
          'message': 'El usuario ya se encuentra registrado con esta cedula',
        }),
      );

      expect(
        mapped.message,
        'El usuario ya se encuentra registrado con esta cedula',
      );
    });

    test('reads the capital-M `Message` that one endpoint uses', () {
      // init-registration-patient answers `{"Message": "..."}`. Missing this
      // means losing the server's text on exactly the endpoint whose errors
      // matter most.
      final AppException mapped = mapDioException(
        badResponse(400, <String, dynamic>{'Message': 'Codigo Otp enviado'}),
      );

      expect(mapped.message, 'Codigo Otp enviado');
    });

    test('reads the security entry point shape', () {
      final AppException mapped = mapDioException(
        badResponse(401, <String, dynamic>{
          'error': 'No autorizado',
          'message': 'Sesion invalida o inexistente',
        }),
      );

      // `message` wins over `error`: it is the more specific of the two.
      expect(mapped.message, 'Sesion invalida o inexistente');
    });

    test('timeouts and connection errors become NetworkException', () {
      final RequestOptions options = RequestOptions(path: '/auth/x');
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ]) {
        expect(
          mapDioException(DioException(requestOptions: options, type: type)),
          isA<NetworkException>(),
          reason: '$type should read as a connectivity problem',
        );
      }
    });
  });
}
