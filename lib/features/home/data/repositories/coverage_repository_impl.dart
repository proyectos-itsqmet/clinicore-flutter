import 'package:dartz/dartz.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/coverage.dart';
import '../../domain/repositories/coverage_repository.dart';
import '../datasources/coverage_remote_data_source.dart';
import '../models/coverage_model.dart';

class CoverageRepositoryImpl implements CoverageRepository {
  const CoverageRepositoryImpl(this.remote);

  final CoverageRemoteDataSource remote;

  @override
  Future<Either<Failure, List<CoverageRecord>>> getMyCoverages() {
    return guardFailure(() async {
      final List<CoverageModel> models = await remote.fetchMyCoverages();
      return models.map((CoverageModel model) => model.toEntity()).toList();
    });
  }
}
