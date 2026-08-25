import 'package:clinicore_flutter/features/home/data/models/coverage_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for `PatientCoverageDTO`'s wire format — specifically the
/// `plan.insurer` nesting `CoverageModel` flattens, and the `active` flag
/// `PersonalInfoScreen` depends on to tell a current policy from a lapsed
/// one.
void main() {
  group('CoverageModel', () {
    Map<String, dynamic> json({bool active = true, String? validUntil}) {
      return <String, dynamic>{
        'id': 1,
        'policyNumber': 'POL-001',
        'validFrom': '2026-01-01',
        'validUntil': validUntil,
        'active': active,
        'plan': <String, dynamic>{
          'id': 5,
          'name': 'Plan Oro',
          'coveragePercentage': 80,
          'copayAmount': 10.5,
          'insurer': <String, dynamic>{
            'id': 2,
            'name': 'Seguros Equinoccial',
            'type': 'INSURER_PRIVATE',
          },
        },
      };
    }

    test('flattens plan.insurer.name and plan.name onto the model', () {
      final CoverageModel model = CoverageModel.fromJson(json());

      expect(model.insurerName, 'Seguros Equinoccial');
      expect(model.planName, 'Plan Oro');
      expect(model.coveragePercentage, 80);
      expect(model.copayAmount, 10.5);
    });

    test('an active policy with no end date parses validUntil as null', () {
      final CoverageModel model = CoverageModel.fromJson(json());

      expect(model.active, isTrue);
      expect(model.validUntil, isNull);
      expect(model.validFrom, DateTime(2026, 1, 1));
    });

    test('a lapsed policy carries active:false and its end date', () {
      final CoverageModel model = CoverageModel.fromJson(
        json(active: false, validUntil: '2025-12-31'),
      );

      expect(model.active, isFalse);
      expect(model.validUntil, DateTime(2025, 12, 31));
    });

    test('a missing plan or insurer does not throw', () {
      final CoverageModel model = CoverageModel.fromJson(<String, dynamic>{
        'id': 1,
        'policyNumber': 'POL-001',
        'validFrom': '2026-01-01',
        'active': true,
      });

      expect(model.insurerName, '');
      expect(model.planName, '');
      expect(model.coveragePercentage, 0);
    });
  });
}
