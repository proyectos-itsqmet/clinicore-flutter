import 'package:dartz/dartz.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/clinical_record.dart';
import '../../domain/repositories/clinical_repository.dart';
import '../datasources/clinical_remote_data_source.dart';
import '../models/encounter_model.dart';
import '../models/prescription_model.dart';
import '../models/turn_model.dart';

class ClinicalRepositoryImpl implements ClinicalRepository {
  const ClinicalRepositoryImpl(this.remote);

  final ClinicalRemoteDataSource remote;

  @override
  Future<Either<Failure, List<EncounterRecord>>> getMyEncounters() {
    return guardFailure(() async {
      final PageModel<EncounterModel> page = await remote.fetchMyEncounters();
      return page.content
          .map((EncounterModel model) => model.toEntity())
          .toList();
    });
  }

  @override
  Future<Either<Failure, List<PrescriptionRecord>>> getMyPrescriptions() {
    return guardFailure(() async {
      final PageModel<PrescriptionModel> page = await remote
          .fetchMyPrescriptions();
      return page.content
          .map((PrescriptionModel model) => model.toEntity())
          .toList();
    });
  }
}
