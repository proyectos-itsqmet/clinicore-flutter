import 'package:flutter/material.dart';

import '../widgets/legal_document.dart';

/// "Terminos y condiciones", reached from the profile tab and from the
/// registration consent line.
///
/// The clause list below is the STRUCTURE a clinic's terms need — see
/// [LegalDocument]'s own note. The headings and their order are the real
/// contribution here; the paragraph text is placeholder and is marked as such
/// on screen.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocument(
      title: 'Términos y condiciones',
      intro:
          'Estas condiciones regulan el uso de la aplicación CLINI CORE '
          'para agendar turnos y consultar tu información clínica.',
      clauses: <LegalClause>[
        LegalClause(
          title: 'Quién presta el servicio',
          body: <String>[
            'La aplicación es operada por CliniCore S.A., con domicilio en '
                'Av. de los Shyris N38-120 y El Telegrafo, Quito y RUC 1790000000001.',
            'El uso de la app no reemplaza la relación médico-paciente ni '
                'constituye por sí mismo un acto médico.',
          ],
        ),
        LegalClause(
          title: 'Tu cuenta',
          body: <String>[
            'Para agendar necesitas una cuenta asociada a tu cédula. Los '
                'datos que registres deben ser verdaderos y estar '
                'actualizados: la historia clínica se archiva con ese número.',
            'Eres responsable de mantener tu contraseña en reserva. Si '
                'sospechas que alguien mas accedió a tu cuenta, cámbiala y '
                'avísanos.',
          ],
        ),
        LegalClause(
          title: 'Turnos, cancelaciones y ausencias',
          body: <String>[
            'Un turno agendado ocupa un cupo real en la agenda de un '
                'profesional. Podes cancelarlo hasta 24 horas antes de la hora '
                'reservada sin ningún cargo.',
            'La política de ausencias sin aviso es que el cupo se libera de '
                'inmediato y la ausencia queda registrada en tu historial de '
                'reservas.',
          ],
        ),
        LegalClause(
          title: 'Valores y cobertura',
          body: <String>[
            'Los valores mostrados antes de confirmar son estimados en base a '
                'la cobertura registrada de tu plan y pueden variar según lo '
                'que efectivamente se realice en la consulta.',
            'La liquidación definitiva se emite en la sede.',
          ],
        ),
        LegalClause(
          title: 'Uso de la aplicación',
          body: <String>[
            'No podes usar la app para agendar turnos a nombre de terceros sin '
                'su autorización, ni intentar acceder a información clínica '
                'que no sea la tuya o la de personas a tu cargo debidamente '
                'registradas.',
          ],
        ),
        LegalClause(
          title: 'Emergencias',
          body: <String>[
            'La aplicación NO es un canal de emergencias. Ante una urgencia, '
                'llama al 911 o acude directamente al '
                'servicio de emergencia más cercano.',
          ],
        ),
        LegalClause(
          title: 'Disponibilidad y cambios',
          body: <String>[
            'Hacemos lo razonable para mantener el servicio disponible, pero '
                'puede haber interrupciones por mantenimiento o por causas '
                'ajenas a la clínica.',
            'Si estas condiciones cambian, te avisamos en la app antes de que '
                'la nueva versión entre en vigencia.',
          ],
        ),
        LegalClause(
          title: 'Contacto',
          body: <String>[
            'Escríbenos a contacto@clinicore.ec o llama al (02) 380-0100 para '
                'cualquier consulta sobre estas condiciones.',
          ],
        ),
      ],
    );
  }
}
