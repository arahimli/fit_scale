import 'package:fit_scale/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screens.dart';

void main() {
  setUpAll(loadFitScaleTestFonts);

  // 9 devices x 3 text sizes = 27 cases, all must pass.
  testFitScale('good screen', () => fitApp(const GoodScreen()));

  group('bad screen is caught', () {
    late FitReport report;

    testWidgets('on a small Android phone', (tester) async {
      report = await pumpFitScreen(
        tester,
        MaterialApp(home: const BadScreen()),
        device: FitDevices.androidCompact,
        textScale: 1.3,
      );
      final checks = report.problems.map((p) => p.check).toSet();
      expect(report.passed, isFalse);
      expect(
          checks, {FitCheck.overflow, FitCheck.tapTargets, FitCheck.minFont});
      expect(report.toString(), contains('android_compact 360x640'));
      expect(report.problems.where((p) => p.check == FitCheck.tapTargets),
          hasLength(1));
    });

    testWidgets('only the checks asked for', (tester) async {
      report = await pumpFitScreen(
        tester,
        MaterialApp(home: const BadScreen()),
        device: FitDevices.iphoneSe1,
        checks: {FitCheck.minFont},
      );
      expect(report.problems.map((p) => p.check).toSet(), {FitCheck.minFont});
    });
  });

  testWidgets('platform and text scale are reset afterwards', (tester) async {
    await pumpFitScreen(
      tester,
      fitApp(const GoodScreen()),
      device: FitDevices.iphoneSe1,
      textScale: 2,
    );
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
