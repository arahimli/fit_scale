import 'dart:convert';
import 'dart:io';

import '../breakpoints.dart';
import 'devices.dart';
import 'harness.dart';

/// One device and text size of a [FitScreenReport].
class FitCaseResult {
  const FitCaseResult(this.report, {this.screenshot});

  final FitReport report;

  /// Path of the case's PNG relative to the report directory, if taken.
  final String? screenshot;
}

/// Every case of one screen, as rendered by `testFitScale`.
///
/// `testFitScale(reportDir: ...)` builds and writes one for you; build
/// your own from `pumpFitScreen` results to write custom reports.
class FitScreenReport {
  FitScreenReport(this.name, [List<FitCaseResult>? cases])
      : cases = cases ?? [];

  final String name;
  final List<FitCaseResult> cases;

  int get total => cases.length;
  int get passed => cases.where((c) => c.report.passed).length;

  /// File-name-safe form of [name].
  String get slug {
    final s = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final trimmed = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'screen' : trimmed;
  }

  List<FitDevice> get _devices {
    final seen = <String>{};
    return [
      for (final c in cases)
        if (seen.add(c.report.device.name)) c.report.device,
    ];
  }

  List<double> get _scales {
    final seen = <double>{};
    return [
      for (final c in cases)
        if (seen.add(c.report.textScale)) c.report.textScale,
    ];
  }

  FitCaseResult? _at(FitDevice d, double scale) {
    for (final c in cases) {
      if (c.report.device.name == d.name && c.report.textScale == scale) {
        return c;
      }
    }
    return null;
  }

  static String _size(FitDevice d) =>
      '${d.size.width.toStringAsFixed(0)}×${d.size.height.toStringAsFixed(0)}';

  static String _class(FitDevice d) =>
      const FitBreakpoints().widthClass(d.size.width).name;

  static String _scale(double s) => '×${s.toStringAsFixed(1)}';

  static const _short = {
    FitCheck.overflow: 'overflow',
    FitCheck.tapTargets: 'tap',
    FitCheck.minFont: 'font',
    FitCheck.truncatedText: 'cut',
  };

  /// "2 overflow · 1 tap" for a failed case.
  static String _counts(FitReport r) {
    final counts = <FitCheck, int>{};
    for (final p in r.problems) {
      counts[p.check] = (counts[p.check] ?? 0) + 1;
    }
    return [
      for (final e in counts.entries) '${e.value} ${_short[e.key]}',
    ].join(' · ');
  }

  /// A table of devices × text sizes plus the problems of each failed
  /// case. Fits a pull request comment or a CI job summary.
  String toMarkdown() {
    final scales = _scales;
    final b = StringBuffer()
      ..writeln('### ${_md(name)}: $passed / $total passed')
      ..writeln()
      ..writeln(
        '| Device | Class | ${scales.map((s) => 'Text ${_scale(s)}').join(' | ')} |',
      )
      ..writeln('|---|---|${'---|' * scales.length}');
    for (final d in _devices) {
      final cells = [
        for (final s in scales)
          switch (_at(d, s)) {
            null => '–',
            final c when c.report.passed => '✓',
            final c => '✗ ${_counts(c.report)}',
          },
      ];
      b.writeln(
          '| ${d.name} ${_size(d)} | ${_class(d)} | ${cells.join(' | ')} |');
    }
    final failed = cases.where((c) => !c.report.passed).toList();
    if (failed.isNotEmpty) {
      b
        ..writeln()
        ..writeln('<details><summary>Problems in ${failed.length} '
            'case${failed.length == 1 ? '' : 's'}</summary>')
        ..writeln();
      for (final c in failed) {
        b.writeln('**${c.report.device.name} ${_size(c.report.device)}, '
            'text ${_scale(c.report.textScale)}**');
        for (final p in c.report.problems) {
          b.writeln('- `${p.check.name}` ${_md(p.message)}');
        }
        b.writeln();
      }
      b.writeln('</details>');
    }
    return b.toString();
  }

  /// A self-contained page: the same table with a screenshot per case
  /// (when taken) and every problem listed below it.
  String toHtml() {
    final scales = _scales;
    final b = StringBuffer()
      ..write(_htmlHead(name))
      ..writeln('<h1>${_html(name)}</h1>')
      ..writeln('<p class="sum ${passed == total ? 'ok' : 'bad'}">'
          '$passed / $total cases passed</p>')
      ..writeln('<table><thead><tr><th>Device</th>')
      ..writeln(scales.map((s) => '<th>Text ${_scale(s)}</th>').join())
      ..writeln('</tr></thead><tbody>');
    for (final d in _devices) {
      b.writeln('<tr><th class="dev">${_html(d.name)}<br>'
          '<span>${_size(d)} · ${_class(d)}</span></th>');
      for (final s in scales) {
        final c = _at(d, s);
        if (c == null) {
          b.writeln('<td>–</td>');
          continue;
        }
        final id = _id(c);
        final ok = c.report.passed;
        final shot = c.screenshot == null
            ? ''
            : '<a href="${_html(c.screenshot!)}"><img loading="lazy" '
                'src="${_html(c.screenshot!)}" alt="${_html(d.name)} '
                'text ${_scale(s)}"></a>';
        final label = ok
            ? '<span class="tag ok">✓ ok</span>'
            : '<a class="tag bad" href="#$id">✗ ${_html(_counts(c.report))}</a>';
        b.writeln('<td>$shot$label</td>');
      }
      b.writeln('</tr>');
    }
    b.writeln('</tbody></table>');
    final failed = cases.where((c) => !c.report.passed).toList();
    if (failed.isNotEmpty) b.writeln('<h2>Problems</h2>');
    for (final c in failed) {
      b
        ..writeln('<section id="${_id(c)}"><h3>${_html(c.report.device.name)} '
            '${_size(c.report.device)}, text ${_scale(c.report.textScale)}'
            '</h3><ul>')
        ..writeln(c.report.problems
            .map((p) => '<li><code>${p.check.name}</code> '
                '${_html(p.message)}</li>')
            .join())
        ..writeln('</ul></section>');
    }
    b.writeln('</body></html>');
    return b.toString();
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'slug': slug,
        'passed': passed,
        'total': total,
        'cases': [
          for (final c in cases)
            {
              'device': c.report.device.name,
              'width': c.report.device.size.width,
              'height': c.report.device.size.height,
              'windowClass': _class(c.report.device),
              'textScale': c.report.textScale,
              'passed': c.report.passed,
              'screenshot': c.screenshot,
              'problems': [
                for (final p in c.report.problems)
                  {'check': p.check.name, 'message': p.message},
              ],
            },
        ],
      };

  static String _id(FitCaseResult c) =>
      'case-${c.report.device.name}-${c.report.textScale}'.replaceAll('.', '_');
}

/// Writes [report] as `<slug>.html`, `<slug>.md` and `<slug>.json` in
/// [dir], rebuilds `index.html` from every screen report there, and
/// appends the markdown to [summaryPath] (by default GitHub Actions'
/// `GITHUB_STEP_SUMMARY`, when set).
void writeFitReport(FitScreenReport report, String dir, {String? summaryPath}) {
  final out = Directory(dir)..createSync(recursive: true);
  final slug = report.slug;
  File('${out.path}/$slug.html').writeAsStringSync(report.toHtml());
  File('${out.path}/$slug.md').writeAsStringSync(report.toMarkdown());
  File('${out.path}/$slug.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );
  _writeIndex(out);

  final summary = summaryPath ?? Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summary != null && summary.isNotEmpty) {
    File(summary).writeAsStringSync(
      '${report.toMarkdown()}\n',
      mode: FileMode.append,
    );
  }
}

void _writeIndex(Directory dir) {
  final screens = <Map<String, dynamic>>[];
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    try {
      final data = jsonDecode(f.readAsStringSync());
      if (data is Map<String, dynamic> && data['cases'] is List) {
        screens.add(data);
      }
    } on FormatException {
      // Not one of ours.
    }
  }
  screens.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
  final b = StringBuffer()
    ..write(_htmlHead('fit_scale report'))
    ..writeln('<h1>fit_scale report</h1>')
    ..writeln('<table><thead><tr><th>Screen</th><th>Passed</th></tr>'
        '</thead><tbody>');
  for (final s in screens) {
    final ok = s['passed'] == s['total'];
    b.writeln('<tr><th class="dev"><a href="${_html('${s['slug']}')}.html">'
        '${_html('${s['name']}')}</a></th><td><span class="tag '
        '${ok ? 'ok' : 'bad'}">${s['passed']} / ${s['total']}</span></td></tr>');
  }
  b.writeln('</tbody></table></body></html>');
  File('${dir.path}/index.html').writeAsStringSync(b.toString());
}

String _htmlHead(String title) => '''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_html(title)}</title>
<style>
:root{--bg:#fff;--fg:#202124;--muted:#5f6368;--line:#dadce0;--ok:#1e8c46;--bad:#c62828;--okbg:#e6f4ea;--badbg:#fce8e6}
@media (prefers-color-scheme:dark){:root{--bg:#1f1f1f;--fg:#e8eaed;--muted:#9aa0a6;--line:#3c4043;--ok:#81c995;--bad:#f28b82;--okbg:#1e3a29;--badbg:#4a2421}}
body{margin:0;padding:24px 16px;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
h1{font-size:22px;margin:0 0 4px}h2{font-size:18px;margin:32px 0 8px}h3{font-size:15px;margin:16px 0 4px}
.sum{margin:0 0 16px;font-weight:600}.sum.ok{color:var(--ok)}.sum.bad{color:var(--bad)}
table{border-collapse:collapse;display:block;overflow-x:auto;max-width:100%}
th,td{border:1px solid var(--line);padding:8px;vertical-align:top;text-align:left}
th.dev{white-space:nowrap}th.dev span{font-weight:400;color:var(--muted);font-size:12px}
td img{display:block;height:180px;width:auto;border:1px solid var(--line);margin-bottom:6px}
.tag{display:inline-block;padding:1px 8px;border-radius:10px;font-size:12px;font-weight:600;text-decoration:none;white-space:nowrap}
.tag.ok{background:var(--okbg);color:var(--ok)}.tag.bad{background:var(--badbg);color:var(--bad)}
a{color:inherit}code{font-size:12px;color:var(--muted)}ul{margin:4px 0;padding-left:20px}
</style></head><body>
''';

String _html(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Markdown is rendered as HTML by GitHub, so keep tags inert.
String _md(String s) => s.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
