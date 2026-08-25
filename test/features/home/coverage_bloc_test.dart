import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/domain/entities/coverage.dart';
import 'package:clinicore_flutter/features/home/domain/usecases/coverage_usecases.dart';
import 'package:clinicore_flutter/features/home/presentation/blocs/coverage/coverage_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repositories.dart';

void main() {
  late FakeCoverageRepository repository;

  setUp(() => repository = FakeCoverageRepository());

  CoverageBloc buildBloc() =>
      CoverageBloc(getMyCoverages: GetMyCoverages(repository));

  test('the active coverage is distinguishable from a historical one', () async {
    repository.coveragesResult = Right<Failure, List<CoverageRecord>>(
      <CoverageRecord>[testExpiredCoverage, testActiveCoverage],
    );

    final CoverageBloc bloc = buildBloc()..add(const CoverageRequested());
    final CoverageState state = await bloc.stream.firstWhere(
      (s) => s.status == CoverageStatus.ready,
    );

    expect(state.active, testActiveCoverage);
    expect(state.history, <CoverageRecord>[testExpiredCoverage]);
    expect(state.history.every((c) => !c.active), isTrue);
    await bloc.close();
  });

  test('no active coverage among several historical ones', () async {
    repository.coveragesResult = Right<Failure, List<CoverageRecord>>(
      <CoverageRecord>[testExpiredCoverage],
    );

    final CoverageBloc bloc = buildBloc()..add(const CoverageRequested());
    final CoverageState state = await bloc.stream.firstWhere(
      (s) => s.status == CoverageStatus.ready,
    );

    expect(state.active, isNull);
    expect(state.history, <CoverageRecord>[testExpiredCoverage]);
    await bloc.close();
  });

  test('an empty coverage list reads as empty, not a failure', () async {
    final CoverageBloc bloc = buildBloc()..add(const CoverageRequested());
    final CoverageState state = await bloc.stream.firstWhere(
      (s) => s.status == CoverageStatus.ready,
    );

    expect(state.isEmpty, isTrue);
    expect(state.active, isNull);
    await bloc.close();
  });

  test('a load failure surfaces the failure, coverages empty', () async {
    repository.coveragesResult = const Left<Failure, List<CoverageRecord>>(
      NetworkFailure(),
    );

    final CoverageBloc bloc = buildBloc()..add(const CoverageRequested());
    final CoverageState state = await bloc.stream.firstWhere(
      (s) => s.status == CoverageStatus.failure,
    );

    expect(state.coverages, isEmpty);
    expect(state.failure, isA<NetworkFailure>());
    await bloc.close();
  });
}
