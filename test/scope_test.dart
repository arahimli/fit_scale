import 'package:fit_scale/fit_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('context.fit without a scope explains the fix', (tester) async {
    await tester.pumpWidget(host(Builder(builder: (c) {
      c.fit;
      return const SizedBox();
    })));
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('No FitScaleScope found'));
  });

  testWidgets('dependents rebuild when the screen size changes',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    late FitScaleData seen;
    final app = host(FitScaleScope(
      child: Builder(builder: (c) {
        seen = c.fit;
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(app);
    expect(seen.scale, 1);

    tester.view.physicalSize = const Size(744, 1133);
    await tester.pump();
    expect(seen.scale, 1.25);
  });

  testWidgets('useLayoutSize scales a pane by its own size', (tester) async {
    setScreen(tester, const Size(720, 690));
    late FitScaleData screen;
    late FitScaleData pane;
    await tester.pumpWidget(host(FitScaleScope(
      child: Row(children: [
        Expanded(child: Builder(builder: (c) {
          screen = c.fit;
          return const SizedBox();
        })),
        Expanded(
          child: FitScaleScope(
            useLayoutSize: true,
            child: Builder(builder: (c) {
              pane = c.fit;
              return const SizedBox();
            }),
          ),
        ),
      ]),
    )));
    expect(screen.scaleWidth, 1.25); // 720 / 360 capped
    expect(pane.scaleWidth, 1.0); // 360 / 360
  });

  testWidgets('FitSquare stays square in landscape', (tester) async {
    setScreen(tester, const Size(874, 402));
    await tester.pumpWidget(host(const FitScaleScope(
      child: Center(child: FitSquare(size: 56)),
    )));
    final size = tester.getSize(find.byType(FitSquare));
    expect(size.width, size.height);
  });

  testWidgets('FitBox grows with its content', (tester) async {
    setScreen(tester, const Size(360, 690));
    await tester.pumpWidget(host(const FitScaleScope(
      child: Column(children: [
        FitBox(height: 20, child: SizedBox(height: 100)),
      ]),
    )));
    expect(tester.getSize(find.byType(FitBox)).height, 100);
  });

  testWidgets('interactive FitBox keeps the tap floor on a tiny screen',
      (tester) async {
    setScreen(tester, const Size(874, 402));
    await tester.pumpWidget(host(const FitScaleScope(
      child: Column(children: [FitBox(height: 30, interactive: true)]),
    )));
    expect(tester.getSize(find.byType(FitBox)).height, 48);
  });
}
