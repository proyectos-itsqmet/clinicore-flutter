/// Route names, for navigating by name instead of by literal path.
///
/// Worth keeping in step with [AppPath]: `context.goNamed(PathName.booking)`
/// survives a change to the URL, `context.go('/agendar')` does not.
class PathName {
  static const splashScreen = 'splash';

  //! Auth
  static const loginScreen = 'login';

  //! Password recovery
  static const forgotPasswordScreen = 'recuperar-contrasena';
  static const recoveryCodeScreen = 'recuperar-codigo';
  static const recoveryPasswordScreen = 'recuperar-nueva';

  //! Registration
  static const registerScreen = 'registro';
  static const registerVerificationScreen = 'registro-verificacion';
  static const registerProfileScreen = 'registro-datos';

  //! Home
  static const bookingScreen = 'agendar';
  static const appointmentsScreen = 'mis-citas';
  static const historyScreen = 'historial';
  static const profileScreen = 'perfil';

  //! Profile
  static const personalInfoScreen = 'mi-informacion';
  static const changePasswordScreen = 'cambiar-contrasena';
  static const termsScreen = 'terminos';
  static const privacyScreen = 'privacidad';

  //! History
  static const historyDetailScreen = 'historial-visita';

  //! Asistente virtual — publico, no requiere sesion.
  static const assistantScreen = 'asistente';
}
