import 'package:equatable/equatable.dart';

import 'availability.dart';

/// A place the clinic attends patients — step 1 of "Agendar".
///
/// Not the admin panel's establishment: no assigned services, doctors or
/// operators. Those are fetched separately, by their own endpoints, once a
/// patient has actually picked a sede — carrying them here would mean every
/// row in step 1's list dragging data nobody reads until step 2.
class Establishment extends Equatable {
  const Establishment({required this.id, required this.name, this.address});

  final int id;
  final String name;
  final String? address;

  @override
  List<Object?> get props => <Object?>[id, name, address];
}

/// One of step 2's cards: a service offered at the chosen establishment,
/// plus the doctors who perform it there.
///
/// Mirrors `clinicore-angular`'s `ServiceWithDoctors` (`booking-page.ts`).
/// An empty [doctors] list is not an error — it is the clinic not naming
/// anyone specific for the service, which is what turns into "cualquier
/// doctor disponible" instead of a chip list.
class ServiceWithDoctors extends Equatable {
  const ServiceWithDoctors({required this.service, required this.doctors});

  final BookingService service;
  final List<BookingDoctor> doctors;

  @override
  List<Object?> get props => <Object?>[service, doctors];
}
