import 'package:fit_scale/extensions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('FitScreenUtilInit builds a scope from screenutil arguments',
      (tester) async {
    setScreen(tester, const Size(744, 1133));
    late FitScaleData fit;
    Widget? gotChild;
    const child = SizedBox(key: Key('child'));
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: FitScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        child: child,
        builder: (context, c) {
          fit = context.fit;
          gotChild = c;
          return c!;
        },
      ),
    ));
    expect(fit.config.designSize, const Size(375, 812));
    expect(identical(gotChild, child), isTrue);
    expect(find.byKey(const Key('child')), findsOneWidget);
  });

  testWidgets('FitScreenUtil answers like ScreenUtil(), clamped',
      (tester) async {
    setScreen(tester, const Size(744, 1133));
    late FitScreenUtil su;
    late double w;
    await tester.pumpWidget(FitScreenUtilInit(
      builder: (context, _) {
        su = FitScreenUtil();
        w = su.setWidth(100);
        return const SizedBox();
      },
    ));
    expect(su.screenWidth, 744);
    expect(su.screenHeight, 1133);
    expect(w, 125); // 100 x 1.25 cap, not 206 as linear scaling gives
    expect(su.setSp(10), closeTo(11.5, 1e-9));
    expect(su.orientation, Orientation.portrait);
    expect(su.pixelRatio, 1);
    expect(su.setVerticalSpacing(8).height, 10);
  });

  testWidgets('screenutil-style extensions on insets, radii, constraints',
      (tester) async {
    setScreen(tester, const Size(744, 1133)); // all factors capped at 1.25
    late List<Object> values;
    await tester.pumpWidget(FitScaleScope(
      child: Builder(builder: (_) {
        values = [
          const EdgeInsets.all(8).r,
          BorderRadius.circular(8).r,
          const Radius.circular(8).w,
          const BoxConstraints(maxWidth: 100, maxHeight: 40).hw,
          16.dm,
          16.spMin,
          16.spMax,
          8.verticalSpace,
        ];
        return const SizedBox();
      }),
    ));
    expect(values[0], const EdgeInsets.all(10));
    expect(values[1], BorderRadius.circular(10));
    expect(values[2], const Radius.circular(10));
    expect(values[3], const BoxConstraints(maxWidth: 125, maxHeight: 50));
    expect(values[4], 20);
    expect(values[5], 16);
    expect(values[6], closeTo(18.4, 1e-9));
    expect((values[7] as SizedBox).height, 10);
  });
}
