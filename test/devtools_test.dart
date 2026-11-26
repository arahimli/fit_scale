import 'package:fit_scale/fit_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double drawn(WidgetTester tester, String text) {
  final p = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return p.textScaler.scale((p.text as TextSpan).style!.fontSize!);
}

/// Counts how often it is created, to prove state survives.
class _Counter extends StatefulWidget {
  const _Counter();
  static var created = 0;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    _Counter.created++;
  }

  @override
  Widget build(BuildContext context) =>
      const Text('Total', style: TextStyle(fontSize: 20));
}

void main() {
  tearDown(() {
    FitDevTools.textScale.value = null;
    FitDevTools.overlay.value = null;
    FitDevTools.problems = const [];
  });

  testWidgets('state reports size, class, factors and hinge', (tester) async {
    setScreen(tester, const Size(744, 1133));
    await tester.pumpWidget(const FitScaleScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(),
      ),
    ));
    final s = FitDevTools.handle('state', const {});
    expect(s['connected'], isTrue);
    expect(s['width'], 744);
    expect(s['windowClass'], 'medium');
    expect(s['fontScale'], 1.15);
    expect(s['hinge'], isNull);
    expect(s['forcedTextScale'], isNull);
  });

  testWidgets('without a scope, state says so', (tester) async {
    await tester.pumpWidget(const SizedBox());
    expect(FitDevTools.handle('state', const {})['connected'], isFalse);
  });

  testWidgets('setTextScale shows the app at another text size, keeping state',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    _Counter.created = 0;
    await tester.pumpWidget(const FitScaleScope(
      child: MaterialApp(home: Scaffold(body: _Counter())),
    ));
    expect(drawn(tester, 'Total'), 20);

    FitDevTools.handle('setTextScale', const {'scale': '2'});
    await tester.pump();
    expect(drawn(tester, 'Total'), 40);

    FitDevTools.handle('setTextScale', const {'scale': 'off'});
    await tester.pump();
    expect(drawn(tester, 'Total'), 20);
    expect(_Counter.created, 1, reason: 'no remount when toggling');
  });

  testWidgets('setOverlay turns the overlay on and publishes problems',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    await tester.pumpWidget(const FitScaleScope(
      child: FitDebugOverlay(
        enabled: false,
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: Text('tiny', style: TextStyle(fontSize: 8))),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('compact'), findsNothing);

    FitDevTools.handle('setOverlay', const {'enabled': 'true'});
    await tester.pumpAndSettle();
    expect(find.textContaining('compact · 360×690'), findsOneWidget);
    final problems = FitDevTools.handle('state', const {})['problems'] as List;
    expect(problems.single, containsPair('kind', 'smallText'));

    FitDevTools.handle('setOverlay', const {'enabled': 'false'});
    await tester.pumpAndSettle();
    expect(find.textContaining('compact'), findsNothing);
    expect(FitDevTools.problems, isEmpty);
  });

  test('unknown methods are rejected', () {
    expect(() => FitDevTools.handle('nope', const {}), throwsArgumentError);
  });
}
