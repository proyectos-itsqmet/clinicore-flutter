part of 'login_bloc.dart';

enum LoginStatus { idle, submitting, success, failure }

class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.idle,
    this.failure,
    this.session,
    this.biometricsAvailable = false,
  });

  final LoginStatus status;

  /// What went wrong, when [status] is [LoginStatus.failure]. Carries the
  /// user-facing message; the screen never composes its own.
  final Failure? failure;

  /// Non-null once [status] is [LoginStatus.success].
  final AuthSession? session;

  /// Whether to show the fingerprint button at all.
  final bool biometricsAvailable;

  bool get isSubmitting => status == LoginStatus.submitting;

  /// `copyWith` cannot clear a nullable field — passing null means "leave it".
  /// [clearFailure] is the explicit way to say "actually remove it", which is
  /// needed every time a new attempt starts. Without it, a stale error hangs
  /// around under a spinner.
  LoginState copyWith({
    LoginStatus? status,
    Failure? failure,
    AuthSession? session,
    bool? biometricsAvailable,
    bool clearFailure = false,
  }) {
    return LoginState(
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
      session: session ?? this.session,
      biometricsAvailable: biometricsAvailable ?? this.biometricsAvailable,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    failure,
    session,
    biometricsAvailable,
  ];
}
