import 'package:fit_scale/fit_scale.dart';
import 'package:fit_scale/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// These tests use the default Ahem test font: every glyph is exactly
// fontSize wide and tall, so expected sizes can be worked out by hand.

Widget box(double width, double height, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    );

double fontOf(WidgetTester tester) => tester
    .widget<Text>(find.descendant(
      of: find.byType(FitText),
      matching: find.byType(Text),
    ))
    .style!
    .fontSize!;

RenderParagraph paragraphOf(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.descendant(
      of: find.byType(FitText),
      matching: find.byType(RichText),
    ));

void textScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

const jd = FitText('JD', style: TextStyle(fontSize: 18));

void main() {
  testWidgets('keeps its size when it fits', (tester) async {
    await tester.pumpWidget(box(100, 50, jd)); // 2 x 18 = 36 wide
    expect(fontOf(tester), 18);
  });

  testWidgets('shrinks only as much as needed', (tester) async {
    textScale(tester, 2); // 'JD' at 18 draws 72 wide in a 50 box
    await tester.pumpWidget(box(50, 50, jd));
    // Fits when 2 glyphs x size x 2 <= 50, so size <= 12.5.
    expect(fontOf(tester), closeTo(12.5, 0.05));
    // fits() allows 0.01 px for float error in layout.
    expect(fontOf(tester) * 2 * 2, lessThanOrEqualTo(50.01));
    expect(paragraphOf(tester).didExceedMaxLines, isFalse);
  });

  testWidgets('the floor is the drawn size, system text scale included',
      (tester) async {
    textScale(tester, 2);
    // Fitting 20 px would need size 5 (drawn 10), below the 11 floor.
    await tester.pumpWidget(box(20, 50, jd));
    final drawn = paragraphOf(tester).textScaler.scale(fontOf(tester));
    expect(drawn, closeTo(11, 0.01));
    expect(paragraphOf(tester).didExceedMaxLines, isTrue,
        reason: 'still does not fit, so it ellipsizes');
  });

  testWidgets('never shrinks text that is already below the floor',
      (tester) async {
    await tester.pumpWidget(
      box(10, 10, const FitText('tiny', style: TextStyle(fontSize: 8))),
    );
    expect(fontOf(tester), 8);
  });

  testWidgets('wraps onto lines the height allows when maxLines is null',
      (tester) async {
    await tester.pumpWidget(box(
      100,
      40,
      const FitText(
        'aaaa bbbb cccc',
        maxLines: null,
        style: TextStyle(fontSize: 20), // 3 lines x 20 = 60 tall
      ),
    ));
    expect(fontOf(tester), lessThan(20));
    expect(paragraphOf(tester).size.height, lessThanOrEqualTo(40));
    expect(paragraphOf(tester).didExceedMaxLines, isFalse);
  });

  testWidgets('with unbounded width it behaves like Text', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: FitText(
          'a long line that would never fit on a phone',
          style: TextStyle(fontSize: 20),
        ),
      ),
    ));
    expect(fontOf(tester), 20);
  });

  group('truncatedText check', () {
    Widget app() => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 40,
                child: FitText(
                  'Wireless Headphones',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        );

    testWidgets('is off by default', (tester) async {
      final report = await pumpFitScreen(
        tester,
        app(),
        device: FitDevices.androidCompact,
      );
      expect(
        report.problems.where((p) => p.check == FitCheck.truncatedText),
        isEmpty,
      );
    });

    testWidgets('reports text cut off even at the minimum size',
        (tester) async {
      final report = await pumpFitScreen(
        tester,
        app(),
        device: FitDevices.androidCompact,
        checks: {...FitCheck.defaults, FitCheck.truncatedText},
      );
      final cut =
          report.problems.where((p) => p.check == FitCheck.truncatedText);
      expect(cut, hasLength(1));
      expect(cut.single.message, contains('"Wireless Headphones" is cut off'));
    });
  });
}
