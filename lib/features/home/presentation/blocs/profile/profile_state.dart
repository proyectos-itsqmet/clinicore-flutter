part of 'profile_bloc.dart';

enum ProfileStatus {
  /// Nothing asked for yet.
  initial,

  /// A read is in flight. [ProfileState.profile] may still hold the previous
  /// one — a refresh does not blank the screen.
  loading,

  ready,

  /// A write is in flight.
  saving,

  /// A write landed. Transient: the screen shows a confirmation and the state
  /// is otherwise identical to [ready].
  saved,

  failure,
}

class ProfileState extends Equatable {
  const ProfileState._({required this.status, this.profile, this.failure});

  const ProfileState.initial() : this._(status: ProfileStatus.initial);

  final ProfileStatus status;

  /// Survives a failed refresh on purpose: showing the last known record with
  /// an error banner is better than replacing a working screen with an error.
  final PatientProfile? profile;

  final Failure? failure;

  bool get isBusy =>
      status == ProfileStatus.loading || status == ProfileStatus.saving;

  /// True only while there is genuinely nothing to draw. The skeleton branch
  /// keys off this, not off [isBusy] — a refresh with data already on screen
  /// must not collapse back into placeholders.
  bool get isFirstLoad => status == ProfileStatus.loading && profile == null;

  /// The session died and the screen has to tell [AuthBloc], not retry.
  bool get isSessionExpired => failure is SessionExpiredFailure;

  ProfileState copyWith({
    ProfileStatus? status,
    PatientProfile? profile,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ProfileState._(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      // `copyWith` cannot express "set this to null" with a nullable
      // parameter, and a stale error surviving a successful reload is exactly
      // the bug that produces. Hence the explicit flag.
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, profile, failure];
}
