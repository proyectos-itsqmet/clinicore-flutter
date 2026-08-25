import '../../domain/entities/establishment.dart';
import 'json_reader.dart';

/// The backend's `StablishmentDTO`, reduced to what step 1 shows.
///
/// The DTO also carries the sede's assigned services, doctors and operators.
/// None of it is parsed here: each is fetched by its own endpoint once a
/// patient has picked a sede (`ServicioController`, `StablishmentController`),
/// so parsing them on the list card would mean every row in step 1 carrying a
/// payload nobody reads until step 2.
class EstablishmentModel {
  const EstablishmentModel({required this.id, required this.name, this.address});

  factory EstablishmentModel.fromJson(Map<String, dynamic> json) {
    return EstablishmentModel(
      id: readInt(json['id']),
      name: readString(json['name']),
      address: readStringOrNull(json['address']),
    );
  }

  final int id;
  final String name;
  final String? address;

  Establishment toEntity() => Establishment(
    id: id,
    // Never blank: a card with no name is untappable in practice, and a
    // sede with no name is a data problem the patient should see.
    name: name.isEmpty ? 'Sede sin nombre' : name,
    address: address,
  );
}
