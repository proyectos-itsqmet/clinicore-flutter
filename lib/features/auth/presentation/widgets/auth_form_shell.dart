import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/ui/organisms/organisms.dart';

/// The layout every auth screen shares: the dark hero on top, a scrolling
/// form under it on the `field` ground.
///
/// All five auth screens are the same shape — a heading, some fields, one
/// primary action, and a way out — so the shape lives here once. What each
/// screen supplies is its copy, its fields and its callbacks. If a screen
/// needs to change this layout, that is a signal the layout is wrong for all
/// of them, not that this one deserves an exception.
///
/// The form is NOT inside a card, and that is deliberate. The web app wraps
/// its booking form in a white panel because that form is a widget embedded
/// in a marketing page — it has to announce itself as interactive. Here the
/// form IS the page, so it sits directly on the page ground, which is what
/// the boards do with every other section's content.
class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.title,
    required this.children,
    this.kicker,
    this.subtitle,
    this.footer,
    this.onBack,
  });

  final String title;
  final String? kicker;
  final String? subtitle;

  /// Fields and actions, spaced at [AppSpacing.section] — the boards' own
  /// gap between the items of a content column.
  final List<Widget> children;

  /// The way out: "ya tengo cuenta", "volver al inicio". Scrolls with the
  /// form rather than pinning, so the keyboard never covers it and never
  /// fights it for the bottom of the screen.
  final Widget? footer;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.field,
      body: Column(
        children: <Widget>[
          AppAuthHero(
            title: title,
            kicker: kicker,
            subtitle: subtitle,
            onBack: onBack,
            // The hero gives its height back to the form the moment the
            // keyboard appears.
            collapsed: context.isKeyboardOpen,
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: AppSpacing.pad,
                right: AppSpacing.pad,
                top: AppSpacing.sectionY * 0.6,
                bottom: AppSpacing.sectionY * 0.6 + context.bottomSafeInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.section,
                children: <Widget>[
                  ...children,
                  if (footer != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "or do this instead" line at the bottom of an auth screen: a sentence
/// with one tappable word.
///
/// A whole `AppButton` would compete with the screen's primary action, and a
/// bare blue word with no explanation is a guess. This is the middle: `cap`
/// text in `ink-3`, the action in `blue-text` at 700, and a 44px-tall touch
/// target around it even though the text is 13px.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: '$message $actionLabel',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
            child: Center(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: '$message ', style: AppTypography.cap),
                    TextSpan(
                      text: actionLabel,
                      style: AppTypography.cap.copyWith(
                        color: AppColors.blueText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
