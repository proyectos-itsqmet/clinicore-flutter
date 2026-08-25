import 'package:clinicore_flutter/core/error/exceptions.dart';
import 'package:clinicore_flutter/core/error/failures.dart';
import 'package:clinicore_flutter/features/home/data/models/encounter_model.dart';
import 'package:clinicore_flutter/features/home/data/models/prescription_model.dart';
import 'package:clinicore_flutter/features/home/data/models/turn_model.dart';
import 'package:clinicore_flutter/features/home/data/repositories/clinical_repository_impl.dart';
import 'package:clinicore_flutter/features/home/domain/entities/clinical_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_datasources.dart';

void main() {
  late FakeClinicalRemoteDataSource remote;
  late ClinicalRepositoryImpl repository;

  setUp(() {
    remote = FakeClinicalRemoteDataSource();
    repository = ClinicalRepositoryImpl(remote);
  });

  group('getMyEncounters', () {
    test('maps every encounter the server returned', () async {
      remote.encountersPage = const PageModel<EncounterModel>(
        content: <EncounterModel>[
          EncounterModel(
            id: 100,
            turnId: 10,
            reasonForVisit: 'x',
            diagnosis: 'Migrana tensional',
          ),
        ],
        number: 0,
        last: true,
        totalElements: 1,
      );

      final result = await repository.getMyEncounters();

      final List<EncounterRecord> encounters = result.fold(
        (Failure f) => throw StateError('expected Right, got $f'),
        (List<EncounterRecord> value) => value,
      );
      expect(encounters.single.turnId, 10);
      expect(encounters.single.diagnosis, 'Migrana tensional');
    });

    test('a data-source failure becomes a Failure, not an exception', () async {
      remote.encountersError = const NetworkException(message: 'x');

      final result = await repository.getMyEncounters();

      expect(result.isLeft(), isTrue);
    });
  });

  group('getMyPrescriptions', () {
    test('maps every prescription, items included', () async {
      remote.prescriptionsPage = const PageModel<PrescriptionModel>(
        content: <PrescriptionModel>[
          PrescriptionModel(
            id: 200,
            encounterId: 100,
            items: <PrescriptionItemModel>[
              PrescriptionItemModel(
                medication: 'Ibuprofeno',
                dosage: '400mg',
                frequency: 'f',
                duration: 'd',
              ),
            ],
          ),
        ],
        number: 0,
        last: true,
        totalElements: 1,
      );

      final result = await repository.getMyPrescriptions();

      final List<PrescriptionRecord> prescriptions = result.fold(
        (Failure f) => throw StateError('expected Right, got $f'),
        (List<PrescriptionRecord> value) => value,
      );
      expect(prescriptions.single.encounterId, 100);
      expect(prescriptions.single.items.single.medication, 'Ibuprofeno');
    });

    test('a data-source failure becomes a Failure, not an exception', () async {
      remote.prescriptionsError = const ServerException(message: 'x');

      final result = await repository.getMyPrescriptions();

      expect(result.isLeft(), isTrue);
    });
  });
}
