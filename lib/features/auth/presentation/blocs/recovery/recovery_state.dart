part of 'recovery_bloc.dart';

/// Where in the recovery flow we are.
enum RecoveryStep {
  /// The address.
  email,

  /// The mailed code.
  code,

  /// The new password.
  password,

  /// Changed. The patient signs in again.
  done,
}

enum RecoveryStatus { idle, submitting, failure }

class RecoveryState extends Equatable {
  const RecoveryState({
    this.step = RecoveryStep.email,
    this.status = RecoveryStatus.idle,
    this.email,
    this.failure,
  });

  final RecoveryStep step;
  final RecoveryStatus status;

  /// Captured in step 1 and held for two reasons only: to SHOW the patient
  /// where the mail went, and to resend without asking again.
  ///
  /// It is never sent in a request body after step 1 — the server reads it
  /// from the flash token, which is the single source of truth for whose
  /// password is being changed.
  final String? email;

  final Failure? failure;

  bool get isSubmitting => status == RecoveryStatus.submitting;

  RecoveryState copyWith({
    RecoveryStep? step,
    RecoveryStatus? status,
    String? email,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return RecoveryState(
      step: step ?? this.step,
      status: status ?? this.status,
      email: email ?? this.email,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[step, status, email, failure];
}
