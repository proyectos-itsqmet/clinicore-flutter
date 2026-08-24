part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load, or reload, the patient's record.
///
/// Fired on first build and on pull-to-refresh. The bloc keeps whatever it
/// already had on screen while this runs — see the handler.
class ProfileRequested extends ProfileEvent {
  const ProfileRequested();
}

/// Save the editable half.
///
/// Carries a [PatientContactUpdate] and not a whole profile, because that is
/// the only shape the server honours. See the entity for why.
class ProfileContactSubmitted extends ProfileEvent {
  const ProfileContactSubmitted(this.update);

  final PatientContactUpdate update;

  @override
  List<Object?> get props => <Object?>[update];
}
