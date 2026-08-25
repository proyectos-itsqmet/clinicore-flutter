part of 'appointments_bloc.dart';

enum AppointmentsStatus { initial, loading, ready, failure }

class AppointmentsState extends Equatable {
  const AppointmentsState._({
    required this.status,
    this.items = const <Appointment>[],
    this.failure,
    this.cancellingId,
    this.cancelFailure,
    this.cancelFailureId,
  });

  const AppointmentsState.initial() : this._(status: AppointmentsStatus.initial);

  final AppointmentsStatus status;
  final List<Appointment> items;

  /// A LOAD failure — the reason the whole list could not be fetched. Kept
  /// separate from [cancelFailure] on purpose: the two answer different
  /// questions, and conflating them would turn "the cancel you just tried
  /// failed" into "we could not load your appointments", which is a lie the
  /// patient has no way to tell apart from the real thing.
  final Failure? failure;

  /// The `Appointment.id` a cancel request is in flight for, so only THAT
  /// card shows a spinner — the rest of the list stays interactive.
  final int? cancellingId;

  /// The last cancel attempt's failure, if any. Transient: cleared the moment
  /// another cancel starts or a reload succeeds. Never drives [isEmpty] or
  /// the failure branch the LOAD failure does — see [failure].
  final Failure? cancelFailure;

  /// Which appointment [cancelFailure] belongs to. Without this a failed
  /// cancel on one card would show its message under every card in the list.
  final int? cancelFailureId;

  /// Only while there is nothing to draw yet. A reload with items already on
  /// screen keeps them and shows the refresh indicator instead of collapsing
  /// back into skeletons.
  bool get isFirstLoad =>
      status == AppointmentsStatus.loading && items.isEmpty;

  /// The difference between "you have no appointments" and "we could not load
  /// them" — an empty state shown after a failed request is a lie, and the
  /// worst kind: it tells a patient they have nothing booked.
  bool get isEmpty =>
      status == AppointmentsStatus.ready && items.isEmpty;

  bool get isSessionExpired => failure is SessionExpiredFailure;

  bool get isCancelling => cancellingId != null;

  AppointmentsState copyWith({
    AppointmentsStatus? status,
    List<Appointment>? items,
    Failure? failure,
    bool clearFailure = false,
    int? cancellingId,
    bool clearCancellingId = false,
    Failure? cancelFailure,
    int? cancelFailureId,
    bool clearCancelFailure = false,
  }) {
    return AppointmentsState._(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
      cancellingId: clearCancellingId
          ? null
          : (cancellingId ?? this.cancellingId),
      cancelFailure: clearCancelFailure
          ? null
          : (cancelFailure ?? this.cancelFailure),
      cancelFailureId: clearCancelFailure
          ? null
          : (cancelFailureId ?? this.cancelFailureId),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    items,
    failure,
    cancellingId,
    cancelFailure,
    cancelFailureId,
  ];
}
