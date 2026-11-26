import 'dart:io';

import 'package:fit_scale/src/migrate/migrator.dart';
import 'package:flutter_test/flutter_test.dart';

const before = r'''
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Home extends StatelessWidget with SU {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      builder: (context, child) => Column(children: [
        SizedBox(height: 52.h, child: const Text('Total')),
        Container(width: 56.w, height: 56.h),
        Text('w ${ScreenUtil().screenWidth}', style: TextStyle(fontSize: 14.sp)),
        RSizedBox(height: 10),
      ]),
    );
  }
}

void setup(BuildContext context) => ScreenUtil.init(context);
''';

void main() {
  group('migrateDart', () {
    final r = migrateDart('lib/home.dart', before);

    test('swaps the import', () {
      expect(
          r.migrated, contains("import 'package:fit_scale/extensions.dart';"));
      expect(r.migrated, isNot(contains('flutter_screenutil')));
    });

    test('renames ScreenUtilInit and ScreenUtil(), drops SU', () {
      expect(r.migrated, contains('return FitScreenUtilInit('));
      expect(r.migrated, contains(r'${FitScreenUtil().screenWidth}'));
      expect(r.migrated, contains('class Home extends StatelessWidget {'));
      expect(r.edits, [
        'import → package:fit_scale/extensions.dart',
        'ScreenUtil() → FitScreenUtil() (1)',
        'removed the SU mixin',
        'ScreenUtilInit → FitScreenUtilInit (1)',
      ]);
    });

    test('leaves extensions and everything else alone', () {
      expect(r.migrated, contains('SizedBox(height: 52.h'));
      expect(r.migrated, contains('fontSize: 14.sp'));
      expect(r.migrated, contains('RSizedBox(height: 10)'));
      expect(r.migrated, contains('ScreenUtil.init(context)'));
    });

    test('lists what needs a person, with line numbers', () {
      final byLine = {for (final n in r.notes) n.line: n.message};
      expect(byLine[11], contains('FitBox(height: n)'));
      expect(byLine[12], contains('FitSquare'));
      expect(byLine[14], contains('R-widgets'));
      expect(byLine[20], contains('static ScreenUtil call'));
      expect(r.notes, hasLength(4));
    });

    test('files without screenutil are untouched', () {
      const other = "import 'package:flutter/material.dart';\n"
          'final x = SizedBox(height: 52.h);\n';
      final o = migrateDart('lib/other.dart', other);
      expect(o.changed, isFalse);
      expect(o.notes, isEmpty);
    });

    test('SU in a list of mixins', () {
      final o = migrateDart(
        'a.dart',
        "import 'package:flutter_screenutil/flutter_screenutil.dart';\n"
            'class A extends StatelessWidget with Diagnosticable, SU {}\n'
            'class B extends StatelessWidget with SU, Diagnosticable {}\n',
      );
      expect(o.migrated, contains('with Diagnosticable {}'));
      expect(o.migrated,
          contains('class B extends StatelessWidget with Diagnosticable {}'));
    });

    test('show/hide on the import is reported', () {
      final o = migrateDart(
        'a.dart',
        "import 'package:flutter_screenutil/flutter_screenutil.dart' "
            'show ScreenUtil;\n',
      );
      expect(o.migrated, "import 'package:fit_scale/extensions.dart';\n");
      expect(o.notes.single.message, contains('show/hide'));
    });
  });

  group('migratePubspec', () {
    test('replaces the dependency', () {
      final r = migratePubspec(
        'pubspec.yaml',
        'dependencies:\n  flutter:\n    sdk: flutter\n'
            '  flutter_screenutil: ^5.9.3\n  http: ^1.2.0\n',
        version: '0.10.0',
      );
      expect(r.migrated,
          'dependencies:\n  flutter:\n    sdk: flutter\n  fit_scale: ^0.10.0\n  http: ^1.2.0\n');
    });

    test('removes it when fit_scale is already there', () {
      final r = migratePubspec(
        'pubspec.yaml',
        'dependencies:\n  fit_scale: ^0.9.0\n  flutter_screenutil: ^5.9.3\n',
      );
      expect(r.migrated, 'dependencies:\n  fit_scale: ^0.9.0\n');
    });

    test('a git or path block is left for a person', () {
      const src = 'dependencies:\n  flutter_screenutil:\n    path: ../\n';
      final r = migratePubspec('pubspec.yaml', src);
      expect(r.changed, isFalse);
      expect(r.notes.single.line, 2);
    });
  });

  test('fitScaleVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)![1];
    expect(fitScaleVersion, version);
  });
}
