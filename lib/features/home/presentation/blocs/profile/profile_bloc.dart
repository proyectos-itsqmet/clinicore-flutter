import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/patient_profile.dart';
import '../../../domain/usecases/profile_usecases.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// Owns the signed-in patient's own record.
///
/// ONE bloc for "Mi perfil" and "Mi informacion" because they show the same
/// record: the tab shows the name and cedula, the detail screen shows all of
/// it. Two blocs would mean two fetches of the same endpoint and two chances
/// for them to disagree after an edit.
///
/// Registered as a **lazy singleton**, unlike the form blocs. That is the
/// deliberate exception to this app's factory rule (see `injection.dart`): the
/// profile is read once and read from two screens, and a factory would refetch
/// on every navigation between them. The state is not a form's — there is no
/// stale error to carry into a second visit.
///
/// SESSION EXPIRY IS NOT SWALLOWED. A [SessionExpiredFailure] lands in the
/// state like any other, and the screen forwards it to [AuthBloc]. Handling it
/// here by calling sign-out would put routing decisions inside a data bloc.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required this.getMyProfile, required this.updateMyContact})
    : super(const ProfileState.initial()) {
    on<ProfileRequested>(_onRequested);
    on<ProfileContactSubmitted>(_onContactSubmitted);
    on<ProfileReset>(_onReset);
  }

  final GetMyProfile getMyProfile;
  final UpdateMyContact updateMyContact;

  Future<void> _onRequested(
    ProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    // A refresh keeps the profile on screen while it reloads. Blanking it
    // would make a pull-to-refresh look like the data was lost.
    emit(state.copyWith(status: ProfileStatus.loading, clearFailure: true));

    final result = await getMyProfile(const NoParams());

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: ProfileStatus.failure, failure: failure),
        (PatientProfile profile) => state.copyWith(
          status: ProfileStatus.ready,
          profile: profile,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> _onContactSubmitted(
    ProfileContactSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.saving, clearFailure: true));

    final result = await updateMyContact(event.update);

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: ProfileStatus.failure, failure: failure),
        // The SERVER's version replaces the local one, not the submitted one.
        // The two differ whenever the server ignored a field, and showing what
        // was actually stored is the only honest thing after a save.
        (PatientProfile profile) => state.copyWith(
          status: ProfileStatus.saved,
          profile: profile,
          clearFailure: true,
        ),
      ),
    );
  }

  void _onReset(ProfileReset event, Emitter<ProfileState> emit) {
    emit(const ProfileState.initial());
  }
}
