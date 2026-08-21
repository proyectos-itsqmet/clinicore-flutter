import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import 'app_top_bar.dart';

/// The standard page shell: `field` ground, an optional [AppTopBar], and a
/// body that scrolls and is guttered at [AppSpacing.pad].
///
/// It exists so that no screen has to remember the page background, the 20px
/// gutter, or to keep its content clear of the keyboard. A screen that
/// assembles its own [Scaffold] is saying "my layout is genuinely different"
/// — the home shell does that, because it owns the bottom navigation, and
/// the auth screens do it, because their hero bleeds behind the status bar.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.child,
    this.topBar,
    this.scrollable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.pad),
    this.footer,
    this.background = AppColors.field,
  });

  final Widget child;
  final AppTopBar? topBar;

  /// Off for a screen that manages its own scrolling — a long list that needs
  /// a `ListView.builder` rather than a column in a scroll view.
  final bool scrollable;

  final EdgeInsetsGeometry padding;

  /// Pinned below the scrolling body, above the safe area — where a single
  /// submit action belongs so it stays reachable while the user reads.
  final Widget? footer;

  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding, child: child);

    if (scrollable) {
      body = SingleChildScrollView(
        // The keyboard can dismiss by dragging the content, which is the
        // gesture people already expect from every native form.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: topBar,
      body: SafeArea(
        top: topBar == null,
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(child: body),
            if (footer != null)
              Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.pad,
                  right: AppSpacing.pad,
                  top: AppSpacing.xxl,
                  bottom: AppSpacing.xxl + context.bottomSafeInset,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
