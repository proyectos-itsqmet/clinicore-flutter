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

  /// Changing your own password from inside a live session.
  ///
  /// NOT under [forgotPasswordScreen], and the prefix is what keeps them
  /// apart: [isAuthFlow] matches `/recuperar-contrasena` with `startsWith`,
  /// so a path nested there would be classified as part of the signed-OUT
  /// recovery flow — and the guard would bounce a signed-IN patient straight
  /// back to `/agendar` the moment they opened it.
  static const changePasswordScreen = '/cambiar-contrasena';

  /// One visit of the clinical history, in full.
  ///
  /// A TOP-LEVEL route rather than a child of [historyScreen], for the same
  /// reason [personalInfoScreen] is one: a child of a shell branch renders
  /// INSIDE the branch's navigator, which leaves the bottom nav bar over a
  /// medical record that wants the whole screen. It is also what puts this
  /// through `AppRouter._redirect`, so a session that dies while a diagnosis
  /// is on screen takes the screen with it.
  ///
  /// The `HistoryEntry` travels as `GoRouterState.extra` — it is a joined
  /// object with no id of its own to put in the path, and re-fetching it here
  /// would cost a second audited clinical read. See `HistoryDetailScreen` for
  /// what happens when that hand-off is missing.
  static const historyDetailScreen = '/historial/visita';

  //! Asistente virtual de atencion al cliente.
  //!
  //! Publico y anonimo por diseno: informa sobre servicios, precios,
  //! especialidades, sedes y turnos disponibles, y no responde nada de un
  //! paciente en particular. Alguien que todavia no tiene cuenta tiene que
  //! poder preguntar "que examenes hacen?" antes de registrarse.
  static const assistantScreen = '/asistente';

  /// Locations reachable with or without a session.
  ///
  /// The two legal documents and the assistant. A patient has to be able to
  /// read the terms BEFORE agreeing to them, which means before having an
  /// account — and to ask the assistant what the clinic offers before deciding
  /// to create one.
  static const Set<String> publicPaths = <String>{
    termsScreen,
    privacyScreen,
    assistantScreen,
  };

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
