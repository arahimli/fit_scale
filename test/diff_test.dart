import 'dart:convert';
import 'dart:io';

import 'package:fit_scale/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screens.dart';

FitCaseResult result(FitDevice d, double scale, [List<FitProblem>? p]) =>
    FitCaseResult(FitReport(device: d, textScale: scale, problems: p ?? []));

const overflowA = FitProblem(FitCheck.overflow, 'overflowed by 4 pixels');
const overflowB = FitProblem(FitCheck.overflow, 'overflowed by 9 pixels');
const tapX = FitProblem(FitCheck.tapTargets, 'Place order is 40x40');
const fontY = FitProblem(FitCheck.minFont, '"VAT" renders at 9.8 px');

Map<String, dynamic> json(FitScreenReport r) =>
    jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;

final baseline = json(FitScreenReport('Checkout', [
  result(FitDevices.iphoneSe1, 1.0),
  result(FitDevices.iphoneSe1, 2.0, [overflowA]),
  result(FitDevices.ipadMini, 1.0, [tapX]),
  result(FitDevices.ipadMini, 2.0),
  result(FitDevices.pixel9, 1.0),
]));

final current = FitScreenReport('Checkout', [
  result(FitDevices.iphoneSe1, 1.0, [overflowB]), // regressed
  result(FitDevices.iphoneSe1, 2.0), // fixed
  result(FitDevices.ipadMini, 1.0, [tapX, fontY]), // changed
  result(FitDevices.ipadMini, 2.0), // same
  result(FitDevices.foldCover, 1.0), // added; pixel9 removed
]);

final dir = Directory.systemTemp.createTempSync('fit_scale_diff_');

void main() {
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('classifies every kind of change', () {
    final diff = FitReportDiff(baseline, current);
    final byKind = {
      for (final c in diff.changes) c.kind: '${c.device}@${c.textScale}',
    };
    expect(byKind, {
      FitChangeKind.regressed: 'iphone_se1@1.0',
      FitChangeKind.fixed: 'iphone_se1@2.0',
      FitChangeKind.changed: 'ipad_mini@1.0',
      FitChangeKind.added: 'fold_cover@1.0',
      FitChangeKind.removed: 'pixel9@1.0',
    });
    expect(diff.summary,
        '1 regressed · 1 fixed · 1 changed · 1 added · 1 removed');
    expect(diff.hasRegressions, isTrue);

    final changed = diff.of(FitChangeKind.changed).single;
    expect(changed.appeared, ['minFont: "VAT" renders at 9.8 px']);
    expect(changed.resolved, isEmpty);
  });

  test('the same run twice has no changes', () {
    final diff = FitReportDiff(json(current), current);
    expect(diff.changes, isEmpty);
    expect(diff.summary, 'no changes');
    expect(diff.hasRegressions, isFalse);
  });

  test('a case that only lost problems is not a regression', () {
    final diff = FitReportDiff(
      json(FitScreenReport('S', [
        result(FitDevices.ipadMini, 1.0, [tapX, fontY])
      ])),
      FitScreenReport('S', [
        result(FitDevices.ipadMini, 1.0, [tapX])
      ]),
    );
    expect(diff.of(FitChangeKind.changed), hasLength(1));
    expect(diff.hasRegressions, isFalse);
  });

  test('markdown and html list what appeared and went away', () {
    final diff = FitReportDiff(baseline, current);
    final md = diff.toMarkdown();
    expect(md, contains('#### Since baseline: 1 regressed'));
    expect(md, contains('🔴 **regressed** iphone_se1, text ×1.0'));
    expect(md, contains('  - new: overflow: overflowed by 9 pixels'));
    expect(md, contains('🟢 **fixed** iphone_se1, text ×2.0'));
    expect(md, contains('  - gone: overflow: overflowed by 4 pixels'));

    final html = current.toHtml(diff: diff);
    expect(html, contains('<h2>Since baseline: 1 regressed'));
    expect(html, contains('<span class="tag bad">regressed</span>'));
  });

  test('writeFitReport reads the baseline directory', () {
    final base = '${dir.path}/base';
    final out = '${dir.path}/out';
    final summary = File('${dir.path}/summary.md')..writeAsStringSync('');
    Directory(base).createSync();
    File('$base/checkout.json').writeAsStringSync(jsonEncode(baseline));

    writeFitReport(current, out, baselineDir: base, summaryPath: summary.path);

    expect(File('$out/checkout.md').readAsStringSync(),
        contains('#### Since baseline: 1 regressed'));
    final saved = jsonDecode(File('$out/checkout.json').readAsStringSync());
    expect(saved['sinceBaseline'], {
      'summary': '1 regressed · 1 fixed · 1 changed · 1 added · 1 removed',
      'regressions': true,
    });
    expect(File('$out/index.html').readAsStringSync(),
        contains('<span class="tag bad">1 regressed'));
    expect(summary.readAsStringSync(), contains('Since baseline'));
  });

  test('without a baseline file nothing changes', () {
    final out = '${dir.path}/nobase';
    writeFitReport(current, out, baselineDir: '${dir.path}/missing');
    expect(File('$out/checkout.md').readAsStringSync(),
        isNot(contains('Since baseline')));
  });

  // A real run compared with a baseline in which the case failed.
  final runBase = '${dir.path}/run_base';
  final runOut = '${dir.path}/run_out';
  Directory(runBase).createSync(recursive: true);
  File('$runBase/order_screen.json').writeAsStringSync(jsonEncode(json(
    FitScreenReport('Order screen', [
      result(FitDevices.iphoneSe1, 1.0, [overflowA]),
    ]),
  )));
  setUpAll(loadFitScaleTestFonts);
  testFitScale(
    'Order screen',
    () => fitApp(const GoodScreen()),
    devices: const [FitDevices.iphoneSe1],
    textScales: const [1.0],
    reportDir: runOut,
    baselineDir: runBase,
  );

  test('testFitScale passes baselineDir through', () {
    final saved = jsonDecode(
      File('$runOut/order_screen.json').readAsStringSync(),
    );
    expect(
        saved['sinceBaseline'], {'summary': '1 fixed', 'regressions': false});
  });
}
