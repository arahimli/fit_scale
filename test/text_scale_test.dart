import 'package:fit_scale/fit_scale.dart';
import 'package:fit_scale/testing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void setScreen(WidgetTester tester, Size size, {double text = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Font size a Text with [key] is drawn at.
double drawn(WidgetTester tester, Key key) {
  final p = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
  );
  return p.textScaler.scale((p.text as TextSpan).style!.fontSize!);
}

Widget materialApp(Widget home) => FitScaleScope(
      child: MaterialApp(
        builder: (context, child) => FitTextScale(child: child!),
        home: home,
      ),
    );

const plain = Key('plain');
const themed = Key('themed');

Widget page() => Scaffold(
      body: Builder(
        builder: (context) => Column(children: [
          const Text('Total', key: plain, style: TextStyle(fontSize: 20)),
          Text('Title',
              key: themed, style: Theme.of(context).textTheme.titleLarge),
        ]),
      ),
    );

void main() {
  testWidgets('design size: text is unchanged', (tester) async {
    setScreen(tester, const Size(360, 690));
    await tester.pumpWidget(materialApp(page()));
    expect(drawn(tester, plain), 20);
  });

  testWidgets('large screen: plain and theme text both scale', (tester) async {
    setScreen(tester, const Size(744, 1133)); // font factor 1.15
    await tester.pumpWidget(materialApp(page()));
    expect(drawn(tester, plain), closeTo(23, 1e-9));
    final titleLarge = Theme.of(tester.element(find.byKey(themed)))
        .textTheme
        .titleLarge!
        .fontSize!;
    expect(drawn(tester, themed), closeTo(titleLarge * 1.15, 1e-9));
  });

  testWidgets('small screen: fonts stay at the design size', (tester) async {
    setScreen(tester, const Size(280, 653));
    await tester.pumpWidget(materialApp(page()));
    expect(drawn(tester, plain), 20);
  });

  testWidgets('the system text size applies on top', (tester) async {
    setScreen(tester, const Size(744, 1133), text: 2);
    await tester.pumpWidget(materialApp(page()));
    expect(drawn(tester, plain), closeTo(20 * 1.15 * 2, 1e-9));
  });

  testWidgets('works without Material: Cupertino app', (tester) async {
    setScreen(tester, const Size(744, 1133));
    await tester.pumpWidget(FitScaleScope(
      child: CupertinoApp(
        builder: (context, child) => FitTextScale(child: child!),
        home: const Center(
          child: Text('Total', key: plain, style: TextStyle(fontSize: 20)),
        ),
      ),
    ));
    expect(drawn(tester, plain), closeTo(23, 1e-9));
  });

  testWidgets('nested FitTextScale does not apply the factor twice',
      (tester) async {
    setScreen(tester, const Size(744, 1133));
    await tester.pumpWidget(FitScaleScope(
      child: MaterialApp(
        builder: (context, child) => FitTextScale(child: child!),
        home: const FitTextScale(
          child: Text('Total', key: plain, style: TextStyle(fontSize: 20)),
        ),
      ),
    ));
    expect(drawn(tester, plain), closeTo(23, 1e-9));
  });

  testWidgets('FitText floors and the harness agree with the scaler',
      (tester) async {
    // 10 px design text on a large screen draws at 11.5: passes minFont.
    final report = await pumpFitScreen(
      tester,
      materialApp(const Scaffold(
        body:
            Center(child: Text('Small print', style: TextStyle(fontSize: 10))),
      )),
      device: FitDevices.ipadMini,
    );
    expect(report.problems.where((p) => p.check == FitCheck.minFont), isEmpty);

    final small = await pumpFitScreen(
      tester,
      materialApp(const Scaffold(
        body:
            Center(child: Text('Small print', style: TextStyle(fontSize: 10))),
      )),
      device: FitDevices.iphoneSe1,
    );
    expect(small.problems.map((p) => p.check), contains(FitCheck.minFont));
  });

  test('scaler equality and value', () {
    const a = FitTextScaler(TextScaler.linear(2), 1.15);
    expect(a.scale(10), closeTo(23, 1e-9));
    expect(a, const FitTextScaler(TextScaler.linear(2), 1.15));
    expect(a == const FitTextScaler(TextScaler.linear(2), 1.1), isFalse);
  });
}
