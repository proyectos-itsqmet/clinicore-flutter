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
  // | verify | the init token         | ROLE_CHANGE_PASSWORD     | 600s     |
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

  // ==========================================================
  // NOT ON THE SERVER YET
  // ==========================================================

  /// **DOES NOT EXIST.** There is no OTP verification endpoint.
  ///
  /// `OtpService` has `generateOtp`, `saveOtp` and `validate`, but
  /// `AuthService.initRegistration` calls only `generateOtp` — it never calls
  /// `saveOtp`, so `otpStore` is always empty — and nothing anywhere calls
  /// `validate`. The code the app would need is written; it is simply not
  /// wired to a route.
  ///
  /// Consequence today: the emailed code is decorative. The flash token from
  /// step 1 alone is enough to complete registration.
  static const String verifyOtp = '$_auth/verify-otp';

  /// **DOES NOT EXIST as a route**, though `JwtValidator` special-cases
  /// `/auth/logout` in its exception handler so an expired token can still
  /// clear the cookie. `AuthController` has no `@PostMapping("/logout")`.
  ///
  /// It costs the mobile app nothing: a stateless JWT is logged out by
  /// deleting it from the device, which is what `AuthLocalDataSource` does.
  static const String logout = '$_auth/logout';
}
