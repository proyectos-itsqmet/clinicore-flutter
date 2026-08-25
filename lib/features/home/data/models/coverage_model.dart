import '../../domain/entities/coverage.dart';
import 'json_reader.dart';

/// The backend's `PatientCoverageDTO`, with its nested `plan.insurer`
/// flattened — the same reasoning `TurnModel` flattens `schedule.doctor`
/// with: nothing in `PersonalInfoScreen` needs the plan's or the insurer's
/// OWN id, only their names and the plan's pricing terms.
class CoverageModel {
  const CoverageModel({
    required this.id,
    required this.insurerName,
    required this.planName,
    required this.coveragePercentage,
    required this.policyNumber,
    required this.active,
    this.copayAmount,
    this.validFrom,
    this.validUntil,
  });

  factory CoverageModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> plan = readMap(json['plan']);
    final Map<String, dynamic> insurer = readMap(plan['insurer']);

    return CoverageModel(
      id: readInt(json['id']),
      insurerName: readString(insurer['name']),
      planName: readString(plan['name']),
      coveragePercentage: readInt(plan['coveragePercentage']),
      copayAmount: readDoubleOrNull(plan['copayAmount']),
      policyNumber: readString(json['policyNumber']),
      validFrom: readDate(json['validFrom']),
      validUntil: readDate(json['validUntil']),
      active: readBool(json['active']),
    );
  }

  final int id;
  final String insurerName;
  final String planName;
  final int coveragePercentage;
  final double? copayAmount;
  final String policyNumber;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool active;

  CoverageRecord toEntity() => CoverageRecord(
    id: id,
    insurerName: insurerName,
    planName: planName,
    coveragePercentage: coveragePercentage,
    copayAmount: copayAmount,
    policyNumber: policyNumber,
    validFrom: validFrom,
    validUntil: validUntil,
    active: active,
  );
}
