import 'package:clinicore_flutter/app.dart';
import 'package:clinicore_flutter/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app is portrait-only. Not a limitation to lift later: the design
  // system was drawn at 390px wide and its type scale, gutters and grids are
  // that width's. A landscape phone would need its own scale, which is exactly
  // the difference between `design/Main.dc.html` and `design/Mobile.dc.html`.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge to edge, so the bottom navigation's translucent blur actually has the
  // gesture area behind it to blur, and the auth hero can bleed under the
  // status bar as the boards draw it.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Default chrome: dark glyphs, for the `field` ground every screen but the
  // auth hero and the splash sits on. Those two override it for themselves.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Tolerated rather than required. A missing `.env` is a development
  // annoyance, not a reason to refuse to start: `AppConfig` falls back to the
  // local backend, and on Android that fallback is `10.0.2.2` rather than
  // `localhost` — which is the one detail that makes an emulator reach the
  // developer's machine at all.
  try {
    await dotenv.load(fileName: '.env.app_dev');
  } catch (_) {
    debugPrint('No se pudo leer .env.app_dev; se usa la configuracion por defecto.');
  }

  // Before runApp, because the app's first widget resolves the stored session
  // through the locator.
  await configureDependencies();

  runApp(const MainApp());
}
