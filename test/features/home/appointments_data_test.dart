import 'package:clinicore_flutter/features/home/data/models/turn_model.dart';
import 'package:clinicore_flutter/features/home/domain/entities/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for `TurnDTO`'s wire format, specifically the ticket.
///
/// El numero de turno se calcula POR SERVICIO Y POR FECHA, asi que dos
/// servicios tienen un turno #3 el mismo dia. Sin el prefijo del servicio el
/// numero es ambiguo: el paciente escucha "H-003" en la sala y su telefono le
/// dice "3", que es tambien el numero de otro paciente en otro consultorio.
///
/// El formato lo arma el BACKEND (`utils/Ticket`) y viaja en `TurnDTO.ticket`.
/// El cliente NO lo deriva: si lo hiciera, cada pantalla nueva podria inventar
/// el suyo y el mismo turno se veria distinto en dos lugares.
void main() {
  group('TurnModel ticket', () {
    Map<String, dynamic> json({Object? ticket = 'H-003'}) {
      return <String, dynamic>{
        'id': 41,
        'order': 3,
        'ticket': ticket,
        'status': 'TURN_PENDING',
        'schedule': <String, dynamic>{
          'date': '2026-08-27',
          'hour': '09:30:00',
          'doctor': <String, dynamic>{
            'firstName': 'Luis',
            'lastName': 'Andrade',
            'speciality': 'Odontologia',
          },
          'service': <String, dynamic>{'name': 'Odontologia General'},
          'stablishment': <String, dynamic>{'name': 'Sede Norte'},
        },
      };
    }

    test('carries the ticket the patient hears, not the bare order', () {
      final Appointment turno = TurnModel.fromJson(json()).toEntity();

      expect(turno.ticket, 'H-003');
    });

    test('falls back to the order when the backend sends no ticket', () {
      // Un backend anterior a `TurnDTO.ticket` devuelve la fila sin el campo.
      // La pantalla pierde el prefijo, no el numero: "3" sigue siendo mas util
      // que un hueco vacio donde el paciente espera su turno.
      final Appointment turno = TurnModel.fromJson(json(ticket: null)).toEntity();

      expect(turno.ticket, '3');
    });

    test('falls back to the order when the ticket comes back blank', () {
      // Un servicio sin prefijo cargado puede devolver cadena vacia. Vacio no
      // es un ticket: se trata igual que ausente.
      final Appointment turno = TurnModel.fromJson(json(ticket: '')).toEntity();

      expect(turno.ticket, '3');
    });
  });
}
