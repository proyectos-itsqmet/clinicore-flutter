import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/atoms/atoms.dart';

/// What the app shows while it reads the stored session.
///
/// It is deliberately almost nothing: the brand mark on the anchor colour and
/// a live dot. A spinner would promise a wait, and this resolves in the time
/// it takes to read one keychain entry — usually a single frame. What it
/// prevents is the alternative, where a returning patient sees the login form
/// flash before being thrown into the app.
///
/// Nothing here dispatches or navigates. `AuthStarted` is fired once when the
/// app is built, and the router's redirect moves off this screen the moment
/// the session resolves. A splash that owns its own timer is a splash that
/// eventually races the thing it is waiting for.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: const Scaffold(
        backgroundColor: AppColors.navyDeep,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.section,
            children: <Widget>[
              AppBrandMark(size: 56),
              Text(
                'CliniCore',
                style: TextStyle(
                  fontFamily: AppTypography.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.308, // -.014em x 22
                  color: AppColors.surface,
                ),
              ),
              AppLiveDot(),
            ],
          ),
        ),
      ),
    );
  }
}
