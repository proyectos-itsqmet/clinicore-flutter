part of 'coverage_bloc.dart';

sealed class CoverageEvent extends Equatable {
  const CoverageEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load, or reload, the patient's coverage history.
///
/// Fired once on screen entry, and again on an explicit retry from the
/// Cobertura group's own failure card. `/api/patient-coverages/me` is NOT
/// on the audited clinical-log path (`PatientCoverageService` never calls
/// `ClinicalAccessLogService` — coverage is billing data, not a clinical
/// record), but this bloc still only fetches on entry and on explicit retry,
/// for the plainer reason every read-only bloc here does: nothing gains from
/// asking again before the caller asks again.
class CoverageRequested extends CoverageEvent {
  const CoverageRequested();
}
