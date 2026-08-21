import 'package:local_auth/local_auth.dart';

import '../../../../core/error/exceptions.dart';

/// The fingerprint / face check.
///
/// Wraps `local_auth` so nothing above the data layer imports a plugin, and so
/// the platform's error codes become messages a patient can act on.
abstract interface class BiometricDataSource {
  /// True when this device has biometric hardware AND something enrolled.
  Future<bool> isAvailable();

  /// Shows the system prompt. Throws [BiometricException] on anything that is
  /// not a clean success — including the user tapping cancel, which is a
  /// refusal, not a bug.
  Future<void> authenticate();
}

class BiometricDataSourceImpl implements BiometricDataSource {
  const BiometricDataSourceImpl(this._localAuth);

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    try {
      // Both checks are needed and they answer different questions.
      // `isDeviceSupported` asks "can this device do it at all"; a device with
      // a sensor but nothing enrolled passes that and still cannot
      // authenticate. `getAvailableBiometrics` is the one that catches it.
      final bool supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;

      final List<BiometricType> enrolled = await _localAuth
          .getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      // A platform that cannot answer is a platform that cannot do it.
      return false;
    }
  }

  @override
  Future<void> authenticate() async {
    try {
      final bool ok = await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a CliniCore',
        // `biometricOnly: false` on purpose. Falling back to the device PIN or
        // pattern is the RIGHT behaviour here: the check is guarding a token
        // that is already on the device, so the bar is "is this the phone's
        // owner", and a patient with a wet finger should not be locked out of
        // tomorrow's appointment.
        biometricOnly: false,
        // Marks this as a transaction worth protecting; on iOS it prevents the
        // result being reused for a later call.
        sensitiveTransaction: true,
        // Survive the app being backgrounded by the system prompt itself.
        persistAcrossBackgrounding: true,
      );

      if (!ok) {
        throw const BiometricException(
          message: 'No pudimos confirmar tu identidad.',
        );
      }
    } on LocalAuthException catch (error) {
      throw BiometricException(message: _messageFor(error.code));
    }
  }

  /// Platform codes to something worth reading.
  ///
  /// Note that a lockout and a cancellation get different messages: after a
  /// lockout the patient needs to know the fingerprint route is closed for
  /// now and the password still works, whereas after a cancel they already
  /// know what they did.
  String _messageFor(LocalAuthExceptionCode code) => switch (code) {
    LocalAuthExceptionCode.userCanceled => 'Cancelaste la verificacion.',
    LocalAuthExceptionCode.systemCanceled =>
      'La verificacion se interrumpio. Intenta de nuevo.',
    LocalAuthExceptionCode.timeout => 'Se agoto el tiempo de la verificacion.',
    LocalAuthExceptionCode.noBiometricHardware =>
      'Este dispositivo no tiene lector biometrico.',
    LocalAuthExceptionCode.noBiometricsEnrolled =>
      'No tienes huella ni rostro registrados en el dispositivo.',
    LocalAuthExceptionCode.noCredentialsSet =>
      'Configura un PIN o una huella en tu dispositivo para usar esta opcion.',
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
      'El lector biometrico no esta disponible en este momento.',
    LocalAuthExceptionCode.temporaryLockout =>
      'Demasiados intentos. Espera un momento o usa tu contrasena.',
    LocalAuthExceptionCode.biometricLockout =>
      'La huella quedo bloqueada. Desbloquea el dispositivo con tu PIN.',
    _ => 'No pudimos usar la verificacion biometrica. Usa tu contrasena.',
  };
}
