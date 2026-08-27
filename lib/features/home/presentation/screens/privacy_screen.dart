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
      title: 'Política de privacidad',
      intro:
          'Como CliniCore trata tus datos personales y tus datos '
          'de salud cuando usas esta aplicación.',
      clauses: <LegalClause>[
        LegalClause(
          title: 'Quién es responsable de tus datos',
          body: <String>[
            'El responsable del tratamiento es CliniCore S.A., RUC 1790000000001, con '
                'domicilio en Av. de los Shyris N38-120 y El Telegrafo, Quito.',
            'Puedes contactar a nuestro delegado de protección de datos en '
                'proteccion.datos@clinicore.ec.',
          ],
        ),
        LegalClause(
          title: 'Que datos recogemos',
          body: <String>[
            'Datos de identificación: nombre, cédula, fecha de nacimiento, '
                'correo y teléfono.',
            'Datos de salud: motivo de consulta, diagnósticos, recetas, '
                'resultados de laboratorio e imágenes. Son datos sensibles '
                'según la Ley Orgánica de Protección de Datos Personales y '
                'reciben el nivel de protección más alto que aplicamos.',
            'Datos de uso: turnos agendados, cancelaciones y registros de '
                'acceso a la app, que usamos para seguridad y auditoría.',
          ],
        ),
        LegalClause(
          title: 'Para que los usamos',
          body: <String>[
            'Para agendar y gestionar tus turnos, para que un profesional '
                'pueda atenderte con tu historia a la vista, para facturar y '
                'para cumplir obligaciones legales de conservación de la '
                'historia clínica.',
            'No usamos tus datos de salud para publicidad. Nunca.',
          ],
        ),
        LegalClause(
          title: 'Con qué base legal',
          body: <String>[
            'La ejecución de la relación asistencial y el cumplimiento de '
                'obligaciones legales sanitarias. Cuando el tratamiento '
                'requiere tu consentimiento, te lo pedimos de forma separada '
                'y puedes retirarlo.',
          ],
        ),
        LegalClause(
          title: 'Con quién los compartimos',
          body: <String>[
            'Con los profesionales que te atienden, con tu aseguradora cuando '
                'usas cobertura, con laboratorios e imagen cuando se derivan '
                'estudios, y con la autoridad sanitaria cuando la ley lo '
                'exige.',
            'Nuestros proveedores tecnólogicos actúan como encargados del '
                'tratamiento y están obligados por contrato a los mismos '
                'deberes de confidencialidad.',
          ],
        ),
        LegalClause(
          title: 'Cuánto tiempo los conservamos',
          body: <String>[
            'La historia clínica se conserva por el plazo que exige la '
                'normativa sanitaria ecuatoriana. Los datos de la cuenta se '
                'conservan mientras la cuenta esté activa y por 60 meses '
                'después de su cierre.',
          ],
        ),
        LegalClause(
          title: 'Tus derechos',
          body: <String>[
            'Puedes pedir acceso, rectificación, eliminación, oposición, '
                'portabilidad y la suspensión del tratamiento, y no ser '
                'sometido a decisiones automatizadas.',
            'Escribe a proteccion.datos@clinicore.ec y respondemos en el plazo legal. Si no '
                'estás conforme con la respuesta, puedes reclamar ante la '
                'autoridad de protección de datos.',
          ],
        ),
        LegalClause(
          title: 'Seguridad',
          body: <String>[
            'Ciframos la información en tránsito y en reposo, registramos '
                'cada acceso a una historia clínica y aplicamos el principio '
                'de mínimo privilegio: cada persona ve solo lo que necesita '
                'para atenderte.',
            'Si ocurre una vulneración que pueda afectarte, te lo '
                'notificamos.',
          ],
        ),
        LegalClause(
          title: 'Cambios en esta política',
          body: <String>[
            'Si cambia, te avisamos en la app antes de que la nueva versión '
                'entre en vigencia, indicando que se modificó.',
          ],
        ),
      ],
    );
  }
}
