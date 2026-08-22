import 'package:flutter/material.dart';

import '../widgets/legal_document.dart';

/// "Politica de privacidad".
///
/// The clause order follows what Ecuador's Ley Organica de Proteccion de
/// Datos Personales actually requires a controller to disclose — who holds
/// the data, what is collected, on what legal basis, who it is shared with,
/// how long it is kept, and what rights the holder can exercise and how. That
/// order is the real work in this file; the paragraph text is placeholder and
/// is marked as such on screen.
///
/// Health data is a special category under that law, which is why the second
/// clause names it explicitly instead of folding it into "datos personales".
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocument(
      title: 'Politica de privacidad',
      intro:
          'Como [NOMBRE DE LA CLINICA] trata tus datos personales y tus datos '
          'de salud cuando usas esta aplicacion.',
      clauses: <LegalClause>[
        LegalClause(
          title: 'Quien es responsable de tus datos',
          body: <String>[
            'El responsable del tratamiento es [RAZON SOCIAL], RUC [RUC], con '
                'domicilio en [DIRECCION].',
            'Podes contactar a nuestro delegado de proteccion de datos en '
                '[CORREO DEL DPO].',
          ],
        ),
        LegalClause(
          title: 'Que datos recogemos',
          body: <String>[
            'Datos de identificacion: nombre, cedula, fecha de nacimiento, '
                'correo y telefono.',
            'Datos de salud: motivo de consulta, diagnosticos, recetas, '
                'resultados de laboratorio e imagenes. Son datos sensibles '
                'segun la Ley Organica de Proteccion de Datos Personales y '
                'reciben el nivel de proteccion mas alto que aplicamos.',
            'Datos de uso: turnos agendados, cancelaciones y registros de '
                'acceso a la app, que usamos para seguridad y auditoria.',
          ],
        ),
        LegalClause(
          title: 'Para que los usamos',
          body: <String>[
            'Para agendar y gestionar tus turnos, para que un profesional '
                'pueda atenderte con tu historia a la vista, para facturar y '
                'para cumplir obligaciones legales de conservacion de la '
                'historia clinica.',
            'No usamos tus datos de salud para publicidad. Nunca.',
          ],
        ),
        LegalClause(
          title: 'Con que base legal',
          body: <String>[
            'La ejecucion de la relacion asistencial y el cumplimiento de '
                'obligaciones legales sanitarias. Cuando el tratamiento '
                'requiere tu consentimiento, te lo pedimos de forma separada '
                'y podes retirarlo.',
          ],
        ),
        LegalClause(
          title: 'Con quien los compartimos',
          body: <String>[
            'Con los profesionales que te atienden, con tu aseguradora cuando '
                'usas cobertura, con laboratorios e imagen cuando se derivan '
                'estudios, y con la autoridad sanitaria cuando la ley lo '
                'exige.',
            'Nuestros proveedores tecnologicos actuan como encargados del '
                'tratamiento y estan obligados por contrato a los mismos '
                'deberes de confidencialidad.',
          ],
        ),
        LegalClause(
          title: 'Cuanto tiempo los conservamos',
          body: <String>[
            'La historia clinica se conserva por el plazo que exige la '
                'normativa sanitaria ecuatoriana. Los datos de la cuenta se '
                'conservan mientras la cuenta este activa y por [PLAZO] '
                'despues de su cierre.',
          ],
        ),
        LegalClause(
          title: 'Tus derechos',
          body: <String>[
            'Podes pedir acceso, rectificacion, eliminacion, oposicion, '
                'portabilidad y la suspension del tratamiento, y no ser '
                'sometido a decisiones automatizadas.',
            'Escribi a [CORREO DEL DPO] y respondemos en el plazo legal. Si no '
                'estas conforme con la respuesta, podes reclamar ante la '
                'autoridad de proteccion de datos.',
          ],
        ),
        LegalClause(
          title: 'Seguridad',
          body: <String>[
            'Ciframos la informacion en transito y en reposo, registramos '
                'cada acceso a una historia clinica y aplicamos el principio '
                'de minimo privilegio: cada persona ve solo lo que necesita '
                'para atenderte.',
            'Si ocurre una vulneracion que pueda afectarte, te lo '
                'notificamos.',
          ],
        ),
        LegalClause(
          title: 'Cambios en esta politica',
          body: <String>[
            'Si cambia, te avisamos en la app antes de que la nueva version '
                'entre en vigencia, indicando que se modifico.',
          ],
        ),
      ],
    );
  }
}
