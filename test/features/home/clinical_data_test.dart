import 'package:clinicore_flutter/features/home/data/models/encounter_model.dart';
import 'package:clinicore_flutter/features/home/data/models/prescription_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the wire format `HistoryBloc` joins on. `turnId` and
/// `encounterId` are the two fields that MUST parse correctly for the join
/// in `HistoryBloc._merge` to land on the right visit — a wrong key here
/// would silently attach one patient's prescription to the wrong encounter.
void main() {
  group('EncounterModel', () {
    test('parses every field the history card needs', () {
      final EncounterModel model = EncounterModel.fromJson(<String, dynamic>{
        'id': 100,
        'turnId': 10,
        'reasonForVisit': 'Dolor de cabeza',
        'diagnosis': 'Migrana tensional',
        'clinicalNotes': 'Paciente reporta dolor recurrente',
        'visitDate': '2026-11-12',
        'doctorFullName': 'Ana Torres',
        'createdAt': '2026-11-12T10:15:00-05:00',
      });

      expect(model.id, 100);
      expect(model.turnId, 10);
      expect(model.reasonForVisit, 'Dolor de cabeza');
      expect(model.diagnosis, 'Migrana tensional');
      expect(model.visitDate, DateTime(2026, 11, 12));
      expect(model.doctorFullName, 'Ana Torres');
    });

    test('turnId is read from its own key — the join breaks otherwise', () {
      final EncounterModel a = EncounterModel.fromJson(<String, dynamic>{
        'id': 1,
        'turnId': 10,
        'reasonForVisit': 'x',
        'diagnosis': 'y',
      });
      final EncounterModel b = EncounterModel.fromJson(<String, dynamic>{
        'id': 2,
        'turnId': 11,
        'reasonForVisit': 'x',
        'diagnosis': 'y',
      });

      expect(a.toEntity().turnId, 10);
      expect(b.toEntity().turnId, 11);
    });

    test('a missing clinicalNotes/visitDate/doctorFullName does not throw', () {
      final EncounterModel model = EncounterModel.fromJson(<String, dynamic>{
        'id': 1,
        'turnId': 10,
        'reasonForVisit': 'x',
        'diagnosis': 'y',
      });

      expect(model.clinicalNotes, isNull);
      expect(model.visitDate, isNull);
      expect(model.doctorFullName, isNull);
    });
  });

  group('PrescriptionModel', () {
    test('parses every medication as its own item, never collapsed', () {
      final PrescriptionModel model = PrescriptionModel.fromJson(
        <String, dynamic>{
          'id': 200,
          'encounterId': 100,
          'notes': 'Control en 5 dias',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'medication': 'Ibuprofeno',
              'dosage': '400mg',
              'frequency': 'Cada 8 horas',
              'duration': '5 dias',
              'instructions': 'Tomar con alimentos',
            },
            <String, dynamic>{
              'medication': 'Paracetamol',
              'dosage': '500mg',
              'frequency': 'Cada 6 horas',
              'duration': '3 dias',
            },
          ],
        },
      );

      expect(model.id, 200);
      expect(model.encounterId, 100);
      expect(model.items, hasLength(2));
      expect(model.items[0].medication, 'Ibuprofeno');
      expect(model.items[0].instructions, 'Tomar con alimentos');
      expect(model.items[1].medication, 'Paracetamol');
      expect(model.items[1].instructions, isNull);
    });

    test('an empty items list parses to an empty list, not a crash', () {
      final PrescriptionModel model = PrescriptionModel.fromJson(
        <String, dynamic>{'id': 1, 'encounterId': 1, 'items': <Map<String, dynamic>>[]},
      );

      expect(model.items, isEmpty);
    });

    test('toEntity carries every item across, in order', () {
      final PrescriptionModel model = PrescriptionModel.fromJson(
        <String, dynamic>{
          'id': 200,
          'encounterId': 100,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'medication': 'A',
              'dosage': '1',
              'frequency': 'f',
              'duration': 'd',
            },
            <String, dynamic>{
              'medication': 'B',
              'dosage': '2',
              'frequency': 'f',
              'duration': 'd',
            },
          ],
        },
      );

      final entity = model.toEntity();
      expect(
        entity.items.map((item) => item.medication),
        <String>['A', 'B'],
      );
    });
  });
}
