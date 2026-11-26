import 'report.dart';

/// How one device and text size changed since the baseline.
enum FitChangeKind {
  /// Passed in the baseline, fails now.
  regressed,

  /// Failed in the baseline, passes now.
  fixed,

  /// Failed in both, with different problems.
  changed,

  /// Not in the baseline.
  added,

  /// In the baseline, not run now.
  removed,
}

/// One case that is not the same as in the baseline.
class FitCaseChange {
  const FitCaseChange({
    required this.kind,
    required this.device,
    required this.textScale,
    required this.before,
    required this.after,
  });

  final FitChangeKind kind;
  final String device;
  final double textScale;

  /// Problem messages in the baseline and now.
  final List<String> before;
  final List<String> after;

  /// Problems that appeared since the baseline.
  List<String> get appeared => [
        for (final p in after)
          if (!before.contains(p)) p,
      ];

  /// Problems that went away since the baseline.
  List<String> get resolved => [
        for (final p in before)
          if (!after.contains(p)) p,
      ];
}

/// A [FitScreenReport] compared with an earlier run of the same screen,
/// read from that run's `<screen>.json`.
class FitReportDiff {
  FitReportDiff._(this.changes);

  /// Compares [current] with [baseline], the decoded JSON of an earlier
  /// [FitScreenReport.toJson].
  factory FitReportDiff(
    Map<String, dynamic> baseline,
    FitScreenReport current,
  ) {
    String key(String device, double scale) => '$device@$scale';

    final before = <String, List<String>>{};
    final beforeOrder = <String, (String, double)>{};
    for (final c in (baseline['cases'] as List? ?? const [])) {
      final m = c as Map<String, dynamic>;
      final device = '${m['device']}';
      final scale = (m['textScale'] as num).toDouble();
      final k = key(device, scale);
      before[k] = [
        for (final p in (m['problems'] as List? ?? const []))
          '${(p as Map)['check']}: ${p['message']}',
      ];
      beforeOrder[k] = (device, scale);
    }

    final changes = <FitCaseChange>[];
    final seen = <String>{};
    for (final c in current.cases) {
      final device = c.report.device.name;
      final scale = c.report.textScale;
      final k = key(device, scale);
      seen.add(k);
      final now = [
        for (final p in c.report.problems) '${p.check.name}: ${p.message}',
      ];
      final was = before[k];
      final kind = switch (was) {
        null => FitChangeKind.added,
        _ when was.isEmpty && now.isNotEmpty => FitChangeKind.regressed,
        _ when was.isNotEmpty && now.isEmpty => FitChangeKind.fixed,
        _ when !_sameSet(was, now) => FitChangeKind.changed,
        _ => null,
      };
      if (kind == null) continue;
      changes.add(FitCaseChange(
        kind: kind,
        device: device,
        textScale: scale,
        before: was ?? const [],
        after: now,
      ));
    }
    for (final e in beforeOrder.entries) {
      if (seen.contains(e.key)) continue;
      changes.add(FitCaseChange(
        kind: FitChangeKind.removed,
        device: e.value.$1,
        textScale: e.value.$2,
        before: before[e.key]!,
        after: const [],
      ));
    }
    return FitReportDiff._(List.unmodifiable(changes));
  }

  final List<FitCaseChange> changes;

  Iterable<FitCaseChange> of(FitChangeKind kind) =>
      changes.where((c) => c.kind == kind);

  bool get hasRegressions => changes.any((c) =>
      c.kind == FitChangeKind.regressed ||
      (c.kind == FitChangeKind.changed && c.appeared.isNotEmpty));

  /// "2 regressed · 1 fixed", or "no changes".
  String get summary {
    if (changes.isEmpty) return 'no changes';
    return [
      for (final kind in FitChangeKind.values)
        if (of(kind).isNotEmpty) '${of(kind).length} ${kind.name}',
    ].join(' · ');
  }

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('#### Since baseline: $summary')
      ..writeln();
    if (changes.isEmpty) return b.toString();
    for (final c in changes) {
      final icon = switch (c.kind) {
        FitChangeKind.regressed => '🔴',
        FitChangeKind.fixed => '🟢',
        FitChangeKind.changed => '🟡',
        FitChangeKind.added => '➕',
        FitChangeKind.removed => '➖',
      };
      b.writeln('- $icon **${c.kind.name}** ${c.device}, text '
          '×${c.textScale.toStringAsFixed(1)}');
      for (final p in c.appeared) {
        b.writeln('  - new: ${_md(p)}');
      }
      for (final p in c.resolved) {
        b.writeln('  - gone: ${_md(p)}');
      }
    }
    return b.toString();
  }

  /// A `<section>` for the screen's HTML page.
  String toHtml() {
    final b = StringBuffer()
      ..writeln('<section class="diff"><h2>Since baseline: '
          '${_html(summary)}</h2>');
    if (changes.isNotEmpty) b.writeln('<ul>');
    for (final c in changes) {
      final cls = switch (c.kind) {
        FitChangeKind.regressed => 'bad',
        FitChangeKind.fixed => 'ok',
        _ => '',
      };
      b.writeln('<li><span class="tag $cls">${c.kind.name}</span> '
          '${_html(c.device)}, text ×${c.textScale.toStringAsFixed(1)}');
      final items = [
        for (final p in c.appeared) '<li>new: ${_html(p)}</li>',
        for (final p in c.resolved) '<li>gone: ${_html(p)}</li>',
      ];
      if (items.isNotEmpty) b.writeln('<ul>${items.join()}</ul>');
      b.writeln('</li>');
    }
    if (changes.isNotEmpty) b.writeln('</ul>');
    b.writeln('</section>');
    return b.toString();
  }
}

bool _sameSet(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

String _html(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _md(String s) => s.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
