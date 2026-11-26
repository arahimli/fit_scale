/// Source rewrites for `dart run fit_scale:migrate`.
///
/// Plain Dart (no Flutter), so the command-line tool can run it. Only
/// mechanical, safe edits are made; anything that needs judgement is
/// returned as a note with its line number.
library;

/// Version written into a migrated pubspec. Kept in step with
/// pubspec.yaml by a test.
const fitScaleVersion = '0.10.0';

/// Something the tool could not change safely.
class MigrationNote {
  const MigrationNote(this.line, this.message);

  /// 1-based.
  final int line;
  final String message;

  @override
  String toString() => '$line: $message';
}

/// Result for one file.
class FileMigration {
  const FileMigration({
    required this.path,
    required this.original,
    required this.migrated,
    required this.edits,
    required this.notes,
  });

  final String path;
  final String original;
  final String migrated;

  /// Short descriptions of the edits made.
  final List<String> edits;
  final List<MigrationNote> notes;

  bool get changed => migrated != original;
}

final _import = RegExp(
  r'''import\s+(['"])package:flutter_screenutil/flutter_screenutil\.dart\1([^;]*);''',
);
final _init = RegExp(r'(?<![A-Za-z0-9_$])ScreenUtilInit\s*\(');
final _instance = RegExp(r'(?<![A-Za-z0-9_$])ScreenUtil\s*\(\s*\)');

const _checks = <(String, String)>[
  (
    r'(?<![A-Za-z0-9_$.])ScreenUtil\.[a-zA-Z]',
    'static ScreenUtil call (init, configure, registerToBuild, '
        'ensureScreenSize, defaultSize) has no fit_scale counterpart: '
        'FitScaleScope or FitScreenUtilInit above the app replaces it.',
  ),
  (
    r'FitScreenUtil\(\)\s*\.\s*deviceType\b',
    'deviceType is not provided: use context.fit.windowClass.',
  ),
  (
    r'\b(REdgeInsets(Directional)?|RPadding|RSizedBox)\b',
    'screenutil R-widgets are not provided: use EdgeInsets.all(x).r, '
        'Padding or SizedBox with .w/.h/.r.',
  ),
  (
    r'\b(ScreenUtilInitBuilder|RebuildFactors?|FontSizeResolvers?)\b',
    'screenutil type not provided: FitScreenUtilInit accepts and ignores '
        'these arguments; remove the reference.',
  ),
  (
    r'SizedBox\(\s*height:\s*[\d.]+\.h\b',
    'fixed height scaled with .h: if it holds text, use FitBox(height: n), '
        'which grows with large system fonts instead of overflowing.',
  ),
  (
    r'width:\s*([\d.]+)\.w\s*,\s*height:\s*\1\.h\b',
    'square sized with .w and .h: it distorts on other aspect ratios; '
        'use FitSquare(size: n) or .r for both sides.',
  ),
];

/// Rewrites a Dart file that uses flutter_screenutil. Files that do not
/// import or call it come back unchanged and without notes.
FileMigration migrateDart(String path, String source) {
  final usesScreenUtil = _import.hasMatch(source) ||
      _init.hasMatch(source) ||
      _instance.hasMatch(source);
  if (!usesScreenUtil) {
    return FileMigration(
      path: path,
      original: source,
      migrated: source,
      edits: const [],
      notes: const [],
    );
  }

  final edits = <String>[];
  final notes = <MigrationNote>[];
  var out = source;

  var combinators = false;
  out = out.replaceAllMapped(_import, (m) {
    if (m[2]!.trim().isNotEmpty) combinators = true;
    return "import 'package:fit_scale/extensions.dart';";
  });
  if (out != source) {
    edits.add('import → package:fit_scale/extensions.dart');
    if (combinators) {
      notes.add(MigrationNote(
        _lineOf(source, _import.firstMatch(source)!.start),
        'show/hide on the screenutil import was dropped; check the names '
        'you used exist in fit_scale.',
      ));
    }
  }

  final instances = _instance.allMatches(out).length;
  if (instances > 0) {
    out = out.replaceAll(_instance, 'FitScreenUtil()');
    edits.add('ScreenUtil() → FitScreenUtil() ($instances)');
  }

  // screenutil's SU is an empty marker mixin; fit_scale needs none.
  final beforeSu = out;
  out = out
      .replaceAll(RegExp(r'\bwith\s+SU\s*,\s*'), 'with ')
      .replaceAll(RegExp(r'\s*,\s*SU\b(?=\s*(\{|,|implements\b))'), '')
      .replaceAll(RegExp(r'\s+with\s+SU\b(?=\s*(\{|implements\b))'), '');
  if (out != beforeSu) edits.add('removed the SU mixin');

  final inits = _init.allMatches(out).length;
  if (inits > 0) {
    out = out.replaceAllMapped(_init, (m) => 'Fit${m[0]}');
    edits.add('ScreenUtilInit → FitScreenUtilInit ($inits)');
  }

  for (final (pattern, message) in _checks) {
    for (final m in RegExp(pattern).allMatches(out)) {
      notes.add(MigrationNote(_lineOf(out, m.start), message));
    }
  }
  notes.sort((a, b) => a.line.compareTo(b.line));

  return FileMigration(
    path: path,
    original: source,
    migrated: out,
    edits: edits,
    notes: notes,
  );
}

final _depLine = RegExp(r'^([ \t]+)flutter_screenutil:(.*)$', multiLine: true);
final _hasFitScale = RegExp(r'^[ \t]+fit_scale:', multiLine: true);

/// Swaps the flutter_screenutil dependency for fit_scale in a pubspec.
FileMigration migratePubspec(
  String path,
  String source, {
  String version = fitScaleVersion,
}) {
  final m = _depLine.firstMatch(source);
  if (m == null) {
    return FileMigration(
      path: path,
      original: source,
      migrated: source,
      edits: const [],
      notes: const [],
    );
  }
  final notes = <MigrationNote>[];
  final value = m[2]!.trim();
  // A git, path or hosted block continues on the next, deeper lines.
  if (value.isEmpty) {
    notes.add(MigrationNote(
      _lineOf(source, m.start),
      'flutter_screenutil is declared as a block (git, path or hosted); '
      'replace it with fit_scale: ^$version by hand.',
    ));
    return FileMigration(
      path: path,
      original: source,
      migrated: source,
      edits: const [],
      notes: notes,
    );
  }

  final String out;
  final String edit;
  if (_hasFitScale.hasMatch(source)) {
    out = source.replaceRange(
      m.start,
      _endOfLine(source, m.end),
      '',
    );
    edit = 'removed flutter_screenutil (fit_scale already present)';
  } else {
    out = source.replaceRange(m.start, m.end, '${m[1]}fit_scale: ^$version');
    edit = 'flutter_screenutil → fit_scale: ^$version';
  }
  return FileMigration(
    path: path,
    original: source,
    migrated: out,
    edits: [edit],
    notes: notes,
  );
}

int _lineOf(String s, int offset) =>
    '\n'.allMatches(s.substring(0, offset)).length + 1;

/// Offset just past the newline that ends the line containing [offset].
int _endOfLine(String s, int offset) {
  final nl = s.indexOf('\n', offset);
  return nl == -1 ? s.length : nl + 1;
}
