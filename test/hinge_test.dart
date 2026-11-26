import 'dart:ui' as ui;

import 'package:fit_scale/fit_scale.dart';
import 'package:fit_scale/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screens.dart';

ui.DisplayFeature feature(
  Rect bounds, {
  ui.DisplayFeatureType type = ui.DisplayFeatureType.fold,
  ui.DisplayFeatureState state = ui.DisplayFeatureState.postureHalfOpened,
}) =>
    ui.DisplayFeature(bounds: bounds, type: type, state: state);

void setDevice(WidgetTester tester, FitDevice device) {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = device.displayFeatures;
  addTearDown(tester.view.reset);
}

const startKey = Key('start');
const endKey = Key('end');
const singleKey = Key('single');

Widget hingeLayout({TextDirection direction = TextDirection.ltr}) =>
    Directionality(
      textDirection: direction,
      child: FitScaleScope(
        child: FitHingeLayout(
          single: (_) => const SizedBox.expand(key: singleKey),
          start: (_) => const SizedBox.expand(key: startKey),
          end: (_) => const SizedBox.expand(key: endKey),
        ),
      ),
    );

void main() {
  group('FitHinge.fromDisplayFeatures', () {
    test('half-open vertical fold is book posture', () {
      final h = FitHinge.fromDisplayFeatures(
          [feature(const Rect.fromLTWH(336.5, 0, 0, 841))])!;
      expect(h.posture, FitPosture.book);
      expect(h.splitsLeftRight, isTrue);
    });

    test('half-open horizontal fold is tabletop posture', () {
      final h = FitHinge.fromDisplayFeatures(
          [feature(const Rect.fromLTWH(0, 457.5, 412, 0))])!;
      expect(h.posture, FitPosture.tabletop);
      expect(h.splitsLeftRight, isFalse);
    });

    test('a hinge with a width separates even when flat', () {
      final h = FitHinge.fromDisplayFeatures([
        feature(
          const Rect.fromLTWH(540, 0, 34, 720),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureFlat,
        ),
      ])!;
      expect(h.posture, FitPosture.flat);
    });

    test('a fully opened fold and a cutout do not split the screen', () {
      expect(
        FitHinge.fromDisplayFeatures([
          feature(
            const Rect.fromLTWH(336.5, 0, 0, 841),
            state: ui.DisplayFeatureState.postureFlat,
          ),
          feature(
            const Rect.fromLTWH(150, 0, 100, 30),
            type: ui.DisplayFeatureType.cutout,
            state: ui.DisplayFeatureState.unknown,
          ),
        ]),
        isNull,
      );
      expect(FitHinge.fromDisplayFeatures(const []), isNull);
    });

    test('crosses: only rects lying across the line', () {
      final h = FitHinge.fromDisplayFeatures(
          [feature(const Rect.fromLTWH(100, 0, 0, 800))])!;
      expect(h.crosses(const Rect.fromLTRB(50, 10, 150, 30)), isTrue);
      expect(h.crosses(const Rect.fromLTRB(0, 10, 100, 30)), isFalse);
      expect(h.crosses(const Rect.fromLTRB(100, 10, 150, 30)), isFalse);
    });
  });

  testWidgets('fit.hinge comes from the screen, not from panes',
      (tester) async {
    setDevice(tester, FitDevices.foldBook);
    late FitScaleData screen;
    late FitScaleData pane;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: FitScaleScope(
        child: Builder(builder: (c) {
          screen = c.fit;
          return FitScaleScope(
            useLayoutSize: true,
            child: Builder(builder: (c) {
              pane = c.fit;
              return const SizedBox();
            }),
          );
        }),
      ),
    ));
    expect(screen.hinge?.posture, FitPosture.book);
    expect(pane.hinge, isNull);
  });

  group('FitHingeLayout', () {
    testWidgets('without a hinge it builds single', (tester) async {
      setDevice(tester, FitDevices.pixel9);
      await tester.pumpWidget(hingeLayout());
      expect(find.byKey(singleKey), findsOneWidget);
      expect(find.byKey(startKey), findsNothing);
    });

    testWidgets('book posture: left and right of the fold', (tester) async {
      setDevice(tester, FitDevices.foldBook);
      await tester.pumpWidget(hingeLayout());
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(startKey)),
          const Rect.fromLTRB(0, 0, 336.5, 841));
      expect(tester.getRect(find.byKey(endKey)),
          const Rect.fromLTRB(336.5, 0, 673, 841));
    });

    testWidgets('Surface Duo: nothing under the hinge', (tester) async {
      setDevice(tester, FitDevices.surfaceDuo);
      await tester.pumpWidget(hingeLayout());
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(startKey)).right, 540);
      expect(tester.getRect(find.byKey(endKey)).left, 574);
    });

    testWidgets('tabletop posture: above and below the fold', (tester) async {
      setDevice(tester, FitDevices.flipTabletop);
      await tester.pumpWidget(hingeLayout());
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(startKey)).bottom, 457.5);
      expect(tester.getRect(find.byKey(endKey)).top, 457.5);
    });

    testWidgets('right to left: start goes on the right', (tester) async {
      setDevice(tester, FitDevices.foldBook);
      await tester.pumpWidget(hingeLayout(direction: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(startKey)),
          const Rect.fromLTRB(336.5, 0, 673, 841));
    });

    testWidgets('placed below other content, it still splits at the fold',
        (tester) async {
      setDevice(tester, FitDevices.flipTabletop);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: FitScaleScope(
          child: Column(children: [
            const SizedBox(height: 100), // an app bar, say
            Expanded(
              child: FitHingeLayout(
                single: (_) => const SizedBox.expand(key: singleKey),
                start: (_) => const SizedBox.expand(key: startKey),
                end: (_) => const SizedBox.expand(key: endKey),
              ),
            ),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(startKey)),
          const Rect.fromLTRB(0, 100, 412, 457.5));
      expect(tester.getRect(find.byKey(endKey)).top, 457.5);
    });
  });

  group('hingeOverlap check', () {
    setUpAll(loadFitScaleTestFonts);

    // A list with no gaps between rows: whatever the fold's position, a
    // row lies across it.
    Widget list() => MaterialApp(
          home: Scaffold(
            body: ListView(children: [
              for (var i = 0; i < 30; i++)
                ListTile(title: Text('Order line $i'), onTap: () {}),
            ]),
          ),
        );

    for (final device in FitDevices.foldables) {
      testWidgets('a one-column list crosses the ${device.name} fold',
          (tester) async {
        final report = await pumpFitScreen(tester, list(), device: device);
        final hinge =
            report.problems.where((p) => p.check == FitCheck.hingeOverlap);
        expect(hinge, isNotEmpty, reason: '$report');
      });
    }

    testWidgets('FitHingeLayout keeps everything off the fold', (tester) async {
      final report = await pumpFitScreen(
        tester,
        fitApp(FitHingeLayout(
          single: (_) => const GoodScreen(),
          start: (_) => const Center(child: Text('Order summary')),
          end: (_) => Center(
            child: FilledButton(
              onPressed: () {},
              child: const Text('Place order'),
            ),
          ),
        )),
        device: FitDevices.foldBook,
      );
      expect(report.passed, isTrue, reason: '$report');
    });

    testWidgets('never fires on devices without a fold', (tester) async {
      final report = await pumpFitScreen(
        tester,
        fitApp(const GoodScreen()),
        device: FitDevices.ipadMini,
      );
      expect(report.passed, isTrue, reason: '$report');
    });
  });

  testWidgets('the overlay draws the fold and outlines what crosses it',
      (tester) async {
    setDevice(tester, FitDevices.foldBook);
    final calls = <List<FitDebugProblem>>[];
    await tester.pumpWidget(FitScaleScope(
      child: FitDebugOverlay(
        enabled: true,
        onProblems: calls.add,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('This line runs across the fold')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls.last.map((p) => p.kind), [FitDebugProblemKind.hingeOverlap]);
    expect(calls.last.single.message,
        '"This line runs across the fold" crosses the fold');
    expect(find.textContaining('book fold'), findsOneWidget);
  });
}
