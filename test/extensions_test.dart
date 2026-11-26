import 'package:fit_scale/extensions.dart';
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

/// Reads extensions in build and records them. Const, and does not
/// depend on any InheritedWidget, so only the scope's subtree rebuild
/// can refresh it.
class _Probe extends StatelessWidget {
  const _Probe();

  static final seen = <double>[];

  @override
  Widget build(BuildContext context) {
    seen.add(16.w);
    return const SizedBox();
  }
}

void main() {
  setUp(_Probe.seen.clear);

  testWidgets('extensions match context.fit', (tester) async {
    setScreen(tester, const Size(280, 653));
    late FitScaleData fit;
    late List<double> ext;
    await tester.pumpWidget(host(FitScaleScope(
      child: Builder(builder: (c) {
        fit = c.fit;
        ext = [16.w, 16.h, 16.r, 11.sp, 40.tap, 0.5.sw, 0.5.sh];
        return const SizedBox();
      }),
    )));
    expect(ext, [
      fit.w(16),
      fit.h(16),
      fit.r(16),
      fit.sp(11),
      fit.tap(40),
      140,
      326.5,
    ]);
    expect(11.sp, 11, reason: 'fonts never below design size');
    expect(40.tap, 48, reason: 'touch-target floor');
  });

  testWidgets('a const widget using 16.w rebuilds when the screen resizes',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    await tester.pumpWidget(host(const FitScaleScope(child: _Probe())));
    expect(_Probe.seen, [16]);

    tester.view.physicalSize = const Size(744, 1133);
    await tester.pump();
    expect(_Probe.seen.last, 20); // 16 x 1.25 cap

    // Same size again: no extra rebuild.
    final builds = _Probe.seen.length;
    await tester.pump();
    expect(_Probe.seen.length, builds);
  });

  testWidgets('verticalSpace and horizontalSpace', (tester) async {
    setScreen(tester, const Size(744, 1133));
    await tester.pumpWidget(host(FitScaleScope(
      child: Builder(
        builder: (_) => Column(children: [8.verticalSpace, 8.horizontalSpace]),
      ),
    )));
    final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
    expect(boxes[0].height, 10);
    expect(boxes[1].width, 10);
  });

  testWidgets('a nested layout scope does not replace the global one',
      (tester) async {
    setScreen(tester, const Size(720, 690));
    late double inPane;
    await tester.pumpWidget(host(FitScaleScope(
      child: Row(children: [
        const Expanded(child: SizedBox()),
        Expanded(
          child: FitScaleScope(
            useLayoutSize: true,
            child: Builder(builder: (_) {
              inPane = 16.w;
              return const SizedBox();
            }),
          ),
        ),
      ]),
    )));
    expect(inPane, 20); // root screen 720 wide, capped at 1.25
    expect(FitScale.global!.size, const Size(720, 690));
  });

  testWidgets('without a root scope the error explains the fix',
      (tester) async {
    expect(FitScale.global, isNull);
    await tester.pumpWidget(host(Builder(builder: (_) {
      16.w;
      return const SizedBox();
    })));
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('No root FitScaleScope found'));
  });

  testWidgets('removing the scope clears the global data', (tester) async {
    setScreen(tester, const Size(360, 690));
    await tester.pumpWidget(host(const FitScaleScope(child: SizedBox())));
    expect(FitScale.global, isNotNull);
    await tester.pumpWidget(host(const SizedBox()));
    expect(FitScale.global, isNull);
  });
}
