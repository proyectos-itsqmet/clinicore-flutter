import 'package:dartz/dartz.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../datasources/appointments_remote_data_source.dart';
import '../datasources/turn_updates_remote_data_source.dart';
import '../models/turn_model.dart';

/// The translation layer for the patient's appointments.
///
/// It also does the ONE thing the server cannot: order the result.
/// `findTurnsForPatient` sorts by date descending, which is right for the past
/// and backwards for what is coming. And when a scope spans several statuses
/// the data source merges several requests, so the union arrives grouped by
/// status rather than by date. Sorting here means every caller gets a list
/// that reads in the order the screen shows it.
///
/// Two data sources, on purpose: [remote] is Dio/REST, [realtime] is a STOMP
/// socket, and they do not share an interface because they do not share a
/// transport — folding a socket subscription into the same interface as
/// `fetchMyTurns`/`cancelTurn` would mix two different failure and lifecycle
/// models under one name.
class AppointmentsRepositoryImpl implements AppointmentsRepository {
  const AppointmentsRepositoryImpl(this.remote, this.realtime);

  final AppointmentsRemoteDataSource remote;
  final TurnUpdatesRemoteDataSource realtime;

  @override
  Future<Either<Failure, AppointmentPage>> getMyAppointments({
    required AppointmentScope scope,
    int page = 0,
    int size = 20,
  }) {
    return guardFailure(() async {
      final PageModel<TurnModel> result = await remote.fetchMyTurns(
        statuses: scope.statuses,
        page: page,
        size: size,
      );

      final List<Appointment> items = result.content
          .map((TurnModel model) => model.toEntity())
          .toList();

      _sort(items, ascending: scope.ascending);

      return AppointmentPage(
        items: items,
        page: result.number,
        isLast: result.last,
        totalElements: result.totalElements,
      );
    });
  }

  @override
  Future<Either<Failure, Appointment>> cancelAppointment(int turnId) {
    return guardFailure(() async {
      final TurnModel model = await remote.cancelTurn(turnId);
      return model.toEntity();
    });
  }

  @override
  Stream<Appointment> watchTurnUpdates() => realtime.watchTurnUpdates();

  /// Sorts by day, then by hour within the day.
  ///
  /// Appointments with no date sink to the bottom in BOTH directions. That is
  /// deliberate: a turn whose schedule was deleted is a real row the server
  /// returns, and letting it float to the top of "Proximas" would put a card
  /// with no date where the next appointment should be.
  ///
  /// The time is compared as the `HH:mm` STRING, which sorts correctly because
  /// it is zero-padded — `readTime` guarantees that. Parsing it into a
  /// `DateTime` to compare would be more code for the same answer.
  void _sort(List<Appointment> items, {required bool ascending}) {
    items.sort((Appointment a, Appointment b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;

      final int byDate = a.date!.compareTo(b.date!);
      final int byTime = (a.time ?? '').compareTo(b.time ?? '');
      final int result = byDate != 0 ? byDate : byTime;

      return ascending ? result : -result;
    });
  }
}
