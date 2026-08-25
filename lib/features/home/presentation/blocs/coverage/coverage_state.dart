part of 'coverage_bloc.dart';

enum CoverageStatus { initial, loading, ready, failure }

class CoverageState extends Equatable {
  const CoverageState._({
    required this.status,
    this.coverages = const <CoverageRecord>[],
    this.failure,
  });

  const CoverageState.initial() : this._(status: CoverageStatus.initial);

  final CoverageStatus status;
  final List<CoverageRecord> coverages;
  final Failure? failure;

  bool get isFirstLoad =>
      status == CoverageStatus.loading && coverages.isEmpty;

  bool get isEmpty => status == CoverageStatus.ready && coverages.isEmpty;

  bool get isSessionExpired => failure is SessionExpiredFailure;

  /// The one policy in effect right now, or null when the patient has no
  /// active coverage — either they never registered one, or every one on
  /// file has lapsed. The server guarantees at most one `true` among
  /// [CoverageRecord.active], so the first match is the only match.
  CoverageRecord? get active {
    for (final CoverageRecord coverage in coverages) {
      if (coverage.active) return coverage;
    }
    return null;
  }

  /// Every coverage that is NOT the active one — the policy history, kept
  /// separate so `PersonalInfoScreen` never renders a lapsed plan with the
  /// same visual weight as the current one.
  List<CoverageRecord> get history =>
      coverages.where((CoverageRecord c) => !c.active).toList();

  CoverageState copyWith({
    CoverageStatus? status,
    List<CoverageRecord>? coverages,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CoverageState._(
      status: status ?? this.status,
      coverages: coverages ?? this.coverages,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, coverages, failure];
}
