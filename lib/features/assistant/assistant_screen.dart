import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'assistant_service.dart';

/// Un mensaje de la conversación.
class _Mensaje {
  _Mensaje({required this.esDelBot, required this.texto});

  final bool esDelBot;
  String texto;
}

/// El asistente virtual de atención al cliente.
///
/// DÓNDE VA
///
/// En las pantallas de ANTES de iniciar sesión. Este asistente es anónimo por
/// diseño: informa sobre servicios, precios, especialidades, sedes y turnos
/// disponibles, y no responde nada de un paciente en particular. A alguien que
/// ya inició sesión, un "por seguridad, inicia sesión" no se le lee como
/// seguridad: se le lee como que el chat está roto.
///
/// TEXTO Y AUDIO
///
/// El paciente puede escribir o grabar un audio. El audio NO cambia el
/// asistente: el servicio lo transcribe y el texto entra al mismo agente. Es
/// una capa de traducción en la entrada, nada más.
///
/// STREAMING
///
/// La respuesta se escribe de a poco, a medida que llega del servidor. No hay
/// ningún temporizador simulando el efecto: se lee el cuerpo de la respuesta
/// HTTP mientras el servidor lo va enviando (ver [AssistantService]).
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  /// Tope de duración de un audio. Un audio largo cuesta más y casi nunca es
  /// una consulta legítima: nadie tarda un minuto en preguntar por un turno.
  static const int _maxSegundos = 60;

  final AssistantService _asistente = AssistantService();
  final AudioRecorder _grabador = AudioRecorder();
  final TextEditingController _entrada = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Agrupa los mensajes de una misma conversación en la memoria del agente.
  /// NO es una credencial y no identifica a nadie.
  late final String _sessionId = _idAlAzar();

  final List<_Mensaje> _mensajes = <_Mensaje>[
    _Mensaje(
      esDelBot: true,
      texto:
          'Hola. Puedo informarte sobre nuestros médicos y especialidades, '
          'turnos disponibles, direcciones y precios.\n\n'
          'Puedes escribir o grabar un audio con tu consulta.',
    ),
  ];

  bool _enviando = false;
  String _estado = '';
  bool _grabando = false;
  int _segundos = 0;

  Timer? _contador;
  StreamSubscription<AssistantEvent>? _suscripcion;

  @override
  void dispose() {
    _contador?.cancel();
    _suscripcion?.cancel();
    _grabador.dispose();
    _entrada.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static String _idAlAzar() {
    final int ahora = DateTime.now().millisecondsSinceEpoch;
    final int azar = Random().nextInt(0xFFFFFF);
    return 's-${ahora.toRadixString(36)}-${azar.toRadixString(36)}';
  }

  String get _transcurrido {
    final int m = _segundos ~/ 60;
    final String s = (_segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // -------------------------------------------------------------------------
  // Texto
  // -------------------------------------------------------------------------

  void _enviar() {
    final String texto = _entrada.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() {
      _mensajes.add(_Mensaje(esDelBot: false, texto: texto));
      _entrada.clear();
    });

    _consumir(_asistente.chat(sessionId: _sessionId, mensaje: texto));
  }

  // -------------------------------------------------------------------------
  // Audio
  // -------------------------------------------------------------------------

  Future<void> _empezarAGrabar() async {
    if (_enviando || _grabando) return;

    // `hasPermission` con `request: true` muestra el diálogo del sistema la
    // primera vez y devuelve la respuesta del paciente.
    final bool permitido = await _grabador.hasPermission();
    if (!permitido) {
      if (!mounted) return;
      setState(() {
        _mensajes.add(
          _Mensaje(
            esDelBot: true,
            texto:
                'No tengo permiso para usar el micrófono. Puedes habilitarlo '
                'en los ajustes del teléfono, o escribir tu consulta.',
          ),
        );
      });
      _alFinal();
      return;
    }

    try {
      // aacLc produce un contenedor MPEG-4, de ahí la extensión .m4a. Es uno
      // de los formatos que acepta el servicio de transcripción.
      //
      // Se toma solo el `.path` en lugar de guardar el `Directory`, para no
      // tener que importar `dart:io` en este archivo: ese import rompe la
      // compilación a web, y la pantalla en sí no necesita nada más de ahí.
      final String carpeta = (await getTemporaryDirectory()).path;
      final String ruta =
          '$carpeta/consulta_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _grabador.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: ruta,
      );

      if (!mounted) return;
      setState(() {
        _grabando = true;
        _segundos = 0;
      });

      _contador = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _segundos++);
        // Se corta solo al llegar al tope, y ENVÍA lo grabado: cortar y
        // descartar haría perder el audio sin avisar.
        if (_segundos >= _maxSegundos) _terminarYEnviar();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _grabando = false;
        _mensajes.add(
          _Mensaje(
            esDelBot: true,
            texto: 'No pude iniciar la grabación. Escribe tu consulta.',
          ),
        );
      });
      _alFinal();
    }
  }

  /// Detiene la grabación y envía el audio.
  Future<void> _terminarYEnviar() async {
    if (!_grabando) return;

    _contador?.cancel();
    _contador = null;

    final String? ruta = await _grabador.stop();

    if (!mounted) return;
    setState(() {
      _grabando = false;
      _segundos = 0;
    });

    if (ruta == null) return;

    setState(() {
      // El evento `transcripcion` va a reemplazar este texto por lo que el
      // paciente realmente dijo.
      _mensajes.add(_Mensaje(esDelBot: false, texto: 'Audio enviado'));
    });
    _alFinal();

    _consumir(_asistente.chatAudio(sessionId: _sessionId, rutaArchivo: ruta));
  }

  /// Descarta la grabación en curso. No se envía nada.
  ///
  /// Existe porque sin él el único camino era enviar: si el paciente se
  /// equivocaba al hablar quedaba obligado a mandar el audio, y cada audio
  /// enviado es una transcripción que se paga. `cancel()` del grabador además
  /// borra el archivo.
  Future<void> _descartarGrabacion() async {
    if (!_grabando) return;

    _contador?.cancel();
    _contador = null;

    await _grabador.cancel();

    if (!mounted) return;
    setState(() {
      _grabando = false;
      _segundos = 0;
    });
  }

  // -------------------------------------------------------------------------
  // Consumo del streaming
  // -------------------------------------------------------------------------

  void _consumir(Stream<AssistantEvent> eventos) {
    setState(() {
      _enviando = true;
      _estado = 'Pensando...';
    });
    _alFinal();

    // La burbuja del bot se crea VACÍA con el primer fragmento y después se le
    // va concatenando el texto, así aparece de inmediato y crece.
    bool burbujaAbierta = false;

    _suscripcion?.cancel();
    _suscripcion = eventos.listen(
      (AssistantEvent evento) {
        if (!mounted) return;

        switch (evento.type) {
          case AssistantEventType.transcripcion:
            if (evento.text != null && evento.text!.isNotEmpty) {
              setState(() => _mensajes.last.texto = evento.text!);
            }

          case AssistantEventType.status:
            setState(() => _estado = evento.text ?? '');

          case AssistantEventType.delta:
            setState(() {
              if (!burbujaAbierta) {
                _mensajes.add(_Mensaje(esDelBot: true, texto: ''));
                burbujaAbierta = true;
                _estado = '';
              }
              _mensajes.last.texto += evento.text ?? '';
            });
            _alFinal();

          case AssistantEventType.error:
            // El error se muestra COMO UN MENSAJE del bot, no como un cartel
            // aparte: mantiene la conversación en un solo hilo.
            setState(() {
              final String aviso =
                  evento.text ?? 'No pude responder en este momento.';
              if (burbujaAbierta) {
                _mensajes.last.texto += '\n\n$aviso';
              } else {
                _mensajes.add(_Mensaje(esDelBot: true, texto: aviso));
              }
            });
            _alFinal();

          case AssistantEventType.session:
          case AssistantEventType.done:
            break;
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _enviando = false;
            _estado = '';
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _mensajes.add(
            _Mensaje(
              esDelBot: true,
              texto: 'No pude responder en este momento. Intenta de nuevo.',
            ),
          );
          _enviando = false;
          _estado = '';
        });
        _alFinal();
      },
    );
  }

  void _alFinal() {
    // Un frame para que el mensaje nuevo ya esté medido antes de desplazar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Asistente'),
            Text(
              'Médicos, turnos, sedes y precios',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              // Un lugar más al final para el indicador de carga.
              itemCount: _mensajes.length + (_estado.isNotEmpty ? 1 : 0),
              itemBuilder: (BuildContext context, int i) {
                if (i == _mensajes.length) {
                  return _Cargando(texto: _estado);
                }
                return _Burbuja(mensaje: _mensajes[i], tema: tema);
              },
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _grabando ? _barraGrabando(tema) : _barraEntrada(),
            ),
          ),
        ],
      ),
    );
  }

  /// Caja de texto + micrófono + enviar.
  Widget _barraEntrada() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _entrada,
            enabled: !_enviando,
            maxLength: 500,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _enviar(),
            decoration: const InputDecoration(
              hintText: '¿Qué doctores tienen?',
              counterText: '',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: _enviando ? null : _empezarAGrabar,
          icon: const Icon(Icons.mic_none_rounded, size: 20),
          tooltip: 'Grabar un audio',
        ),
        const SizedBox(width: 4),
        IconButton.filled(
          onPressed: _enviando ? null : _enviar,
          icon: const Icon(Icons.send_rounded, size: 20),
          tooltip: 'Enviar',
        ),
      ],
    );
  }

  /// Estado de grabación, con DOS botones a propósito: descartar y enviar.
  ///
  /// El de descartar va primero y en estilo neutro — el destructivo no debe ser
  /// el que queda cómodo bajo el pulgar.
  Widget _barraGrabando(ThemeData tema) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: tema.colorScheme.error),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.fiber_manual_record,
                  size: 12,
                  color: tema.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  _transcurrido,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grabando…',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: _descartarGrabacion,
          icon: const Icon(Icons.close_rounded, size: 20),
          tooltip: 'Descartar',
        ),
        const SizedBox(width: 4),
        IconButton.filled(
          onPressed: _terminarYEnviar,
          icon: const Icon(Icons.check_rounded, size: 20),
          tooltip: 'Enviar',
          style: IconButton.styleFrom(
            backgroundColor: tema.colorScheme.error,
            foregroundColor: tema.colorScheme.onError,
          ),
        ),
      ],
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje, required this.tema});

  final _Mensaje mensaje;
  final ThemeData tema;

  @override
  Widget build(BuildContext context) {
    final bool bot = mensaje.esDelBot;

    return Align(
      alignment: bot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bot
              ? tema.colorScheme.surfaceContainerHighest
              : tema.colorScheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(bot ? 4 : 16),
            bottomRight: Radius.circular(bot ? 16 : 4),
          ),
        ),
        child: Text(
          mensaje.texto,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: bot
                ? tema.colorScheme.onSurface
                : tema.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Indicador de carga que dice QUÉ se está consultando.
///
/// El texto lo manda el servidor, que es el que sabe qué herramienta está
/// usando el agente. Dejar al paciente mirando puntitos sin explicación es
/// peor que decirle "Consultando la agenda...".
class _Cargando extends StatelessWidget {
  const _Cargando({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tema.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              texto,
              style: TextStyle(
                fontSize: 11,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
