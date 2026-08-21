import 'package:clinicore_flutter/core/theme/theme.dart';
import 'package:clinicore_flutter/shared/ui/atoms/atoms.dart';
import 'package:clinicore_flutter/shared/ui/molecules/molecules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget in just enough app to render.
///
/// NOTE for anyone adding tests here: several atoms run INFINITE animations
/// by design — [AppBeam]'s 2.8s sweep, [AppLiveDot]'s 2s pulse,
/// [AppSkeleton]'s shimmer. `pumpAndSettle` never returns on a tree that
/// contains one of them, so these tests use `pump(duration)` throughout. That
/// is not a workaround for a bug; it is the correct way to test a widget that
/// is supposed to keep moving.
Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('renders its label and fires its callback', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Ingresar', onPressed: () => taps++)),
      );

      expect(find.text('Ingresar'), findsOneWidget);

      await tester.tap(find.text('Ingresar'));
      await tester.pump(AppMotion.press);

      expect(taps, 1);
    });

    testWidgets('a null callback disables it', (tester) async {
      await tester.pumpWidget(_host(const AppButton(label: 'Ingresar')));

      // The Angular atom's `disabled:opacity-50`, which is what this state
      // actually looks like.
      final Opacity opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byType(AnimatedContainer),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
    });

    testWidgets('while loading it swaps the label for a spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AppButton(label: 'Ingresar', isLoading: true, onPressed: () {})),
      );
      await tester.pump(AppMotion.press);

      expect(find.text('Ingresar'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the WhatsApp variant labels in ink, never in white', (
      tester,
    ) async {
      // White on #25D366 measures 2.4:1 and fails; ink measures 7.83:1. This
      // is the one button pairing in the system that is easy to get wrong, so
      // it is pinned by a test.
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'WhatsApp',
            variant: AppButtonVariant.whatsapp,
            onPressed: () {},
          ),
        ),
      );

      final Text label = tester.widget<Text>(find.text('WhatsApp'));
      expect(label.style?.color, AppColors.ink);
    });
  });

  group('AppChip', () {
    testWidgets('morphs from a 16px rectangle to a pill on selection', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppChip(label: '09:00')));
      await tester.pump();

      BoxDecoration decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(decoration.borderRadius, AppRadii.tileLgAll);
      expect(decoration.color, AppColors.surface);

      await tester.pumpWidget(
        _host(const AppChip(label: '09:00', selected: true)),
      );
      // Past the 300ms morph.
      await tester.pump(AppMotion.morph + const Duration(milliseconds: 50));

      decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(decoration.borderRadius, AppRadii.pillAll);
      expect(decoration.color, AppColors.blue);
    });

    testWidgets('a taken slot keeps its label and strikes it through', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AppChip(label: '08:40', disabled: true)),
      );
      await tester.pump();

      expect(find.text('08:40'), findsOneWidget);

      // Scoped to the chip: MaterialApp puts its own
      // AnimatedDefaultTextStyle in the tree, so an unscoped finder matches
      // more than one.
      final AnimatedDefaultTextStyle styled = tester
          .widget<AnimatedDefaultTextStyle>(
            find.descendant(
              of: find.byType(AppChip),
              matching: find.byType(AnimatedDefaultTextStyle),
            ),
          );
      expect(styled.style.decoration, TextDecoration.lineThrough);
    });

    testWidgets('a disabled chip does not fire', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(AppChip(label: '08:40', disabled: true, onTap: () => taps++)),
      );

      await tester.tap(find.text('08:40'), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('AppCard', () {
    testWidgets('carries the signature 24/24/8/24 corner', (tester) async {
      await tester.pumpWidget(_host(const AppCard(child: Text('contenido'))));
      await tester.pump();

      final BoxDecoration decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;

      expect(decoration.borderRadius, AppRadii.signature);
      // The shape the whole brand is built on: three corners at 24, the
      // bottom-right pinched to 8.
      final BorderRadius radius = decoration.borderRadius! as BorderRadius;
      expect(radius.topLeft.x, 24);
      expect(radius.topRight.x, 24);
      expect(radius.bottomLeft.x, 24);
      expect(radius.bottomRight.x, 8);
    });

    testWidgets('the emergency tone flips its ink to white', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppCard(tone: AppCardTone.emergency, child: Text('Emergencia')),
        ),
      );
      await tester.pump();

      final DefaultTextStyle style = DefaultTextStyle.of(
        tester.element(find.text('Emergencia')),
      );
      expect(style.style.color, AppColors.surface);
    });
  });

  group('AppSegmented', () {
    testWidgets('reports the tapped index and moves the thumb', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (context, setState) => AppSegmented(
                options: const <String>['Consulta', 'Control', 'Tele'],
                selectedIndex: selected,
                onChanged: (index) => setState(() => selected = index),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final double before = tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .left!;

      await tester.tap(find.text('Control'));
      await tester.pump(AppMotion.morph + const Duration(milliseconds: 50));

      expect(selected, 1);
      expect(
        tester
            .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
            .left!,
        greaterThan(before),
      );
    });

    testWidgets('narrow parents fall back to scrolling, not clipping', (
      tester,
    ) async {
      // 3 * 116 + 8 = 356, so 300 cannot fit the mobile board's tracks.
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: AppSegmented(
              options: const <String>['Consulta', 'Control', 'Telemedicina'],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppDayChip', () {
    testWidgets('keeps its 16px radius when selected', (tester) async {
      // Unlike AppChip: a two-line square becoming a pill would squash, so
      // the selection is carried by the fill alone.
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 80,
            child: AppDayChip(weekday: 'Mie', day: '12', selected: true),
          ),
        ),
      );
      await tester.pump();

      final BoxDecoration decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;

      expect(decoration.borderRadius, AppRadii.tileLgAll);
      expect(decoration.color, AppColors.blue);
    });
  });

  group('AppTick', () {
    testWidgets('draws itself after the 120ms delay and does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppTick()));

      // Before the delay elapses there is nothing to see, and that is correct.
      await tester.pump(const Duration(milliseconds: 50));
      // Through the delay and the whole 340ms draw.
      await tester.pump(AppMotion.tickDrawDelay);
      await tester.pump(AppMotion.tickDraw);

      expect(find.byType(AppTick), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
