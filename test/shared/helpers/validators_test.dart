import 'package:clinicore_flutter/shared/helpers/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.cedula', () {
    // The check digits below were computed by hand from the mod-10 rule, so
    // these tests verify the implementation rather than restate it.
    test('accepts a cedula whose check digit is correct', () {
      // 17-1-234567 -> weighted sum 35 -> check (10 - 5) % 10 = 5
      expect(Validators.cedula('1712345675'), isNull);
      // 09-0-012345 -> weighted sum 24 -> check (10 - 4) % 10 = 6
      expect(Validators.cedula('0900123456'), isNull);
    });

    test('rejects a wrong check digit', () {
      expect(Validators.cedula('1712345670'), contains('no verifica'));
    });

    test('rejects an impossible province', () {
      expect(Validators.cedula('9912345675'), contains('provincia'));
    });

    test('accepts province 30, the consular code', () {
      // 30-1-234567 -> d = 3,0,1,2,3,4,5,6,7
      // products 6,0,2,2,6,4,1,6,5 -> sum 32 -> check 8
      expect(Validators.cedula('3012345678'), isNull);
    });

    test('rejects a third digit of 6 or more', () {
      expect(Validators.cedula('1762345675'), contains('tercer digito'));
    });

    test('rejects anything that is not ten digits', () {
      expect(Validators.cedula('171234567'), contains('10 digitos'));
      expect(Validators.cedula('17123456750'), contains('10 digitos'));
      expect(Validators.cedula('17123456a5'), contains('10 digitos'));
    });

    test('rejects an empty value with its own message', () {
      expect(Validators.cedula(''), 'Ingresa tu cedula');
      expect(Validators.cedula(null), 'Ingresa tu cedula');
    });
  });

  group('Validators.email', () {
    test('accepts ordinary and plus-addressed mail', () {
      expect(Validators.email('paciente@clinica.ec'), isNull);
      expect(Validators.email('nombre.apellido+cita@correo.com'), isNull);
    });

    test('rejects the shapes that are actually typos', () {
      expect(Validators.email('paciente'), isNotNull);
      expect(Validators.email('paciente@'), isNotNull);
      expect(Validators.email('paciente@clinica'), isNotNull);
      expect(Validators.email('paciente @clinica.ec'), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('accepts an Ecuadorian mobile', () {
      expect(Validators.phone('0991234567'), isNull);
      // Spaces and dashes are stripped before checking, because people paste.
      expect(Validators.phone('099 123 4567'), isNull);
    });

    test('rejects a landline or a wrong length', () {
      expect(Validators.phone('022345678'), isNotNull);
      expect(Validators.phone('09912345'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('accepts eight characters with a letter and a number', () {
      expect(Validators.password('clinica1'), isNull);
    });

    test('reports the ONE thing that is missing', () {
      expect(Validators.password('corto1'), contains('8 caracteres'));
      expect(Validators.password('12345678'), contains('una letra'));
      expect(Validators.password('clinicaaa'), contains('un numero'));
    });
  });

  group('Validators.confirmPassword', () {
    test('accepts a match and rejects a mismatch', () {
      expect(Validators.confirmPassword('clinica1', 'clinica1'), isNull);
      expect(
        Validators.confirmPassword('clinica2', 'clinica1'),
        contains('no coinciden'),
      );
    });
  });

  group('Validators.fullName', () {
    test('accepts accents, apostrophes and hyphens', () {
      expect(Validators.fullName('María José Núñez'), isNull);
      expect(Validators.fullName("D'Angelo Pérez-Gómez"), isNull);
    });

    test('rejects digits', () {
      expect(Validators.fullName('Paciente 2'), contains('solo lleva letras'));
    });
  });

  group('Validators.otp', () {
    test('accepts exactly six digits', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp('12345'), contains('6 digitos'));
      expect(Validators.otp('12345a'), contains('6 digitos'));
    });
  });
}
