import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration, read once from `.env`.
///
/// Everything the app needs from the environment is named here, so a missing
/// key fails in one place with a message that says which key — instead of
/// surfacing three screens later as a connection error nobody can explain.
abstract final class AppConfig {
  /// Base URL of the QMS API, WITHOUT a trailing slash.
  ///
  /// The Spring Boot service listens on **8080** with no context path
  /// (`server.port=8080` in `application.properties`), so the endpoints sit
  /// directly under the host: `http://host:8080/auth/mobile/login-patient`.
  static String get apiBaseUrl {
    final String? configured = dotenv.maybeGet('API_BASE_URL');
    if (configured != null && configured.isNotEmpty) {
      return _stripTrailingSlash(configured);
    }
    return _developmentFallback;
  }

  /// Where to look when `.env` says nothing.
  ///
  /// This is worth reading before changing it. On an **Android emulator**,
  /// `localhost` is the emulator itself, not the developer's machine — the
  /// host loopback is `10.0.2.2`. Defaulting to `localhost` there is the
  /// single most common "why can't the app reach my backend" and it always
  /// looks like a server problem.
  ///
  /// The iOS simulator shares the host's network stack, so `localhost` is
  /// correct there.
  static String get _developmentFallback {
    if (kIsWeb) return 'http://localhost:8080';
    return Platform.isAndroid
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }

  /// Base URL of the AI assistant service (`clinicore-ai`), WITHOUT a trailing
  /// slash.
  ///
  /// It is a SEPARATE process from the QMS API: a Flask service on port 8000
  /// that holds the agent, its OpenAI calls and its tools. That is why it does
  /// not reuse [apiBaseUrl] — pointing the assistant at 8080 lands on Spring,
  /// which has no `/chat`.
  ///
  /// The same emulator caveat as [apiBaseUrl] applies, and it bites harder here
  /// because the failure looks like the assistant being down.
  static String get aiBaseUrl {
    final String? configured = dotenv.maybeGet('AI_BASE_URL');
    if (configured != null && configured.isNotEmpty) {
      return _stripTrailingSlash(configured);
    }
    if (kIsWeb) return 'http://localhost:8000';
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';
  }

  /// Connection and response timeouts. Generous rather than tight: the app is
  /// used inside clinics, and hospital wifi is not a fast network.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Response timeout for the assistant.
  ///
  /// Longer than [receiveTimeout] on purpose. The assistant streams: the
  /// connection stays open while the model writes, and a reply that consults
  /// the agenda first can take well over 20 seconds end to end. With the
  /// regular timeout the stream is cut mid-sentence and it reads as a crash.
  static const Duration aiReceiveTimeout = Duration(seconds: 90);

  /// Whether to log requests. Off in release, always — the auth endpoints
  /// carry passwords and tokens in their bodies and headers.
  static bool get enableNetworkLogs => kDebugMode;

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
