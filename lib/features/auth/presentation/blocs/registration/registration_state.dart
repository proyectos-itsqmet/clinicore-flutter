part of 'registration_bloc.dart';

/// Where in the flow we are.
enum RegistrationStep {
  /// Email + cedula.
  identity,

  /// The mailed code.
  verification,

  /// Name, birthday, password, and the optional rest.
  profile,

  /// Registered and signed in.
  done,
}

enum RegistrationStatus { idle, submitting, failure }

class RegistrationState extends Equatable {
  const RegistrationState({
    this.step = RegistrationStep.identity,
    this.status = RegistrationStatus.idle,
    this.email,
    this.cedula,
    this.otp,
    this.failure,
    this.session,
  });

  final RegistrationStep step;
  final RegistrationStatus status;

  /// Captured in step 1 and reused in step 3. It MUST be the same value both
  /// times — the server compares it against the flash token's subject.
  final String? email;
  final String? cedula;

  /// What the patient typed in step 2. Held so it can be sent the day the
  /// server starts verifying it.
  final String? otp;

  final Failure? failure;

  /// Non-null once [step] is [RegistrationStep.done].
  final AuthSession? session;

  bool get isSubmitting => status == RegistrationStatus.submitting;

  RegistrationState copyWith({
    RegistrationStep? step,
    RegistrationStatus? status,
    String? email,
    String? cedula,
    String? otp,
    Failure? failure,
    AuthSession? session,
    bool clearFailure = false,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      status: status ?? this.status,
      email: email ?? this.email,
      cedula: cedula ?? this.cedula,
      otp: otp ?? this.otp,
      failure: clearFailure ? null : (failure ?? this.failure),
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    step,
    status,
    email,
    cedula,
    otp,
    failure,
    session,
  ];
}
