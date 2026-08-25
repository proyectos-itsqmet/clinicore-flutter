part of 'history_bloc.dart';

enum HistoryStatus { initial, loading, ready, failure }

class HistoryState extends Equatable {
  const HistoryState._({
    required this.status,
    this.entries = const <HistoryEntry>[],
    this.failure,
  });

  const HistoryState.initial() : this._(status: HistoryStatus.initial);

  final HistoryStatus status;
  final List<HistoryEntry> entries;

  /// The reason the last request failed. Cleared on every new request and on
  /// every success — see the bloc's `clearFailure: true`.
  final Failure? failure;

  /// Only while there is genuinely nothing to draw yet.
  bool get isFirstLoad => status == HistoryStatus.loading && entries.isEmpty;

  /// The difference between "no visits yet" and "we could not load them" —
  /// an empty state shown after a failed request would tell a patient they
  /// have no history when the truth is the request never landed.
  bool get isEmpty => status == HistoryStatus.ready && entries.isEmpty;

  /// A reload failed but there is still a list on screen from before this
  /// attempt. `_HistoryView` keeps the list up and shows a note instead of
  /// replacing it with the whole-screen failure card — the same "keep what
  /// was already shown" rule `AppointmentsState`/`ProfileState` apply to a
  /// failed refresh.
  bool get isReloadFailure =>
      status == HistoryStatus.failure && entries.isNotEmpty;

  bool get isSessionExpired => failure is SessionExpiredFailure;

  HistoryState copyWith({
    HistoryStatus? status,
    List<HistoryEntry>? entries,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return HistoryState._(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, entries, failure];
}
