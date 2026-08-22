/// Every location in the app, as a URL.
///
/// The paths are in Spanish because they are user-visible: they show up in
/// deep links, in the browser bar on Flutter web, and in analytics.
/// `/agendar` tells a Spanish-speaking user what they are looking at;
/// `/booking` does not.
class AppPath {
  /// Where every cold start lands.
  ///
  /// It exists to cover the gap between "the app started" and "we know whether
  /// anyone is signed in". Without it, a returning patient sees the login
  /// screen for a frame before being thrown into the app — which reads as a
  /// bug and, worse, invites them to start typing.
  static const splashScreen = '/';

  //! Auth — all outside the shell, so they cover the whole screen.
  static const loginScreen = '/login';

  //! Password recovery — three steps under one prefix, for the same reason
  //! registration has one: a `ShellRoute` owns the `RecoveryBloc` so the
  //! address captured in step 1 survives two pushes, and each step's
  //! short-lived token is issued by the step before it.
  static const forgotPasswordScreen = '/recuperar-contrasena';
  static const recoveryCodeScreen = '/recuperar-contrasena/codigo';
  static const recoveryPasswordScreen = '/recuperar-contrasena/nueva';

  //! Registration — a three-step flow under one prefix.
  //!
  //! The prefix is what lets the router wrap all three in a single
  //! `ShellRoute` that owns the `RegistrationBloc`: the email and cedula from
  //! step 1 have to survive two pushes, and the server rejects step 3 if the
  //! email does not match what step 1 registered.
  static const registerScreen = '/registro';
  static const registerVerificationScreen = '/registro/verificacion';
  static const registerProfileScreen = '/registro/datos';

  //! Home — the four branches of the bottom navigation. Each is the root of
  //! its own stack, which is what lets a tab keep its scroll position and its
  //! half-filled form when you leave and come back.
  static const bookingScreen = '/agendar';
  static const appointmentsScreen = '/mis-citas';
  static const historyScreen = '/historial';
  static const profileScreen = '/perfil';

  //! Profile destinations, as TOP-LEVEL routes rather than children of
  //! [profileScreen].
  //!
  //! [termsScreen] and [privacyScreen] are reached from two places — the
  //! profile tab AND the consent line on the registration screen, which lives
  //! outside the shell and outside any session. As children of the profile
  //! branch, pushing them from registration would have to build the shell (and
  //! pass the auth guard) underneath them. As top-level public routes, both
  //! callers push the same absolute path and get the same full-screen
  //! document.
  static const personalInfoScreen = '/mi-informacion';
  static const termsScreen = '/terminos';
  static const privacyScreen = '/privacidad';

  /// Locations reachable with or without a session.
  ///
  /// The two legal documents, and only those. A patient has to be able to read
  /// the terms BEFORE agreeing to them, which means before having an account.
  static const Set<String> publicPaths = <String>{termsScreen, privacyScreen};

  /// Locations that are part of signing in or signing up.
  ///
  /// An authenticated patient who lands on one of these is bounced to
  /// [bookingScreen] — otherwise the back button after login walks straight
  /// back into the login form.
  /// `startsWith` for both multi-step flows, not `==`.
  ///
  /// A recovery in progress sits at `/recuperar-contrasena/codigo`, and an
  /// exact match on the prefix alone would leave that location outside the auth
  /// flow — so the guard would bounce the patient to login mid-recovery, on the
  /// screen where they were about to type the code.
  static bool isAuthFlow(String location) {
    return location == splashScreen ||
        location == loginScreen ||
        location.startsWith(forgotPasswordScreen) ||
        location.startsWith(registerScreen);
  }
}
