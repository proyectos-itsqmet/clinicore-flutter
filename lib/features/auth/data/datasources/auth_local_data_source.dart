import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/token_store.dart';
import '../models/auth_response_model.dart';

/// The session as it is kept on this device.
///
/// The token and the profile are stored separately but always read together,
/// and [AuthLocalDataSource.readSession] returns null unless BOTH are
/// present. That rule matters more than it looks: the registration flow parks
/// a 300-second flash token in the same slot, and without this check an
/// abandoned sign-up would leave the app looking logged in with no user
/// behind it — and every request 401ing five minutes later.
class StoredSession {
  const StoredSession({required this.token, required this.user});

  final String token;
  final AuthResponseModel user;
}

abstract interface class AuthLocalDataSource {
  Future<void> saveSession({
    required String token,
    required AuthResponseModel user,
  });

  /// Stores a token with no profile — the registration flash token.
  Future<void> saveTokenOnly(String token);

  Future<StoredSession?> readSession();

  Future<String?> readToken();

  Future<void> clear();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  const AuthLocalDataSourceImpl({
    required this.tokenStore,
    required this.storage,
  });

  // Public finals rather than private fields with a `_x = x` initialiser.
  // Dart forbids a named parameter that starts with an underscore, so a
  // private field can only be filled through that indirection — which the
  // `prefer_initializing_formals` lint then flags. Public finals on an
  // injected dependency are read-only, idiomatic, and lint-clean.
  final TokenStore tokenStore;
  final FlutterSecureStorage storage;

  /// The cached profile. In secure storage rather than SharedPreferences
  /// because a patient's name and email are personal data, and this app is
  /// bound by the same duty of care as the clinic that ships it.
  static const String _userKey = 'clinicore.session.user.v1';

  @override
  Future<void> saveSession({
    required String token,
    required AuthResponseModel user,
  }) async {
    try {
      await tokenStore.write(token);
      await storage.write(
        key: _userKey,
        value: jsonEncode(<String, dynamic>{
          'email': user.email,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'role': user.role,
        }),
        iOptions: SecureTokenStore.iosOptions,
      );
    } catch (error) {
      throw CacheException(message: 'No pudimos guardar la sesion: $error');
    }
  }

  @override
  Future<void> saveTokenOnly(String token) async {
    try {
      await tokenStore.write(token);
    } catch (error) {
      throw CacheException(message: 'No pudimos guardar la sesion: $error');
    }
  }

  @override
  Future<StoredSession?> readSession() async {
    try {
      final String? token = await tokenStore.read();
      if (token == null || token.isEmpty) return null;

      final String? raw = await storage.read(
        key: _userKey,
        iOptions: SecureTokenStore.iosOptions,
      );
      if (raw == null || raw.isEmpty) return null;

      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      return StoredSession(
        token: token,
        user: AuthResponseModel.fromJson(decoded),
      );
    } on FormatException {
      // A profile we cannot parse is a profile from an older app version.
      // Dropping it is right; crashing on launch is not.
      await clear();
      return null;
    } catch (error) {
      throw CacheException(message: 'No pudimos leer la sesion: $error');
    }
  }

  @override
  Future<String?> readToken() async {
    try {
      return await tokenStore.read();
    } catch (error) {
      throw CacheException(message: 'No pudimos leer la sesion: $error');
    }
  }

  @override
  Future<void> clear() async {
    // Deliberately NOT wrapped in a throwing catch: sign-out must always
    // succeed from the user's point of view. If the keychain refuses to
    // delete, the worst outcome is a stale token, and leaving the patient
    // stuck on a screen that will not log them out is worse.
    try {
      await tokenStore.clear();
      await storage.delete(
        key: _userKey,
        iOptions: SecureTokenStore.iosOptions,
      );
    } catch (_) {
      // Swallowed on purpose. See above.
    }
  }
}
