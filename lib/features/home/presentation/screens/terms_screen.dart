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
      title: 'Terminos y condiciones',
      lastUpdated: '[FECHA]',
      intro:
          'Estas condiciones regulan el uso de la aplicacion de [NOMBRE DE LA '
          'CLINICA] para agendar turnos y consultar tu informacion clinica.',
      clauses: <LegalClause>[
        LegalClause(
          title: 'Quien presta el servicio',
          body: <String>[
            'La aplicacion es operada por [RAZON SOCIAL], con domicilio en '
                '[DIRECCION] y RUC [RUC].',
            'El uso de la app no reemplaza la relacion medico-paciente ni '
                'constituye por si mismo un acto medico.',
          ],
        ),
        LegalClause(
          title: 'Tu cuenta',
          body: <String>[
            'Para agendar necesitas una cuenta asociada a tu cedula. Los '
                'datos que registres deben ser verdaderos y estar '
                'actualizados: la historia clinica se archiva con ese numero.',
            'Sos responsable de mantener tu contrasena en reserva. Si '
                'sospechas que alguien mas accedio a tu cuenta, cambiala y '
                'avisanos.',
          ],
        ),
        LegalClause(
          title: 'Turnos, cancelaciones y ausencias',
          body: <String>[
            'Un turno agendado ocupa un cupo real en la agenda de un '
                'profesional. Podes cancelarlo hasta [PLAZO] antes de la hora '
                'reservada sin ningun cargo.',
            'La politica de ausencias sin aviso es [POLITICA].',
          ],
        ),
        LegalClause(
          title: 'Valores y cobertura',
          body: <String>[
            'Los valores mostrados antes de confirmar son estimados en base a '
                'la cobertura registrada de tu plan y pueden variar segun lo '
                'que efectivamente se realice en la consulta.',
            'La liquidacion definitiva se emite en la sede.',
          ],
        ),
        LegalClause(
          title: 'Uso de la aplicacion',
          body: <String>[
            'No podes usar la app para agendar turnos a nombre de terceros sin '
                'su autorizacion, ni intentar acceder a informacion clinica '
                'que no sea la tuya o la de personas a tu cargo debidamente '
                'registradas.',
          ],
        ),
        LegalClause(
          title: 'Emergencias',
          body: <String>[
            'La aplicacion NO es un canal de emergencias. Ante una urgencia, '
                'llama al [NUMERO DE EMERGENCIA] o acude directamente al '
                'servicio de emergencia mas cercano.',
          ],
        ),
        LegalClause(
          title: 'Disponibilidad y cambios',
          body: <String>[
            'Hacemos lo razonable para mantener el servicio disponible, pero '
                'puede haber interrupciones por mantenimiento o por causas '
                'ajenas a la clinica.',
            'Si estas condiciones cambian, te avisamos en la app antes de que '
                'la nueva version entre en vigencia.',
          ],
        ),
        LegalClause(
          title: 'Contacto',
          body: <String>[
            'Escribinos a [CORREO DE CONTACTO] o llamanos al [TELEFONO] para '
                'cualquier consulta sobre estas condiciones.',
          ],
        ),
      ],
    );
  }
}
