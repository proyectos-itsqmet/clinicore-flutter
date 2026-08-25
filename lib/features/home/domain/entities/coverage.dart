import 'package:equatable/equatable.dart';

/// One coverage policy the patient has held.
///
/// A patient may accumulate several of these over the years — a new insurer,
/// a renewed policy number — but the server guarantees AT MOST ONE is
/// [active] at a time (`PatientCoverageService` deactivates every other
/// record for the patient on save). [active] is what `PersonalInfoScreen`
/// uses to decide which one is CURRENT: rendering a historical policy the
/// same way as the active one would let a patient believe an expired plan
/// still covers them.
class CoverageRecord extends Equatable {
  const CoverageRecord({
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

  final int id;
  final String insurerName;
  final String planName;

  /// 0-100. The fraction of the price the insurer picks up, per
  /// `CoveragePlan.coveragePercentage`.
  final int coveragePercentage;

  /// Fixed amount charged before coinsurance applies. Null means no copay
  /// tier on this plan.
  final double? copayAmount;

  final String policyNumber;

  /// Nullable even though the server requires it (`@NotNull` on
  /// `PatientCoverageDTO.validFrom`): this app never invents a date for a
  /// field it could not parse — see `json_reader.dart`'s own rule — so a
  /// malformed response shows "Sin registrar" instead of a silently wrong
  /// "today".
  final DateTime? validFrom;

  /// Null: an ongoing policy with no known end date yet.
  final DateTime? validUntil;

  final bool active;

  @override
  List<Object?> get props => <Object?>[
    id,
    insurerName,
    planName,
    coveragePercentage,
    copayAmount,
    policyNumber,
    validFrom,
    validUntil,
    active,
  ];
}
