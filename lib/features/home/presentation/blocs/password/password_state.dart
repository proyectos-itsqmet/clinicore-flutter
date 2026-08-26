part of 'password_bloc.dart';

enum PasswordStatus {
  /// The form is open and untouched.
  initial,

  /// The request is in flight.
  saving,

  /// The server stored the new password. Terminal for this screen: it pops.
  changed,

  failure,
}

class PasswordState extends Equatable {
  const PasswordState._({required this.status, this.failure});

  const PasswordState.initial() : this._(status: PasswordStatus.initial);

  final PasswordStatus status;

  /// Why the last attempt failed. A [ValidationFailure] here carries the
  /// SERVER's own text ("Las contrasenas no coinciden") — for a rejected
  /// payload the server knows more than this app does, which is why
  /// `PatientRepositoryImpl` deliberately has no `onBadRequest` override.
  final Failure? failure;

  bool get isSubmitting => status == PasswordStatus.saving;

  bool get isChanged => status == PasswordStatus.changed;

  /// The session died mid-form. The screen forwards this to [AuthBloc]
  /// instead of offering a retry that would fail forever — the same contract
  /// every other bloc in this feature follows.
  bool get isSessionExpired => failure is SessionExpiredFailure;

  PasswordState copyWith({
    PasswordStatus? status,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return PasswordState._(
      status: status ?? this.status,
      // `copyWith` cannot express "set this to null" through a nullable
      // parameter, and a stale error surviving a successful retry is exactly
      // the bug that produces.
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, failure];
}
