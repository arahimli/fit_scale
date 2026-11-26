import 'package:fit_scale/fit_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget app(
  Widget body, {
  bool enabled = true,
  ValueChanged<List<FitDebugProblem>>? onProblems,
}) =>
    FitScaleScope(
      child: FitDebugOverlay(
        enabled: enabled,
        onProblems: onProblems,
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );

const tapKey = Key('tap');
const tinyKey = Key('tiny');
const cutKey = Key('cut');

/// One of each problem.
Widget badBody() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: tapKey,
          onTap: () {},
          child: const SizedBox(width: 30, height: 30),
        ),
        const Text('tiny', key: tinyKey, style: TextStyle(fontSize: 8)),
        const SizedBox(
          width: 40,
          child: Text(
            'Wireless Headphones',
            key: cutKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

const cleanBody = Center(child: Text('Order summary'));

void main() {
  testWidgets('disabled, it is just the child', (tester) async {
    setScreen(tester, const Size(360, 690));
    final calls = <List<FitDebugProblem>>[];
    await tester
        .pumpWidget(app(badBody(), enabled: false, onProblems: calls.add));
    await tester.pumpAndSettle();
    expect(find.textContaining('compact'), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('the panel shows class, size, factors and text scale',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(app(cleanBody));
    await tester.pumpAndSettle();
    expect(find.text('compact · 360×690'), findsOneWidget);
    expect(find.text('w 1.00  h 1.00  r 1.00  sp 1.00'), findsOneWidget);
    expect(find.text('text ×1.30 · no problems'), findsOneWidget);
  });

  testWidgets('outlines each kind of problem where it is', (tester) async {
    setScreen(tester, const Size(360, 690));
    final calls = <List<FitDebugProblem>>[];
    await tester.pumpWidget(app(badBody(), onProblems: calls.add));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    final byKind = {for (final p in calls.single) p.kind: p};
    // No fold on this screen; hinge overlaps are tested in hinge_test.
    expect(
        byKind.keys,
        unorderedEquals([
          FitDebugProblemKind.tapTarget,
          FitDebugProblemKind.smallText,
          FitDebugProblemKind.truncatedText,
        ]));

    expect(byKind[FitDebugProblemKind.tapTarget]!.rect,
        tester.getRect(find.byKey(tapKey)));
    expect(byKind[FitDebugProblemKind.smallText]!.rect,
        tester.getRect(find.byKey(tinyKey)));
    expect(byKind[FitDebugProblemKind.truncatedText]!.rect,
        tester.getRect(find.byKey(cutKey)));
    expect(byKind[FitDebugProblemKind.smallText]!.message,
        '"tiny" renders at 8.0 px, below 11.0');

    expect(
      find.text('text ×1.00 · 1 tap · 1 small text · 1 cut text'),
      findsOneWidget,
    );
  });

  testWidgets('a clean screen reports nothing, even with large text',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final calls = <List<FitDebugProblem>>[];
    await tester.pumpWidget(app(cleanBody, onProblems: calls.add));
    await tester.pumpAndSettle();
    expect(calls, isEmpty, reason: 'the panel must not flag itself');
  });

  testWidgets('follows changes inside the app without being rebuilt',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    final bad = ValueNotifier(false);
    addTearDown(bad.dispose);
    final calls = <List<FitDebugProblem>>[];
    await tester.pumpWidget(app(
      ValueListenableBuilder<bool>(
        valueListenable: bad,
        builder: (_, isBad, __) => isBad ? badBody() : cleanBody,
      ),
      onProblems: calls.add,
    ));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    bad.value = true;
    await tester.pumpAndSettle();
    expect(calls.last, hasLength(3));

    bad.value = false;
    await tester.pumpAndSettle();
    expect(calls.last, isEmpty);
  });

  testWidgets('taps reach the app; tapping the panel collapses it',
      (tester) async {
    setScreen(tester, const Size(360, 690));
    var taps = 0;
    await tester.pumpWidget(app(Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => taps++,
        child: const SizedBox(width: 100, height: 100),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 345));
    expect(taps, 1, reason: 'outlines and panel ignore app touches');

    await tester.tap(find.text('compact · 360×690'));
    await tester.pumpAndSettle();
    expect(find.text('fit · ok'), findsOneWidget);
    expect(taps, 1);
  });
}
