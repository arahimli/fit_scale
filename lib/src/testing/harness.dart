import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import 'devices.dart';

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
  truncatedText;

  /// The checks run when none are given.
  static const defaults = {overflow, tapTargets, minFont};
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
/// With [goldenDir] set, also saves a screenshot per case
/// (run `flutter test --update-goldens` to write them).
@isTestGroup
void testFitScale(
  String description,
  Widget Function() builder, {
  List<FitDevice> devices = FitDevices.all,
  List<double> textScales = const [1.0, 1.3, 2.0],
  double minFontSize = 11,
  Set<FitCheck> checks = FitCheck.defaults,
  String? goldenDir,
  bool? skip,
}) {
  group(description, () {
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

List<FitProblem> _smallText(WidgetTester tester, double minFontSize) {
  final problems = <FitProblem>[];
  final seen = <String>{};
  for (final paragraph
      in tester.allRenderObjects.whereType<RenderParagraph>()) {
    if (!paragraph.attached || paragraph.size.isEmpty) continue;
    void visit(InlineSpan span, double inherited) {
      final size = span.style?.fontSize ?? inherited;
      if (span is TextSpan) {
        final text = span.text?.trim() ?? '';
        if (text.isNotEmpty && !_isIconGlyph(text)) {
          final px = paragraph.textScaler.scale(size);
          if (px < minFontSize) {
            final snippet =
                text.length > 40 ? '${text.substring(0, 40)}...' : text;
            final msg = '"$snippet" renders at ${px.toStringAsFixed(1)} px, '
                'below $minFontSize';
            if (seen.add(msg)) problems.add(FitProblem(FitCheck.minFont, msg));
          }
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, size);
        }
      }
    }

    visit(paragraph.text, 14);
  }
  return problems;
}

/// Icon fonts put glyphs in the Unicode private use area.
bool _isIconGlyph(String text) =>
    text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF);

List<FitProblem> _truncatedText(WidgetTester tester) {
  final problems = <FitProblem>[];
  final seen = <String>{};
  for (final paragraph
      in tester.allRenderObjects.whereType<RenderParagraph>()) {
    if (!paragraph.attached || paragraph.size.isEmpty) continue;
    if (!paragraph.didExceedMaxLines) continue;
    final text = paragraph.text.toPlainText().trim();
    if (text.isEmpty || _isIconGlyph(text)) continue;
    final snippet = text.length > 40 ? '${text.substring(0, 40)}...' : text;
    final msg = '"$snippet" is cut off '
        '(maxLines: ${paragraph.maxLines}, overflow: ${paragraph.overflow.name})';
    if (seen.add(msg)) problems.add(FitProblem(FitCheck.truncatedText, msg));
  }
  return problems;
}
