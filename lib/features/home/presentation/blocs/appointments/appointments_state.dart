part of 'appointments_bloc.dart';

enum AppointmentsStatus { initial, loading, ready, failure }

class AppointmentsState extends Equatable {
  const AppointmentsState._({
    required this.status,
    this.items = const <Appointment>[],
    this.failure,
  });

  const AppointmentsState.initial() : this._(status: AppointmentsStatus.initial);

  final AppointmentsStatus status;
  final List<Appointment> items;
  final Failure? failure;

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

  AppointmentsState copyWith({
    AppointmentsStatus? status,
    List<Appointment>? items,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AppointmentsState._(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, items, failure];
}
