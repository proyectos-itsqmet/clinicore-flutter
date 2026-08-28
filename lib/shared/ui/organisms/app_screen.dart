import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import 'app_top_bar.dart';

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
  final bool scrollable;

  final EdgeInsetsGeometry padding;
  final Widget? footer;

  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding, child: child);

    if (scrollable) {
      body = SingleChildScrollView(
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
