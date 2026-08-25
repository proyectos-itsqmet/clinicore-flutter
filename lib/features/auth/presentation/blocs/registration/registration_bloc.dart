import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/patient_registration.dart';
import '../../../domain/usecases/registration_usecases.dart';

part 'registration_event.dart';
part 'registration_state.dart';

/// The three-step sign-up.
///
/// One bloc for the whole flow, not one per screen, because the steps share
/// state that has to survive navigation: the email and cedula entered in step
/// 1 are what step 3 must submit, and `AuthService.completeRegistration`
/// rejects the call if the email does not match the one the flash token was
/// issued for. Three separate blocs would mean passing that pair through route
/// arguments and hoping nobody edits it.
///
/// It is provided by a `ShellRoute` around the three registration routes, so
/// it lives exactly as long as the flow does.
///
/// ## The 300-second cliff
///
/// `init-registration-patient` issues a token that expires in **five
/// minutes**, and step 3 authenticates with it. A patient who takes their time
/// on the profile form — looking up their emergency contact's number, say —
/// will hit a 401 that has nothing to do with anything they typed.
///
/// So [_onProfileSubmitted] treats [SessionExpiredFailure] specially: instead
/// of showing "sesion vencida" on a form for an account that does not exist
/// yet, it walks the flow back to step 1 with an explanation. Anything else is
/// a dead end the patient cannot get out of.
///
/// ## About the OTP step
///
/// The code IS verified by the server now — `POST /auth/verify-registration-otp`. It used
/// not to be: `initRegistration` mailed a code but never stored it, so there
/// was nothing to check it against and this handler advanced the step locally.
/// Both halves exist today, so the code the patient types is no longer
/// decorative and a wrong one keeps them on this step.
///
/// **Three wrong codes block the address**, and the block is per address rather
/// than per attempt — so the only way out is [RegistrationCodeResendRequested],
/// which re-runs step 1. That is also what refreshes the 300-second token, so
/// it is the right escape hatch for both problems at once.
class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  RegistrationBloc({
    required this.initRegistration,
    required this.verifyRegistrationOtp,
    required this.completeRegistration,
  }) : super(const RegistrationState()) {
    on<RegistrationIdentitySubmitted>(_onIdentitySubmitted);
    on<RegistrationCodeSubmitted>(_onCodeSubmitted);
    on<RegistrationCodeResendRequested>(_onCodeResendRequested);
    on<RegistrationProfileSubmitted>(_onProfileSubmitted);
    on<RegistrationFailureDismissed>(_onFailureDismissed);
    on<RegistrationRestarted>(_onRestarted);
  }

  final InitRegistration initRegistration;
  final VerifyRegistrationOtp verifyRegistrationOtp;
  final CompleteRegistration completeRegistration;

  /// Step 1 — claim the email and cedula, get a code mailed.
  Future<void> _onIdentitySubmitted(
    RegistrationIdentitySubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(
      state.copyWith(status: RegistrationStatus.submitting, clearFailure: true),
    );

    final result = await initRegistration(
      InitRegistrationParams(email: event.email, cedula: event.cedula),
    );

    emit(
      result.fold(
        (failure) => state.copyWith(
          status: RegistrationStatus.failure,
          failure: failure,
        ),
        (_) => state.copyWith(
          status: RegistrationStatus.idle,
          step: RegistrationStep.verification,
          email: event.email,
          cedula: event.cedula,
        ),
      ),
    );
  }

  /// Step 2 — the code, checked by the server.
  ///
  /// The step only advances on success. On failure the patient stays here with
  /// the server's own message ("El código no es válido", "Has superado el
  /// límite de intentos"), which is more useful than anything this bloc could
  /// invent — it is the only side that knows what the real code was.
  ///
  /// `otp` is still stored in the state. Step 3 does not send it, so this is
  /// only so the screen can keep showing what was typed if the flow walks back.
  Future<void> _onCodeSubmitted(
    RegistrationCodeSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(
      state.copyWith(status: RegistrationStatus.submitting, clearFailure: true),
    );

    final result = await verifyRegistrationOtp(
      VerifyRegistrationOtpParams(otp: event.code),
    );

    emit(
      result.fold(
        (failure) => state.copyWith(
          status: RegistrationStatus.failure,
          failure: failure,
        ),
        (_) => state.copyWith(
          status: RegistrationStatus.idle,
          step: RegistrationStep.profile,
          otp: event.code,
          clearFailure: true,
        ),
      ),
    );
  }

  /// Re-runs step 1 with the same pair, which is what mails a new code.
  ///
  /// Note this ALSO refreshes the 300-second token, which is the more
  /// important effect: a patient who sat on the code screen for six minutes
  /// needs a new token more than a new code.
  Future<void> _onCodeResendRequested(
    RegistrationCodeResendRequested event,
    Emitter<RegistrationState> emit,
  ) async {
    final String? email = state.email;
    final String? cedula = state.cedula;
    if (email == null || cedula == null) return;

    emit(
      state.copyWith(status: RegistrationStatus.submitting, clearFailure: true),
    );

    final result = await initRegistration(
      InitRegistrationParams(email: email, cedula: cedula),
    );

    emit(
      result.fold(
        (failure) => state.copyWith(
          status: RegistrationStatus.failure,
          failure: failure,
        ),
        (_) => state.copyWith(status: RegistrationStatus.idle),
      ),
    );
  }

  /// Step 3 — the profile, and the call that actually creates the patient.
  Future<void> _onProfileSubmitted(
    RegistrationProfileSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    final String? email = state.email;
    final String? cedula = state.cedula;
    if (email == null || cedula == null) {
      // Nothing to submit against. Only reachable by deep-linking straight to
      // the last step, which is worth handling rather than crashing.
      emit(
        state.copyWith(
          step: RegistrationStep.identity,
          status: RegistrationStatus.failure,
          failure: const ValidationFailure(
            message: 'Empecemos de nuevo: falta tu correo y cedula.',
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(status: RegistrationStatus.submitting, clearFailure: true),
    );

    final result = await completeRegistration(
      PatientRegistration(
        email: email,
        cedula: cedula,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        birthday: event.birthday,
        gender: event.gender,
        phone: event.phone,
        address: event.address,
        emergencyContactName: event.emergencyContactName,
        emergencyContactPhone: event.emergencyContactPhone,
      ),
    );

    emit(
      result.fold(
        (failure) {
          // The 300-second cliff. Sending the patient back to step 1 with a
          // reason beats leaving them on a form that will keep failing.
          if (failure is SessionExpiredFailure) {
            return state.copyWith(
              step: RegistrationStep.identity,
              status: RegistrationStatus.failure,
              failure: const ValidationFailure(
                message:
                    'Se agoto el tiempo para completar el registro. '
                    'Volvamos a empezar: son cinco minutos desde que pides '
                    'el codigo.',
              ),
            );
          }
          return state.copyWith(
            status: RegistrationStatus.failure,
            failure: failure,
          );
        },
        (session) => state.copyWith(
          status: RegistrationStatus.idle,
          step: RegistrationStep.done,
          session: session,
        ),
      ),
    );
  }

  void _onFailureDismissed(
    RegistrationFailureDismissed event,
    Emitter<RegistrationState> emit,
  ) {
    emit(state.copyWith(status: RegistrationStatus.idle, clearFailure: true));
  }

  void _onRestarted(
    RegistrationRestarted event,
    Emitter<RegistrationState> emit,
  ) {
    emit(const RegistrationState());
  }
}
