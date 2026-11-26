import 'package:fit_scale/fit_scale.dart';
import 'package:fit_scale/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FitScaleData data(double width,
        [double height = 800,
        FitScaleConfig config = const FitScaleConfig()]) =>
    FitScaleData(config: config, size: Size(width, height));

Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    );

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('window class boundaries (Material 3)', () {
    for (final (width, expected) in [
      (599.0, FitWindowClass.compact),
      (600.0, FitWindowClass.medium),
      (839.0, FitWindowClass.medium),
      (840.0, FitWindowClass.expanded),
      (1199.0, FitWindowClass.expanded),
      (1200.0, FitWindowClass.large),
      (1599.0, FitWindowClass.large),
      (1600.0, FitWindowClass.extraLarge),
    ]) {
      test('$width -> ${expected.name}', () {
        expect(data(width).windowClass, expected);
      });
    }
  });

  test('height classes split landscape phones from tablets', () {
    expect(data(874, 402).windowClass, FitWindowClass.expanded);
    expect(data(874, 402).heightClass, FitHeightClass.compact);
    expect(data(744, 1133).heightClass, FitHeightClass.expanded);
    expect(data(400, 600).heightClass, FitHeightClass.medium);
  });

  test('the shipped devices land in the classes they are named for', () {
    FitWindowClass cls(FitDevice d) =>
        data(d.size.width, d.size.height).windowClass;
    for (final d in [...FitDevices.small, ...FitDevices.phones]) {
      expect(cls(d), FitWindowClass.compact, reason: d.name);
    }
    expect(cls(FitDevices.foldOpen), FitWindowClass.medium);
    expect(cls(FitDevices.ipadMini), FitWindowClass.medium);
    expect(cls(FitDevices.ipadPro13), FitWindowClass.expanded);
    expect(cls(FitDevices.phoneLandscape), FitWindowClass.expanded);
  });

  test('custom breakpoints', () {
    const config = FitScaleConfig(
      breakpoints: FitBreakpoints(medium: 500, expanded: 700),
    );
    expect(data(550, 800, config).windowClass, FitWindowClass.medium);
    expect(data(700, 800, config).windowClass, FitWindowClass.expanded);
  });

  test('isAtLeast', () {
    expect(FitWindowClass.expanded.isAtLeast(FitWindowClass.medium), isTrue);
    expect(FitWindowClass.compact.isAtLeast(FitWindowClass.medium), isFalse);
    expect(FitHeightClass.medium.isAtLeast(FitHeightClass.medium), isTrue);
  });

  group('when and pick', () {
    test('fall back to the nearest narrower class', () {
      final calls = <String>[];
      String run(double w) => data(w).when(
            compact: () {
              calls.add('c');
              return 'c';
            },
            expanded: () {
              calls.add('e');
              return 'e';
            },
          );
      expect(run(400), 'c');
      expect(run(700), 'c'); // medium missing -> compact
      expect(run(900), 'e');
      expect(run(1700), 'e'); // large, extraLarge missing -> expanded
      expect(calls, ['c', 'c', 'e', 'e'], reason: 'only the chosen runs');
    });

    test('pick', () {
      int columns(double w) => data(w).pick(compact: 1, medium: 2, expanded: 3);
      expect([columns(400), columns(700), columns(1000), columns(1300)],
          [1, 2, 3, 3]);
    });
  });

  group('FitLayout', () {
    testWidgets('builds the layout for the class', (tester) async {
      setScreen(tester, const Size(400, 800));
      await tester.pumpWidget(host(FitScaleScope(
        child: FitLayout(
          compact: (_) => const Text('one column'),
          medium: (_) => const Text('two columns'),
        ),
      )));
      expect(find.text('one column'), findsOneWidget);

      tester.view.physicalSize = const Size(744, 1133);
      await tester.pump();
      expect(find.text('two columns'), findsOneWidget);

      tester.view.physicalSize = const Size(1032, 1376);
      await tester.pump();
      expect(find.text('two columns'), findsOneWidget,
          reason: 'expanded falls back to medium');
    });

    testWidgets('rebuilds only when the class changes', (tester) async {
      setScreen(tester, const Size(400, 800));
      var builds = 0;
      await tester.pumpWidget(host(FitScaleScope(
        child: FitLayout(
          compact: (_) {
            builds++;
            return const SizedBox();
          },
        ),
      )));
      expect(builds, 1);

      // Same class, different size: no rebuild.
      tester.view.physicalSize = const Size(420, 820);
      await tester.pump();
      expect(builds, 1);

      // Height class changes (820 -> 400): rebuild.
      tester.view.physicalSize = const Size(420, 400);
      await tester.pump();
      expect(builds, 2);
    });

    testWidgets('follows the pane inside a layout scope', (tester) async {
      setScreen(tester, const Size(1032, 1376)); // expanded screen
      await tester.pumpWidget(host(FitScaleScope(
        child: Row(children: [
          const SizedBox(width: 600),
          Expanded(
            child: FitScaleScope(
              useLayoutSize: true,
              child: FitLayout(
                compact: (_) => const Text('pane is compact'),
                expanded: (_) => const Text('pane is expanded'),
              ),
            ),
          ),
        ]),
      )));
      expect(find.text('pane is compact'), findsOneWidget); // 432 wide
    });
  });

  test('FitDevices.all covers every class the defaults use', () {
    final classes = {
      for (final d in FitDevices.all)
        data(d.size.width, d.size.height).windowClass,
    };
    expect(classes, {
      FitWindowClass.compact,
      FitWindowClass.medium,
      FitWindowClass.expanded,
    });
    expect(FitDevices.all, hasLength(11));
  });
}
