import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';

/// Qué está pasando en la conversación, tal como lo informa el servicio de IA.
enum AssistantEventType {
  /// El id de conversación que asignó el servidor.
  session,

  /// Lo que el paciente dijo en un audio, ya pasado a texto.
  transcripcion,

  /// Lo que el asistente está haciendo ("Consultando la agenda...").
  status,

  /// Un fragmento de la respuesta, apenas llega.
  delta,

  /// La respuesta terminada.
  done,

  /// Algo falló.
  error,
}

class AssistantEvent {
  const AssistantEvent(this.type, {this.text, this.sessionId});

  final AssistantEventType type;
  final String? text;
  final String? sessionId;
}

/// El asistente virtual de pacientes.
///
/// Habla con `clinicore-ai`, el servicio Python que tiene el agente. No pasa
/// por el backend Spring: es otro proceso, en otro puerto (ver
/// [AppConfig.aiBaseUrl]).
///
/// POR QUÉ STREAMING
///
/// El servicio responde con Server-Sent Events y hay que leer el cuerpo
/// MIENTRAS llega, para que la respuesta se escriba de a poco en pantalla en
/// lugar de aparecer entera al final. Con Dio eso se pide con
/// `ResponseType.stream`, que en vez del cuerpo ya parseado entrega un
/// [ResponseBody] con el stream de bytes crudo.
class AssistantService {
  AssistantService({Dio? dio}) : _dio = dio ?? _crearDio();

  final Dio _dio;

  /// Un Dio propio, no el del QMS.
  ///
  /// El cliente compartido apunta a Spring y lleva el interceptor que agrega
  /// el token del paciente. Acá los dos estorban: la URL es otra, y este chat
  /// es anónimo a propósito — no debe viajar ninguna credencial.
  static Dio _crearDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.aiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.aiReceiveTimeout,
      ),
    );
  }

  /// Envía un mensaje de texto y va entregando los eventos a medida que llegan.
  Stream<AssistantEvent> chat({
    required String sessionId,
    required String mensaje,
  }) async* {
    try {
      final Response<ResponseBody> respuesta = await _dio.post<ResponseBody>(
        '/chat',
        data: <String, String>{'session_id': sessionId, 'mensaje': mensaje},
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, String>{'Content-Type': 'application/json'},
        ),
      );

      final ResponseBody? cuerpo = respuesta.data;
      if (cuerpo == null) {
        yield const AssistantEvent(
          AssistantEventType.error,
          text: 'El asistente no devolvió respuesta.',
        );
        return;
      }

      yield* _leerEventos(cuerpo);
    } on DioException catch (e) {
      yield AssistantEvent(AssistantEventType.error, text: _mensajeDeError(e));
    } catch (_) {
      yield const AssistantEvent(
        AssistantEventType.error,
        text: 'No pude conectarme con el asistente.',
      );
    }
  }

  /// Envía un audio grabado. El servicio lo transcribe y responde por el mismo
  /// canal, así que el audio NO cambia el asistente: es una capa de traducción
  /// en la entrada.
  ///
  /// [rutaArchivo] es el archivo que dejó el grabador en disco.
  Stream<AssistantEvent> chatAudio({
    required String sessionId,
    required String rutaArchivo,
  }) async* {
    try {
      final FormData cuerpoEnvio = FormData.fromMap(<String, dynamic>{
        // El campo se llama "file" porque así lo espera el servicio Python.
        'file': await MultipartFile.fromFile(rutaArchivo),
        'session_id': sessionId,
      });

      final Response<ResponseBody> respuesta = await _dio.post<ResponseBody>(
        '/chat/audio',
        data: cuerpoEnvio,
        options: Options(responseType: ResponseType.stream),
      );

      final ResponseBody? cuerpo = respuesta.data;
      if (cuerpo == null) {
        yield const AssistantEvent(
          AssistantEventType.error,
          text: 'El asistente no devolvió respuesta.',
        );
        return;
      }

      yield* _leerEventos(cuerpo);
    } on DioException catch (e) {
      yield AssistantEvent(AssistantEventType.error, text: _mensajeDeError(e));
    } catch (_) {
      yield const AssistantEvent(
        AssistantEventType.error,
        text: 'No pude enviar el audio.',
      );
    }
  }

  /// Recorre el stream de bytes y va entregando los eventos SSE completos.
  ///
  /// Cada evento llega así:
  ///
  ///     event: delta
  ///     data: {"texto":"Hola"}
  ///
  /// separados por una línea en blanco. Un fragmento del stream puede cortar
  /// un evento por la mitad, así que se acumula en [pendiente] y solo se
  /// procesa lo que ya está completo.
  Stream<AssistantEvent> _leerEventos(ResponseBody cuerpo) async* {
    String pendiente = '';

    await for (final List<int> trozo in cuerpo.stream) {
      pendiente += utf8.decode(trozo, allowMalformed: true);

      final List<String> bloques = pendiente.split('\n\n');
      // El último puede estar cortado: se guarda para la próxima vuelta.
      pendiente = bloques.removeLast();

      for (final String bloque in bloques) {
        final AssistantEvent? evento = _parsear(bloque);
        if (evento != null) yield evento;
      }
    }

    final AssistantEvent? ultimo = _parsear(pendiente);
    if (ultimo != null) yield ultimo;
  }

  AssistantEvent? _parsear(String bloque) {
    String tipo = '';
    String datos = '';

    for (final String linea in bloque.split('\n')) {
      if (linea.startsWith('event:')) {
        tipo = linea.substring(6).trim();
      } else if (linea.startsWith('data:')) {
        datos += linea.substring(5).trim();
      }
    }

    if (tipo.isEmpty || datos.isEmpty) return null;

    try {
      final Map<String, dynamic> cuerpo =
          jsonDecode(datos) as Map<String, dynamic>;

      final String? texto = (cuerpo['texto'] ?? cuerpo['mensaje']) as String?;
      final String? sessionId = cuerpo['session_id'] as String?;

      return switch (tipo) {
        'session' => AssistantEvent(
          AssistantEventType.session,
          sessionId: sessionId,
        ),
        'transcripcion' => AssistantEvent(
          AssistantEventType.transcripcion,
          text: texto,
        ),
        'status' => AssistantEvent(AssistantEventType.status, text: texto),
        'delta' => AssistantEvent(AssistantEventType.delta, text: texto),
        'done' => AssistantEvent(AssistantEventType.done, text: texto),
        'error' => AssistantEvent(AssistantEventType.error, text: texto),
        _ => null,
      };
    } catch (_) {
      // Un bloque mal formado no debe cortar la conversación entera.
      return null;
    }
  }

  /// Traduce el error de red a algo que un paciente pueda leer.
  ///
  /// El caso más frecuente en desarrollo es que el servicio Python no esté
  /// levantado, o que en el emulador Android se haya apuntado a `localhost` en
  /// lugar de `10.0.2.2`. Los dos dan `connectionError` y los dos se leen como
  /// "el asistente está caído", así que el mensaje lo dice.
  String _mensajeDeError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout =>
        'No pude conectarme con el asistente. Verifica que el servicio esté '
            'activo.',
      DioExceptionType.receiveTimeout =>
        'El asistente tardó demasiado en responder. Intenta de nuevo.',
      _ => 'No pude responder en este momento. Intenta de nuevo.',
    };
  }
}
