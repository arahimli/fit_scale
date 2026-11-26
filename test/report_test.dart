import 'dart:convert';
import 'dart:io';

import 'package:fit_scale/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screens.dart';

FitReport report(FitDevice device, double scale, [List<FitProblem>? p]) =>
    FitReport(device: device, textScale: scale, problems: p ?? const []);

FitScreenReport sample() => FitScreenReport('Checkout', [
      FitCaseResult(report(FitDevices.iphoneSe1, 1.0)),
      FitCaseResult(report(FitDevices.iphoneSe1, 2.0, const [
        FitProblem(FitCheck.overflow, 'A RenderFlex overflowed by 45 pixels'),
        FitProblem(FitCheck.tapTargets, 'found <b>Size(30, 30)</b> & less'),
      ])),
      FitCaseResult(report(FitDevices.ipadMini, 1.0)),
      FitCaseResult(report(FitDevices.ipadMini, 2.0)),
    ]);

final dir = Directory.systemTemp.createTempSync('fit_scale_report_');

void main() {
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('markdown: device x text size table with counts', () {
    final md = sample().toMarkdown();
    expect(md, contains('### Checkout: 3 / 4 passed'));
    expect(md, contains('| Device | Class | Text ×1.0 | Text ×2.0 |'));
    expect(
        md,
        contains(
            '| iphone_se1 320×568 | compact | ✓ | ✗ 1 overflow · 1 tap |'));
    expect(md, contains('| ipad_mini 744×1133 | medium | ✓ | ✓ |'));
    expect(md, contains('<details><summary>Problems in 1 case</summary>'));
    expect(md, contains('&lt;b&gt;Size(30, 30)&lt;/b&gt;'));
    expect(md, isNot(contains('<b>')));
  });

  test('html: summary, escaping and links to problems', () {
    final html = sample().toHtml();
    expect(html, contains('3 / 4 cases passed'));
    expect(html, contains('found &lt;b&gt;Size(30, 30)&lt;/b&gt; &amp; less'));
    expect(html, isNot(contains('<b>Size')));
    expect(html, contains('href="#case-iphone_se1-2_0"'));
    expect(html, contains('<section id="case-iphone_se1-2_0">'));
    expect(html, contains('prefers-color-scheme:dark'));
  });

  test('slug is file-name safe', () {
    expect(FitScreenReport('Checkout / Pay!').slug, 'checkout_pay');
    expect(FitScreenReport('???').slug, 'screen');
  });

  test('writeFitReport writes files, the index and the job summary', () {
    final out = '${dir.path}/write';
    final summary = File('${dir.path}/summary.md')..writeAsStringSync('');
    writeFitReport(sample(), out, summaryPath: summary.path);
    writeFitReport(
        FitScreenReport('Profile', [
          FitCaseResult(report(FitDevices.pixel9, 1.0)),
        ]),
        out,
        summaryPath: summary.path);

    for (final f in [
      'checkout.html',
      'checkout.md',
      'checkout.json',
      'profile.html',
      'index.html'
    ]) {
      expect(File('$out/$f').existsSync(), isTrue, reason: f);
    }
    final index = File('$out/index.html').readAsStringSync();
    expect(index, contains('<a href="checkout.html">Checkout</a>'));
    expect(index, contains('3 / 4'));
    expect(index, contains('<a href="profile.html">Profile</a>'));

    final json = jsonDecode(File('$out/checkout.json').readAsStringSync());
    expect(json['passed'], 3);
    expect((json['cases'] as List)[1]['problems'], hasLength(2));

    final s = summary.readAsStringSync();
    expect(s, contains('### Checkout: 3 / 4 passed'));
    expect(s, contains('### Profile: 1 / 1 passed'));
  });

  // A real run: two cases with screenshots.
  final reportDir = '${dir.path}/run';
  setUpAll(loadFitScaleTestFonts);
  testFitScale(
    'Order screen',
    () => fitApp(const GoodScreen()),
    devices: const [FitDevices.iphoneSe1],
    textScales: const [1.0, 2.0],
    reportDir: reportDir,
  );

  test('testFitScale wrote the report with a screenshot per case', () {
    final json = jsonDecode(
      File('$reportDir/order_screen.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json['total'], 2);
    expect(json['passed'], 2);
    for (final c in json['cases'] as List) {
      final png = File('$reportDir/${c['screenshot']}');
      expect(png.existsSync(), isTrue, reason: png.path);
      final bytes = png.readAsBytesSync();
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]); // PNG
      expect(bytes.length, greaterThan(5000), reason: 'not a blank image');
    }
    expect(
      File('$reportDir/order_screen.html').readAsStringSync(),
      contains('src="order_screen/iphone_se1_x1.0.png"'),
    );
  });
}
