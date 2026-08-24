import 'package:dartz/dartz.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_remote_data_source.dart';
import '../models/patient_model.dart';

/// The translation layer for the patient's own record.
///
/// Thin on purpose: the exception-to-failure mapping lives in
/// `core/error/failure_mapper.dart`, shared with every other repository. This
/// class only knows which data source to call and how to turn its model into
/// an entity.
///
/// No `onBadRequest` override — a 400 here is a rejected payload (a duplicate
/// email, a malformed field) and the server's own message is better than
/// anything this app could invent.
class PatientRepositoryImpl implements PatientRepository {
  const PatientRepositoryImpl(this.remote);

  final PatientRemoteDataSource remote;

  @override
  Future<Either<Failure, PatientProfile>> getMyProfile() {
    return guardFailure(() async {
      final PatientModel model = await remote.fetchMyProfile();
      return model.toEntity();
    });
  }

  @override
  Future<Either<Failure, PatientProfile>> updateMyContact(
    PatientContactUpdate update,
  ) {
    return guardFailure(() async {
      final PatientModel model = await remote.updateMyContact(update);
      return model.toEntity();
    });
  }
}
