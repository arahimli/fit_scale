import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import '../checks.dart';
import '../hinge.dart';
import 'devices.dart';
import 'report.dart';

/// What the harness checks on every device and text size.
enum FitCheck {
  /// No RenderFlex (or other) overflow.
  overflow,

  /// Every tappable element meets the platform's minimum
  /// (48x48 on Android, 44x44 on iOS).
  tapTargets,

  /// No visible text rendered smaller than `minFontSize`.
  minFont,

  /// No text cut off by `maxLines` (ellipsis, fade or clip), including a
  /// `FitText` that did not fit even at its minimum size.
  ///
  /// Not in [defaults]: many apps cut long names on purpose. Add it with
  /// `checks: {...FitCheck.defaults, FitCheck.truncatedText}`.
  truncatedText,

  /// No text line or tap target lying across a fold or hinge. Only does
  /// anything on devices with one, such as [FitDevices.foldables].
  hingeOverlap;

  /// The checks run when none are given.
  static const defaults = {overflow, tapTargets, minFont, hingeOverlap};
}

/// One thing that went wrong on one device.
@immutable
class FitProblem {
  const FitProblem(this.check, this.message);

  final FitCheck check;
  final String message;

  @override
  String toString() => '[${check.name}] $message';
}

/// Result of rendering one screen on one device at one text size.
@immutable
class FitReport {
  const FitReport({
    required this.device,
    required this.textScale,
    required this.problems,
  });

  final FitDevice device;
  final double textScale;
  final List<FitProblem> problems;

  bool get passed => problems.isEmpty;

  @override
  String toString() {
    final head = '$device, text x$textScale';
    if (passed) return '$head: ok';
    return '$head: ${problems.length} problem(s)\n'
        '${problems.map((p) => '  - $p').join('\n')}';
  }
}

/// Key of the [RepaintBoundary] the harness wraps the app in.
const fitScaleRootKey = ValueKey('fit_scale_root');

/// Renders [app] as it would look on [device] with the system text
/// scale set to [textScale], then runs [checks].
///
/// Call it inside your own `testWidgets` when you need custom setup;
/// otherwise use [testFitScale]. Screen size, text scale and platform
/// are reset when the test ends.
Future<FitReport> pumpFitScreen(
  WidgetTester tester,
  Widget app, {
  required FitDevice device,
  double textScale = 1.0,
  double minFontSize = 11,
  Set<FitCheck> checks = FitCheck.defaults,
}) async {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (device.displayFeatures.isNotEmpty) {
    tester.view.displayFeatures = device.displayFeatures;
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final semantics = tester.ensureSemantics();
  final overflows = <String>{};
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed by')) {
      overflows.add(text.split('\n').first);
    } else {
      previousOnError?.call(details);
    }
  };

  final problems = <FitProblem>[];
  debugDefaultTargetPlatformOverride = device.platform;
  try {
    await tester.pumpWidget(
      RepaintBoundary(key: fitScaleRootKey, child: app),
    );
    await tester.pumpAndSettle();
    FlutterError.onError = previousOnError;

    if (checks.contains(FitCheck.overflow)) {
      for (final o in overflows) {
        problems.add(FitProblem(FitCheck.overflow, o));
      }
    }

    if (checks.contains(FitCheck.tapTargets)) {
      final guideline = switch (device.platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => iOSTapTargetGuideline,
        _ => androidTapTargetGuideline,
      };
      final result = await guideline.evaluate(tester);
      if (!result.passed) {
        for (final line in (result.reason ?? 'tap target too small')
            .trim()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('See also'))) {
          problems.add(FitProblem(FitCheck.tapTargets, line));
        }
      }
    }

    if (checks.contains(FitCheck.minFont)) {
      problems.addAll(_smallText(tester, minFontSize));
    }

    if (checks.contains(FitCheck.truncatedText)) {
      problems.addAll(_truncatedText(tester));
    }

    final hinge = FitHinge.fromDisplayFeatures(device.displayFeatures);
    if (hinge != null && checks.contains(FitCheck.hingeOverlap)) {
      final root = tester
          .renderObject(find.byKey(fitScaleRootKey))
          .owner
          ?.semanticsOwner
          ?.rootSemanticsNode;
      final targets = root == null
          ? const <TapTarget>[]
          : tapTargets(root, devicePixelRatio: 1, screen: device.size);
      for (final issue in hingeOverlaps(
        hinge,
        tester.allRenderObjects.whereType<RenderParagraph>(),
        targets,
      )) {
        problems.add(FitProblem(FitCheck.hingeOverlap, issue.message));
      }
    }
  } finally {
    FlutterError.onError = previousOnError;
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }

  return FitReport(device: device, textScale: textScale, problems: problems);
}

/// Defines one `testWidgets` per device and text scale that renders
/// [builder]'s app and fails with every problem found.
///
/// ```dart
/// testFitScale('checkout', () => const MyApp(home: CheckoutPage()));
/// ```
///
/// With [goldenDir] set, also compares a golden per case
/// (run `flutter test --update-goldens` to write them).
///
/// With [reportDir] set, writes a report when the group finishes, also
/// when cases fail: `<description>.html` (a device × text size table with
/// a screenshot per case), `.md` (the same table, for pull requests),
/// `.json`, and an `index.html` of every screen in the directory. On
/// GitHub Actions the markdown is added to the job summary. See
/// [writeFitReport].
@isTestGroup
void testFitScale(
  String description,
  Widget Function() builder, {
  List<FitDevice> devices = FitDevices.all,
  List<double> textScales = const [1.0, 1.3, 2.0],
  double minFontSize = 11,
  Set<FitCheck> checks = FitCheck.defaults,
  String? goldenDir,
  String? reportDir,
  bool? skip,
}) {
  final screen = reportDir == null ? null : FitScreenReport(description);
  group(description, () {
    if (screen != null) {
      tearDownAll(() => writeFitReport(screen, reportDir!));
    }
    for (final device in devices) {
      for (final scale in textScales) {
        testWidgets('$device text x$scale', (tester) async {
          final report = await pumpFitScreen(
            tester,
            builder(),
            device: device,
            textScale: scale,
            minFontSize: minFontSize,
            checks: checks,
          );
          if (screen != null) {
            final shot = '${screen.slug}/${device.name}_x$scale.png';
            await _screenshot(tester, '$reportDir/$shot');
            screen.cases.add(FitCaseResult(report, screenshot: shot));
          }
          if (goldenDir != null) {
            await expectLater(
              find.byKey(fitScaleRootKey),
              matchesGoldenFile('$goldenDir/${device.name}_x$scale.png'),
            );
          }
          if (!report.passed) fail(report.toString());
        }, skip: skip);
      }
    }
  });
}

/// Saves the harness root as a PNG at [path].
Future<void> _screenshot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(fitScaleRootKey),
  );
  // Image encoding needs real async work, which widget tests fake.
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

/// Loads Roboto and Material Icons from the Flutter SDK so tests render
/// real glyphs instead of the Ahem test font (whose square glyphs make
/// text wider than it really is). Registers Roboto under the iOS system
/// font names too, so iOS devices render it as well.
///
/// Call it from `setUpAll`. Does nothing if `FLUTTER_ROOT` is unknown.
Future<void> loadFitScaleTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;

  ByteData read(String file) {
    final bytes = File('$dir/$file').readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }

  const textFamilies = [
    'Roboto',
    '.SF UI Display',
    '.SF UI Text',
    '.SF Pro Text',
    '.SF Pro Display',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ];
  const weights = ['Regular', 'Medium', 'Bold'];
  for (final family in textFamilies) {
    final loader = FontLoader(family);
    for (final w in weights) {
      loader.addFont(Future.value(read('Roboto-$w.ttf')));
    }
    await loader.load();
  }
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(read('MaterialIcons-Regular.otf'))))
      .load();
}

List<FitProblem> _smallText(WidgetTester tester, double minFontSize) => [
      for (final issue in smallText(
        tester.allRenderObjects.whereType<RenderParagraph>(),
        minFontSize,
      ))
        FitProblem(FitCheck.minFont, issue.message),
    ];

List<FitProblem> _truncatedText(WidgetTester tester) => [
      for (final issue in truncatedText(
        tester.allRenderObjects.whereType<RenderParagraph>(),
      ))
        FitProblem(FitCheck.truncatedText, issue.message),
    ];
