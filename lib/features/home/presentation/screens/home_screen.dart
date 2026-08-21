import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/organisms/organisms.dart';

/// The app shell: the four tabs and the bar that switches them.
///
/// It holds a [StatefulNavigationShell], so each tab keeps its own navigation
/// stack and its own scroll position. Switching away from a half-filled
/// booking form and back does not reset it — which is the whole reason to use
/// the stateful variant instead of rebuilding the branch on every tap.
///
/// ## Why `extendBody` is on
///
/// The navigation bar is translucent white with a 16px backdrop blur, copied
/// from the mobile board's `.actionbar`. A blur over an opaque background is
/// wasted work — there is nothing behind it to blur. With `extendBody: true`
/// the tab content scrolls UNDER the bar, so the blur does what it was drawn
/// to do.
///
/// That trade has to be paid for: content would otherwise end up permanently
/// hidden behind the bar. It is paid in the tabs, and Flutter makes it easy —
/// with `extendBody: true` a [Scaffold] reports the bar's height to its body
/// through `MediaQuery.padding.bottom`, so a tab that ends its scroll padding
/// with `context.bottomSafeInset` clears the bar exactly, with no shared
/// constant to keep in sync.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// The four destinations, in the order the user's day runs: book something,
  /// check what is booked, look back at what happened, then account settings.
  static const List<AppNavItem> tabs = <AppNavItem>[
    AppNavItem(label: 'Agendar', icon: AppIcons.booking),
    AppNavItem(label: 'Mis citas', icon: AppIcons.appointments),
    AppNavItem(label: 'Historial', icon: AppIcons.history),
    AppNavItem(label: 'Mi perfil', icon: AppIcons.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.field,
      extendBody: true,
      body: shell,
      bottomNavigationBar: AppBottomNav(
        items: tabs,
        currentIndex: shell.currentIndex,
        onSelected: (index) => shell.goBranch(
          index,
          // Tapping the tab you are already on returns it to its root, which
          // is what every native tab bar does and what people expect when
          // they are three screens deep and want out.
          initialLocation: index == shell.currentIndex,
        ),
      ),
    );
  }
}
