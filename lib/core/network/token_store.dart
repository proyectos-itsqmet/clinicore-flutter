import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session token lives.
///
/// This is an interface rather than a concrete class for one structural
/// reason: `AuthInterceptor` needs to read the token on every request, and
/// `core/` must not import from `features/`. Both the interceptor and the auth
/// feature depend on this abstraction instead, so the dependency arrow keeps
/// pointing inwards.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// The real one: Keychain on iOS, Keystore-backed ciphers on Android.
///
/// A JWT is a bearer credential — whoever holds it IS the patient until it
/// expires — so it does not go in SharedPreferences, which is a
/// world-readable XML file on a rooted device.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  /// Bumping this key logs everyone out, which is the correct behaviour if the
  /// token's shape ever changes.
  static const String _key = 'clinicore.session.jwt.v1';

  /// No `AndroidOptions` on purpose.
  ///
  /// The usual advice is to pass `AndroidOptions(encryptedSharedPreferences:
  /// true)`, and that advice is now out of date: Google deprecated the Jetpack
  /// Security library, so `flutter_secure_storage` deprecated the flag too. In
  /// this version it is ignored, existing data is migrated to custom ciphers on
  /// first access, and the parameter disappears in v11. Passing it would be a
  /// deprecation warning that buys nothing.
  ///
  /// `first_unlock_this_device` on iOS is still worth setting explicitly:
  /// readable after the first unlock following a reboot, and never synced to
  /// iCloud or restored onto a different device. A session token that survives
  /// a device migration is a session token that outlived its owner's phone.
  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<String?> read() => _storage.read(key: _key, iOptions: iosOptions);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _key, value: token, iOptions: iosOptions);

  @override
  Future<void> clear() => _storage.delete(key: _key, iOptions: iosOptions);
}
