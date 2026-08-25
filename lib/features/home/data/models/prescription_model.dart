import '../../domain/entities/clinical_record.dart';
import 'json_reader.dart';

/// The backend's `PrescriptionItemDTO` — one medication line.
class PrescriptionItemModel {
  const PrescriptionItemModel({
    required this.medication,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  factory PrescriptionItemModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionItemModel(
      medication: readString(json['medication']),
      dosage: readString(json['dosage']),
      frequency: readString(json['frequency']),
      duration: readString(json['duration']),
      instructions: readStringOrNull(json['instructions']),
    );
  }

  final String medication;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;

  PrescriptionItemEntry toEntity() => PrescriptionItemEntry(
    medication: medication,
    dosage: dosage,
    frequency: frequency,
    duration: duration,
    instructions: instructions,
  );
}

/// The backend's `PrescriptionDTO`.
///
/// `encounterId` is what `HistoryBloc` joins a prescription back to the
/// [EncounterModel] it belongs to — `/api/prescriptions/me` returns every
/// prescription for the caller, flat, across every encounter.
class PrescriptionModel {
  const PrescriptionModel({
    required this.id,
    required this.encounterId,
    required this.items,
    this.notes,
    this.createdAt,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      id: readInt(json['id']),
      encounterId: readInt(json['encounterId']),
      items: readMapList(
        json['items'],
      ).map(PrescriptionItemModel.fromJson).toList(),
      notes: readStringOrNull(json['notes']),
      createdAt: readDate(json['createdAt']),
    );
  }

  final int id;
  final int encounterId;
  final List<PrescriptionItemModel> items;
  final String? notes;
  final DateTime? createdAt;

  PrescriptionRecord toEntity() => PrescriptionRecord(
    id: id,
    encounterId: encounterId,
    items: items.map((PrescriptionItemModel i) => i.toEntity()).toList(),
    notes: notes,
    createdAt: createdAt,
  );
}
