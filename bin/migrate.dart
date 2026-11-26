// Migrates a project from flutter_screenutil to fit_scale.
//
//   dart run fit_scale:migrate            # dry run in the current project
//   dart run fit_scale:migrate --apply    # write the changes
//   dart run fit_scale:migrate path/to/app
//
// Only mechanical edits are made: the import, ScreenUtilInit →
// FitScreenUtilInit, and the pubspec dependency. Everything else is
// listed with its line number to check by hand.

import 'dart:io';

import 'package:fit_scale/src/migrate/migrator.dart';

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln('Usage: dart run fit_scale:migrate [--apply] [project dir]');
    return;
  }
  final apply = args.contains('--apply');
  final rest = args.where((a) => !a.startsWith('-')).toList();
  final root = Directory(rest.isEmpty ? '.' : rest.first);
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('No pubspec.yaml in ${root.absolute.path}.');
    exitCode = 64;
    return;
  }

  final results = <FileMigration>[];
  final pubspec = File('${root.path}/pubspec.yaml');
  results.add(migratePubspec('pubspec.yaml', pubspec.readAsStringSync()));

  for (final dir in ['lib', 'test', 'integration_test', 'bin']) {
    final d = Directory('${root.path}/$dir');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final path = f.path.substring(root.path.length + 1);
      if (!path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart')) {
        continue;
      }
      results.add(migrateDart(path, f.readAsStringSync()));
    }
  }

  final changed = results.where((r) => r.changed).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final notes = [
    for (final r in results)
      for (final n in r.notes) (r.path, n),
  ]..sort((a, b) {
      final p = a.$1.compareTo(b.$1);
      return p != 0 ? p : a.$2.line.compareTo(b.$2.line);
    });

  stdout
    ..writeln('fit_scale migrate'
        '${apply ? '' : ' (dry run: nothing written; pass --apply to write)'}')
    ..writeln();

  if (changed.isEmpty) {
    stdout.writeln('Nothing to change: no flutter_screenutil found.');
  } else {
    stdout.writeln('${apply ? 'Changed' : 'Would change'} '
        '${changed.length} file${changed.length == 1 ? '' : 's'}:');
    for (final r in changed) {
      stdout.writeln('  ${r.path}: ${r.edits.join('; ')}');
      if (apply) {
        File('${root.path}/${r.path}').writeAsStringSync(r.migrated);
      }
    }
  }

  if (notes.isNotEmpty) {
    stdout
      ..writeln()
      ..writeln('Check by hand (${notes.length}):');
    // One heading per kind of note, then where it occurs.
    final byMessage = <String, Map<String, List<int>>>{};
    for (final (path, n) in notes) {
      byMessage
          .putIfAbsent(n.message, () => {})
          .putIfAbsent(path, () => [])
          .add(n.line);
    }
    for (final e in byMessage.entries) {
      final count = e.value.values.fold(0, (a, l) => a + l.length);
      stdout.writeln('\n  ${e.key} ($count)');
      for (final f in e.value.entries) {
        stdout.writeln('    ${f.key}: line${f.value.length == 1 ? '' : 's'} '
            '${f.value.join(', ')}');
      }
    }
  }

  if (changed.isNotEmpty) {
    stdout
      ..writeln()
      ..writeln('Next: flutter pub get, then run testFitScale on your '
          'screens (package:fit_scale/testing.dart) to find what still '
          'breaks on small screens and large text.');
  }
}
