import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/domain/entities/appointment.dart';
import 'package:clinicore_flutter/features/home/domain/entities/clinical_record.dart';
import 'package:clinicore_flutter/features/home/domain/repositories/appointments_repository.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/appointments_usecases.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/clinical_usecases.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/history/history_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repositories.dart';

/// Tests for the join `HistoryBloc` performs across three independent reads
/// — see the bloc's class doc. `screens_test.dart` covers the rendering; the
/// merge logic and the failure-degradation rules live here, driven directly
/// against fakes.
void main() {
  late FakeAppointmentsRepository appointmentsRepository;
  late FakeClinicalRepository clinicalRepository;

  setUp(() {
    appointmentsRepository = FakeAppointmentsRepository();
    clinicalRepository = FakeClinicalRepository();
  });

  HistoryBloc buildBloc() {
    return HistoryBloc(
      getMyAppointments: GetMyAppointments(appointmentsRepository),
      getMyEncounters: GetMyEncounters(clinicalRepository),
      getMyPrescriptions: GetMyPrescriptions(clinicalRepository),
    );
  }

  void seedAttended(List<Appointment> items) {
    appointmentsRepository.results[AppointmentScope.attended] =
        Right<Failure, AppointmentPage>(
          AppointmentPage(
            items: items,
            page: 0,
            isLast: true,
            totalElements: items.length,
          ),
        );
  }

  test('asks for the ATTENDED scope, never upcoming or past', () async {
    seedAttended(testAttended);
    final HistoryBloc bloc = buildBloc()..add(const HistoryRequested());

    await bloc.stream.firstWhere((s) => s.status == HistoryStatus.ready);

    expect(appointmentsRepository.requestedScopes, <AppointmentScope>[
      AppointmentScope.attended,
    ]);
    await bloc.close();
  });

  test('joins a visit to its documented encounter and every prescription item', () async {
    seedAttended(testAttended);
    clinicalRepository.encountersResult = Right<Failure, List<EncounterRecord>>(
      testEncounters,
    );
    clinicalRepository.prescriptionsResult =
        Right<Failure, List<PrescriptionRecord>>(testPrescriptions);

    final HistoryBloc bloc = buildBloc()..add(const HistoryRequested());
    final HistoryState state = await bloc.stream.firstWhere(
      (s) => s.status == HistoryStatus.ready,
    );

    final documented = state.entries.firstWhere(
      (e) => e.appointment.id == 10,
    );
    expect(documented.hasClinicalDetail, isTrue);
    expect(documented.encounter!.diagnosis, 'Migrana tensional');
    expect(documented.prescriptions.single.items, hasLength(2));
    expect(
      documented.prescriptions.single.items.map((i) => i.medication),
      <String>['Ibuprofeno', 'Paracetamol'],
    );

    await bloc.close();
  });

  test('a visit with no documented encounter still appears, with no clinical detail', () async {
    seedAttended(testAttended);
    clinicalRepository.encountersResult = Right<Failure, List<EncounterRecord>>(
      testEncounters,
    );

    final HistoryBloc bloc = buildBloc()..add(const HistoryRequested());
    final HistoryState state = await bloc.stream.firstWhere(
      (s) => s.status == HistoryStatus.ready,
    );

    expect(state.entries, hasLength(2));
    final undocumented = state.entries.firstWhere(
      (e) => e.appointment.id == 11,
    );
    expect(undocumented.hasClinicalDetail, isFalse);
    expect(undocumented.prescriptions, isEmpty);

    await bloc.close();
  });

  test('an empty attended list reads as empty, not as a failure', () async {
    seedAttended(const <Appointment>[]);

    final HistoryBloc bloc = buildBloc()..add(const HistoryRequested());
    final HistoryState state = await bloc.stream.firstWhere(
      (s) => s.status == HistoryStatus.ready,
    );

    expect(state.isEmpty, isTrue);
    await bloc.close();
  });

  test('a failed appointments load fails the whole screen', () async {
    appointmentsRepository.results[AppointmentScope.attended] =
        const Left<Failure, AppointmentPage>(NetworkFailure());

    final HistoryBloc bloc = buildBloc()..add(const HistoryRequested());
    final HistoryState state = await bloc.stream.firstWhere(
      (s) => s.status == HistoryStatus.failure,
    );

    expect(state.entries, isEmpty);
    await bloc.close();
  });

  test('a failed encounters/prescriptions load still shows the visit list', () async {
    seedAttended(testAttended);
    clinicalRepository.encountersResult =
        const Left<Failure, List<EncounterRecord>>(ServerFailure());
    clinicalRepository.prescriptionsResult =
        const Left<Failure, List<PrescriptionRecord>>(ServerFailure());

    final HistoryBloc bloc = buildBloc()..add(const HistoryRequested());
    final HistoryState state = await bloc.stream.firstWhere(
      (s) => s.status == HistoryStatus.ready,
    );

    expect(state.entries, hasLength(2));
    expect(state.entries.every((e) => !e.hasClinicalDetail), isTrue);
    await bloc.close();
  });

  test('a reload failure keeps the list already on screen', () async {
    seedAttended(testAttended);
    final HistoryBloc bloc = buildBloc()..add(const HistoryRequested());
    await bloc.stream.firstWhere((s) => s.status == HistoryStatus.ready);

    appointmentsRepository.results[AppointmentScope.attended] =
        const Left<Failure, AppointmentPage>(NetworkFailure());
    bloc.add(const HistoryRequested());
    final HistoryState state = await bloc.stream.firstWhere(
      (s) => s.status == HistoryStatus.failure,
    );

    expect(state.isReloadFailure, isTrue);
    expect(state.entries, hasLength(2));
    await bloc.close();
  });
}
