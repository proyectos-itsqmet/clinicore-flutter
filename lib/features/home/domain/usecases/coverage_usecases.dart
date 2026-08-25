import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/coverage.dart';
import '../repositories/coverage_repository.dart';

/// Reads every coverage the signed-in patient has held.
class GetMyCoverages implements UseCase<List<CoverageRecord>, NoParams> {
  const GetMyCoverages(this._repository);

  final CoverageRepository _repository;

  @override
  Future<Either<Failure, List<CoverageRecord>>> call(NoParams params) {
    return _repository.getMyCoverages();
  }
}
