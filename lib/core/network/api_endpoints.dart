/// The QMS API surface this app uses.
///
/// Every path below was read off the Spring Boot controllers in
/// `Backend_QMS/src/main/java/com/devluis/controller/`, not guessed. Where a
/// path this app needs does NOT exist yet, it is listed anyway with a comment
/// saying so — an honest missing endpoint is easier to fix than an invented
/// one that silently 404s.
abstract final class ApiEndpoints {
  /// `@RequestMapping("/auth")` on `AuthController`.
  static const String _auth = '/auth';

  // ==========================================================
  // LOGIN
  // ==========================================================

  /// `POST /auth/mobile/login-patient` — **use this one, not the web variant.**
  ///
  /// The controller has two patient logins. `/auth/login-patient` puts the JWT
  /// in a `Set-Cookie` header, which is what the Angular app consumes.
  /// `/auth/mobile/login-patient` returns the same body but puts the token in
  /// an `Authorization: Bearer <token>` RESPONSE header, which is what a
  /// native client can actually read.
  ///
  /// Body: `{ "email": String?, "ci": String?, "password": String }` —
  /// `LoginPatientBody`. Send ONE of email or ci; `AuthService.loginPatient`
  /// checks `ci` first and falls back to `email`.
  ///
  /// 200 body: `AuthResponse` = `{ email, firstName, lastName, role, message }`.
  static const String loginPatientMobile = '$_auth/mobile/login-patient';

  // ==========================================================
  // REGISTRATION — a two-step flow, and the order is not optional
  // ==========================================================

  /// `POST /auth/init-registration-patient` — step 1.
  ///
  /// Body: `{ "email": String, "ci": String }` — `InitRegistrationBody`.
  ///
  /// Checks that neither the cedula nor the email is already registered,
  /// mails a 6-digit code, and issues a **flash JWT** carrying the authority
  /// `ROLE_OTP_PENDING` with a 300-second lifetime. That token is what step 2
  /// authenticates with.
  ///
  /// 200 body: `{ "Message": "Código Otp enviado al correo" }` — note the
  /// capital `M`, which is not how the rest of the API spells it.
  ///
  /// **The flash token comes back as a cookie, not a header.** Unlike login,
  /// there is no `/mobile/` variant of this endpoint, so the client has to
  /// read it out of `Set-Cookie` itself. See `AuthRemoteDataSource`.
  static const String initRegistrationPatient =
      '$_auth/init-registration-patient';

  /// `POST /auth/register-patient` — step 2.
  ///
  /// Body: `PatientDTO`. Required: `email`, `password`, `firstName`,
  /// `lastName`, `ci`, `birthday` (ISO `yyyy-MM-dd`). Optional: `gender`
  /// (`GENDER_MALE` | `GENDER_FEMALE` | `GENDER_OTHER`), `address`, `phone`,
  /// `emergencyContactName`, `emergencyContactPhone`.
  ///
  /// Requires the flash token from step 1: the controller takes
  /// `Authentication auth` and rejects the call unless
  /// `auth.getName() == body.email`. Sending a different email than the one
  /// used in step 1 fails with "El email no pertenece al usuario autenticado".
  ///
  /// 200 body: `AuthResponse`, plus a 24h JWT cookie.
  static const String registerPatient = '$_auth/register-patient';

  // ==========================================================
  // PASSWORD RECOVERY — three steps, and each one issues the token the
  // next one authenticates with
  // ==========================================================
  //
  // Read off `AuthController` lines 159-208 and `AuthService` lines 225-260.
  //
  // Unlike login, NONE of these has a `/mobile/` variant: all three hand their
  // token back as `Set-Cookie: jwt=...`, so the client reads it out of the
  // header itself — the same job `_tokenFromSetCookie` already does for
  // registration.
  //
  // | step   | needs                  | returns a token that     | lifetime |
  // |--------|------------------------|--------------------------|----------|
  // | init   | nothing                | ROLE_OTP_PENDING         | 300s     |
  // | verify | the init token         | ROLE_CHANGE_PASSWORD     | 300s     |
  // | change | the verify token       | — (clears the cookie)    | —        |
  //
  // **This OTP is real**, which is the difference from registration's.
  // `initPasswordRecovery` calls `otpService.saveOtp` (AuthService:234), so
  // `validate` has something to compare against. Three wrong tries blocks the
  // code (`OtpData.excedioIntentos`).

  /// `POST /auth/recover-password/init` — step 1.
  ///
  /// Body: `{ "email": String }` — `RecoverPasswordInitBody`, `@NotBlank` and
  /// `@Email`. Looks the address up across patients, doctors AND operators.
  ///
  /// 200: `{ "Message": "Se ha enviado un código OTP a tu correo" }` — capital
  /// `M`, like `init-registration-patient`.
  /// 404: `{ "message": "No existe un usuario con ese correo" }`.
  ///
  /// Must go out WITHOUT a token: see `AuthInterceptor._anonymousPaths`.
  static const String recoverPasswordInit = '$_auth/recover-password/init';

  /// `POST /auth/recover-password/verify-otp` — step 2.
  ///
  /// Body: `{ "otp": String }` — `VerifyOtpBody`. Authenticates with step 1's
  /// token; the server takes the email from `auth.getName()`, so the client
  /// never re-sends it.
  ///
  /// 200: `{ "Message": "Código verificado correctamente" }`.
  /// 400: "Has superado el límite de intentos" (after 3 wrong codes) or
  /// "Código OTP incorrecto o expirado".
  static const String recoverPasswordVerifyOtp =
      '$_auth/recover-password/verify-otp';

  /// `POST /auth/recover-password/change` — step 3.
  ///
  /// Body: `{ "password": String, "repeatedPassword": String }` —
  /// `ChangePasswordBody`. The server compares them itself and answers 400
  /// "Las contraseñas no coinciden", so the client's own confirm-field check is
  /// a courtesy, not the guarantee.
  ///
  /// Authenticates with step 2's token. 200: `{ "Message": String }`.
  static const String recoverPasswordChange = '$_auth/recover-password/change';

  /// `POST /auth/verify-registration-otp` — verifies REGISTRATION's code.
  ///
  /// **Not `/auth/verify-otp`, and the token it returns does not carry
  /// `ROLE_REGISTER_VERIFIED`.** An earlier version of this file invented
  /// both: that path 404s, and that authority does not exist anywhere in
  /// `Backend_QMS` — grepping the whole backend for it returns zero hits.
  /// The real route is the one above (`AuthController.java:119`) and the
  /// real authority is `ROLE_PENDING_REGISTRATION`
  /// (`AuthService.java:174`). This is precisely the failure mode this
  /// file's own header warns about: a comment that lies convinces the next
  /// reader they already checked.
  ///
  /// Body: `{ "otp": String }` — `VerifyOtpBody`, the same shape recovery
  /// uses. Authenticates with step 1's `ROLE_OTP_PENDING` flash token; the
  /// server takes the email from `auth.getName()`.
  ///
  /// Returns a NEW flash token via `Set-Cookie`, carrying
  /// `ROLE_PENDING_REGISTRATION`, 300 seconds — the same flash token as step 1.
  ///
  /// **The specific authority does not matter for step 3**, which is what
  /// makes the token swap safe: `register-patient` has no `hasAuthority`
  /// matcher in `GlobalConfig`, and `AuthService.completeRegistration` only
  /// compares `auth.getName()` with the submitted email. Both flash tokens
  /// carry the same subject, so step 3 accepts either one.
  ///
  /// 200 body: `{ "Message": "Código OTP verificado correctamente", "email":
  /// String }` — capital `M`, like `init-registration-patient`.
  /// `AuthRemoteDataSourceImpl` never reads it; only the cookie matters here.
  ///
  /// Consumed by `RegistrationBloc._onCodeSubmitted`.
  static const String verifyRegistrationOtp = '$_auth/verify-registration-otp';

  // ==========================================================
  // PATIENT — the signed-in patient's own record
  // ==========================================================

  /// `@RequestMapping("/api/patients")` on `PatientController`.
  static const String _patients = '/api/patients';

  /// `GET /api/patients/me` — **does not exist as a route yet.**
  ///
  /// `PatientController` has only `PUT /me` (below) and
  /// `PUT /change-password`; there is no `@GetMapping("/me")`, even though
  /// `PatientService.getPatientById` exists and could back one. Listed here
  /// anyway, per this file's own rule: an honest gap is easier to fix than a
  /// route that silently 404s because nobody wrote it down.
  ///
  /// Once it lands it should take no parameters — the same way `PUT /me`
  /// already resolves the caller from `auth.getName()`, parsed with
  /// `UUID.fromString`. That is worth knowing ahead of time: the login
  /// token's subject is the patient's UUID, not their email, so a `GET /me`
  /// built the same way would only ever answer to the 24h login token, never
  /// to a registration flash token.
  static const String patientMe = '$_patients/me';

  /// `PUT /api/patients/me` — updates the signed-in patient's CONTACT data.
  ///
  /// Body: `PatientDTO`. The server ignores identity fields on purpose
  /// (`PatientService.updatePatient` only copies address, phone, the two
  /// emergency-contact fields and the email): the medical history is filed
  /// under the name, cedula and birthday, so those cannot move from an app.
  /// Sending them is harmless, they are simply dropped.
  ///
  /// 200 body: the updated `PatientDTO`.
  static const String patientMeUpdate = '$_patients/me';

  // ==========================================================
  // TURNS — the patient's appointments
  // ==========================================================

  /// `@RequestMapping("/api/turns")` on `TurnController`.
  static const String _turns = '/api/turns';

  /// `GET /api/turns/me` — the signed-in patient's appointments, paginated.
  ///
  /// Query: `status`, `from`, `to` (ISO `yyyy-MM-dd`), `page`, `size`. All
  /// optional. Filtered server-side by the patient in the token, which is the
  /// whole reason this exists instead of `GET /api/turns` — that one returns
  /// every turn in the system, other patients' cedulas included.
  ///
  /// `status` is what splits the "Proximas" / "Pasadas" tabs:
  /// `TURN_PENDING` / `TURN_WAITNG` vs `TURN_TREATED` / `TURN_CANCELLED`.
  /// Note the typo in `TURN_WAITNG` — it is the value stored in the database,
  /// so the client spells it wrong too. Fixing it is a migration, not a
  /// rename.
  ///
  /// 200 body: a Spring `Page<TurnDTO>`.
  static const String turnsMe = '$_turns/me';

  /// `POST /api/turns` — books a turn for the signed-in patient.
  ///
  /// Body: `TurnDTO` with a `schedule.id`. The server resolves the patient
  /// from the token and assigns the next `order` for that schedule's day.
  static const String turns = _turns;

  /// `PUT /api/turns/{id}/cancelled` — cancels one of the CALLER's own turns.
  ///
  /// No request body. Ownership is checked server-side, against the token —
  /// never against anything the client sends: `TurnService.cancelTurn`
  /// compares the turn's patient UUID with `auth.getName()` and answers 403
  /// `{ "error": "Error de permisos: Este turno no te pertenece" }` when they
  /// do not match (`TurnController.java:96-100`). A turn already
  /// `TURN_TREATED` or `TURN_CANCELLED` answers 400 instead.
  ///
  /// 200 body: the updated `TurnDTO`, same shape `POST /api/turns` returns.
  ///
  /// The only parameterised member of this class: every other endpoint here
  /// is a fixed path, but this one needs the turn id inline rather than as a
  /// query parameter.
  static String turnCancelled(int turnId) => '$_turns/$turnId/cancelled';

  // ==========================================================
  // AVAILABILITY — what "Agendar" is built from
  // ==========================================================

  /// `GET /api/schedules` — bookable slots, WITH FILTERS.
  ///
  /// Query: `doctorId` (UUID), `serviceId`, `stablishmentId`, `from`, `to`
  /// (ISO `yyyy-MM-dd`), `status`, plus `page` / `size`. All optional; with
  /// none of them it behaves like the old unfiltered listing, so nothing that
  /// called it before changed.
  ///
  /// The filters landed 2026-08-24 and they are what makes the three steps of
  /// "Agendar" possible: `doctorId` + `serviceId` + `status=STATUS_FREE`
  /// yields the distinct dates (step 2) and the hours of each date (step 3).
  ///
  /// **Ask for a big `size`.** The default page is 10, and a week of 20-minute
  /// slots is far more than that — a day grid built from page 0 silently
  /// misses the afternoon.
  static const String schedules = '/api/schedules';

  /// `GET /api/doctors` — step 1 of "Agendar". Paginated.
  static const String doctors = '/api/doctors';

  /// `GET /api/services` — the consultation types. Paginated.
  static const String services = '/api/services';

  // ==========================================================
  // LOGOUT
  // ==========================================================

  /// `POST /auth/logout` — exists. An earlier version of this file said it
  /// did not; `AuthController.java:239` has had `@PostMapping("/logout")`
  /// since before this app started calling it.
  ///
  /// Body: none. Clears the security context server-side and drops the
  /// `jwt` cookie. 200 body: `{ "message": "Sesión cerrada correctamente" }`
  /// — lowercase `message`, unlike registration's replies.
  ///
  /// **Calling it is still optional, and `AuthRepositoryImpl.signOut` treats
  /// it that way.** A stateless JWT is logged out just as well by deleting
  /// it from the device, which `AuthLocalDataSource.clear()` always does —
  /// even if this request fails. Calling it anyway revokes the cookie this
  /// response set, and matches what the Angular client already does
  /// (`auth.service.ts:147`).
  static const String logout = '$_auth/logout';
}
