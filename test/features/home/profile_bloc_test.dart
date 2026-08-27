import 'package:clinicore_flutter/features/home/domain/entities/patient_profile.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/profile_usecases.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/profile/profile_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repositories.dart';

void main() {
  late FakePatientRepository repository;

  setUp(() => repository = FakePatientRepository());

  ProfileBloc buildBloc() => ProfileBloc(
    getMyProfile: GetMyProfile(repository),
    updateMyContact: UpdateMyContact(repository),
  );

  test('ProfileRequested loads and emits ready state with profile', () async {
    final ProfileBloc bloc = buildBloc()..add(const ProfileRequested());

    final ProfileState readyState = await bloc.stream.firstWhere(
      (s) => s.status == ProfileStatus.ready,
    );

    expect(readyState.profile, testProfile);
    expect(readyState.status, ProfileStatus.ready);
    await bloc.close();
  });

  test('ProfileReset resets the bloc back to initial status and clears profile', () async {
    final ProfileBloc bloc = buildBloc()..add(const ProfileRequested());

    await bloc.stream.firstWhere((s) => s.status == ProfileStatus.ready);

    bloc.add(const ProfileReset());

    final ProfileState resetState = await bloc.stream.firstWhere(
      (s) => s.status == ProfileStatus.initial,
    );

    expect(resetState.status, ProfileStatus.initial);
    expect(resetState.profile, isNull);
    await bloc.close();
  });

  test('ProfileContactSubmitted updates profile and emits saved status', () async {
    final ProfileBloc bloc = buildBloc()..add(const ProfileRequested());
    await bloc.stream.firstWhere((s) => s.status == ProfileStatus.ready);

    const PatientContactUpdate update = PatientContactUpdate(
      email: 'updated@example.com',
      phone: '0999999999',
    );

    bloc.add(const ProfileContactSubmitted(update));

    final ProfileState savedState = await bloc.stream.firstWhere(
      (s) => s.status == ProfileStatus.saved,
    );

    expect(savedState.status, ProfileStatus.saved);
    expect(repository.lastUpdate, update);
    await bloc.close();
  });
}
