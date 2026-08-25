import 'package:clinicore_flutter/core/error/exceptions.dart';
import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/data/models/coverage_model.dart';
import 'package:clinicore_flutter/features/home/data/repositories/coverage_repository_impl.dart';
import 'package:clinicore_flutter/features/home/domain/entities/coverage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_datasources.dart';

void main() {
  late FakeCoverageRemoteDataSource remote;
  late CoverageRepositoryImpl repository;

  setUp(() {
    remote = FakeCoverageRemoteDataSource();
    repository = CoverageRepositoryImpl(remote);
  });

  test('maps every coverage the server returned, active flag included', () async {
    remote.coverages = const <CoverageModel>[
      CoverageModel(
        id: 1,
        insurerName: 'Seguros Equinoccial',
        planName: 'Plan Oro',
        coveragePercentage: 80,
        policyNumber: 'POL-001',
        active: true,
      ),
      CoverageModel(
        id: 2,
        insurerName: 'IESS',
        planName: 'Plan Basico',
        coveragePercentage: 50,
        policyNumber: 'POL-000',
        active: false,
      ),
    ];

    final result = await repository.getMyCoverages();

    final List<CoverageRecord> coverages = result.fold(
      (Failure f) => throw StateError('expected Right, got $f'),
      (List<CoverageRecord> value) => value,
    );
    expect(coverages, hasLength(2));
    expect(
      coverages.where((CoverageRecord c) => c.active).single.insurerName,
      'Seguros Equinoccial',
    );
  });

  test('a data-source failure becomes a Failure, not an exception', () async {
    remote.coveragesError = const NetworkException(message: 'x');

    final result = await repository.getMyCoverages();

    expect(result.isLeft(), isTrue);
  });
}
