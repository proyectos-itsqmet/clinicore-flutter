package com.example.clinicore_flutter

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity, NOT FlutterActivity.
 *
 * This is a hard requirement of `local_auth`, not a preference. Android's
 * BiometricPrompt is a Fragment, so it needs a FragmentActivity host. With the
 * default `FlutterActivity`, the app compiles cleanly, installs cleanly, and
 * then throws `no_fragment_activity` the first time anyone taps "Ingresar con
 * huella" — a runtime failure that no amount of `flutter analyze` will catch.
 *
 * See https://pub.dev/packages/local_auth#android-integration
 *
 * The only cost is that this Activity is a FragmentActivity, which the Flutter
 * embedding supports as a first-class option.
 */
class MainActivity : FlutterFragmentActivity()
