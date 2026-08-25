import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/token_store.dart';
import '../../domain/entities/appointment.dart';
import '../models/turn_model.dart';

/// A live feed of the signed-in patient's OWN turn changes.
///
/// ## Why `stomp_dart_client`, and not a raw WebSocket
///
/// `WebSocketConfig.registerStompEndpoints` speaks STOMP framing
/// (CONNECT/SUBSCRIBE/MESSAGE) over a SockJS transport
/// (`.withSockJS()`) — a raw WebSocket client such as `web_socket_channel`
/// only moves bytes, it has no idea what a STOMP frame is, so every caller
/// would end up hand-rolling the protocol on top of it. `stomp_dart_client`
/// speaks STOMP AND the specific SockJS shape this server exposes:
/// `StompConfig.sockJS` builds the SockJS "websocket" transport URL
/// (`/ws-turns/{server}/{session}/websocket` — see `SockJsUtils
/// .generateTransportUrl`) and swaps the scheme to `ws`/`wss`. That
/// transport is a SINGLE WebSocket upgrade request with no `/info`
/// polling round-trip first, which matters here: Spring's SockJS handler
/// accepts the raw "websocket" transport directly unless it is explicitly
/// disabled, and `WebSocketConfig` never disables it — so there is exactly
/// one HTTP-level request to authenticate, not several.
///
/// ## Auth on the handshake — mirrors [AuthInterceptor], does not invent a
/// second mechanism
///
/// `GlobalConfig` gates `/ws-turns/**` behind `.authenticated()`, checked by
/// the SAME `JwtValidator` servlet filter that guards every REST call, and
/// `JwtValidator.recoverToken` reads the token from a `jwt` COOKIE, never
/// from `Authorization` — see `AuthInterceptor`'s own doc for the full
/// story. The WebSocket upgrade is a single HTTP request, and on a native
/// platform `stomp_dart_client` opens it with `dart:io`'s
/// `WebSocket.connect(url, headers: ...)` (see `connect_io.dart`), which —
/// unlike a browser's WebSocket API — accepts arbitrary headers on that
/// request. So [_connect] attaches the token exactly the way
/// [AuthInterceptor] does: `Cookie: jwt=<token>` for `JwtValidator` today,
/// plus `Authorization: Bearer <token>` for the day the server starts
/// reading it there too.
///
/// ## Resilience is the point, not a nicety
///
/// The package's own `reconnectDelay` is a FIXED delay, not backoff — see
/// `StompClient._scheduleReconnect`. It is turned OFF here
/// (`reconnectDelay: Duration.zero`) and replaced with exponential backoff
/// ([_scheduleReconnect]), because a phone that just walked into a
/// basement clinic should back off instead of hammering the server every
/// few seconds forever.
///
/// Just as important: [watchTurnUpdates] NEVER puts an error on the
/// returned stream. Every failure — a bad handshake, a dropped socket, a
/// push this app cannot parse — is swallowed here and answered with a
/// reconnect attempt, not a stream error. [AppointmentsBloc] already holds
/// the last REST-loaded list; a broken realtime feed should be invisible to
/// it, not a reason to show a broken screen. See the class-level note on
/// `AppointmentsRepository.watchTurnUpdates` for the rest of that
/// reasoning.
///
/// ## Lifecycle
///
/// The connection is opened lazily, the first time [watchTurnUpdates]
/// gets a listener, and closed the moment the LAST listener cancels — see
/// the `onListen` / `onCancel` callbacks on the broadcast controller this
/// class owns. [AppointmentsBloc] subscribes when it is constructed (which
/// only happens while the patient is authenticated and looking at an
/// appointments list) and cancels in `close()`, so signing out — which
/// disposes that bloc through the router's auth guard — tears this down
/// for free, with no imperative "on logout, disconnect the socket" code
/// anywhere.
abstract interface class TurnUpdatesRemoteDataSource {
  Stream<Appointment> watchTurnUpdates();
}

class TurnUpdatesRemoteDataSourceImpl implements TurnUpdatesRemoteDataSource {
  TurnUpdatesRemoteDataSourceImpl(this._tokenStore);

  final TokenStore _tokenStore;

  StreamController<Appointment>? _controller;
  StompClient? _client;
  StompUnsubscribe? _unsubscribe;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  /// Bumped on every connect/disconnect cycle. A callback captures the
  /// generation it was created for and no-ops if that generation is no
  /// longer current — without this, a previous socket that is slow to
  /// finish closing could schedule a reconnect (or tear down) for a
  /// DIFFERENT socket that has since taken its place, if the patient leaves
  /// and re-opens the appointments screen quickly enough for the two to
  /// overlap.
  int _generation = 0;

  static const Duration _initialBackoff = Duration(seconds: 2);
  static const Duration _maxBackoff = Duration(seconds: 30);

  @override
  Stream<Appointment> watchTurnUpdates() {
    return (_controller ??= StreamController<Appointment>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    )).stream;
  }

  Future<void> _connect() async {
    _reconnectTimer?.cancel();
    final int generation = ++_generation;

    final String? token = await _tokenStore.read();
    // Superseded while awaiting the token — e.g. the last listener cancelled
    // before this even reached the network. Do not open a socket nobody
    // asked for any more.
    if (generation != _generation) return;

    final Map<String, String> headers = _authHeaders(token);

    _client = StompClient(
      config: StompConfig.sockJS(
        url: '${AppConfig.apiBaseUrl}${ApiEndpoints.wsTurns}',
        webSocketConnectHeaders: headers,
        stompConnectHeaders: headers,
        // Backoff is handled by THIS class — see the class doc — so the
        // package's own fixed-delay reconnect is switched off rather than
        // left to race with it.
        reconnectDelay: Duration.zero,
        onConnect: (StompFrame _) => _onConnected(generation),
        onWebSocketError: (dynamic _) => _scheduleReconnect(generation),
        onStompError: (StompFrame _) => _scheduleReconnect(generation),
        onWebSocketDone: () => _scheduleReconnect(generation),
      ),
    )..activate();
  }

  Map<String, String> _authHeaders(String? token) {
    if (token == null || token.isEmpty) return const <String, String>{};
    return <String, String>{
      'Authorization': 'Bearer $token',
      'Cookie': 'jwt=$token',
    };
  }

  void _onConnected(int generation) {
    if (generation != _generation) return;
    _reconnectAttempt = 0;
    _unsubscribe = _client?.subscribe(
      destination: ApiEndpoints.turnUpdatesDestination,
      callback: _onMessage,
    );
  }

  void _onMessage(StompFrame frame) {
    final String? body = frame.body;
    final StreamController<Appointment>? controller = _controller;
    if (body == null || controller == null || controller.isClosed) return;

    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map) return;
      final Appointment appointment = TurnModel.fromJson(
        Map<String, dynamic>.from(decoded),
      ).toEntity();
      controller.add(appointment);
    } catch (_) {
      // A push this app cannot parse is dropped, not crashed on — the next
      // parseable push (or the next pull-to-refresh) still gets through.
    }
  }

  void _scheduleReconnect(int generation) {
    if (generation != _generation) return;
    // Nobody is listening any more — [_disconnect] already ran for this
    // generation change, or is about to. Do not reconnect a socket with no
    // audience.
    if (_controller?.hasListener != true) return;

    _reconnectTimer?.cancel();
    final Duration backoff = _nextBackoff();
    _reconnectTimer = Timer(backoff, _connect);
  }

  Duration _nextBackoff() {
    // Doubles each attempt (2s, 4s, 8s, 16s, ...), capped so a long outage
    // still retries roughly every 30s instead of trailing off forever.
    final int shift = _reconnectAttempt.clamp(0, 4);
    _reconnectAttempt++;
    final Duration delay = _initialBackoff * (1 << shift);
    return delay > _maxBackoff ? _maxBackoff : delay;
  }

  void _disconnect() {
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _unsubscribe?.call();
    _unsubscribe = null;
    _client?.deactivate();
    _client = null;
  }
}
