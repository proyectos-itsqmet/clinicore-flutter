part of 'history_bloc.dart';

sealed class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load, or reload, the patient's clinical history.
///
/// Fired once on screen entry and again only on an explicit pull-to-refresh
/// — never from `build()`. Reading `/api/encounters/me` or
/// `/api/prescriptions/me` writes a `ClinicalAccessLog` row server-side per
/// call, so a widget that refetched on every rebuild would flood a medical
/// audit trail with reads nobody asked for.
class HistoryRequested extends HistoryEvent {
  const HistoryRequested();
}
