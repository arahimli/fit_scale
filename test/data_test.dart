import 'package:fit_scale/fit_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FitScaleData data(Size size,
        {TargetPlatform platform = TargetPlatform.android,
        FitScaleConfig config = const FitScaleConfig()}) =>
    FitScaleData(config: config, size: size, platform: platform);

void main() {
  test('design size scales by exactly 1', () {
    final d = data(const Size(360, 690));
    expect(d.w(16), 16);
    expect(d.h(16), 16);
    expect(d.r(16), 16);
    expect(d.sp(16), 16);
  });

  test('small screen is clamped instead of shrinking linearly', () {
    final d = data(const Size(280, 653)); // raw width factor 0.78
    expect(d.scaleWidth, 0.9);
    expect(d.scale, 0.9);
    expect(d.scaleHeight, closeTo(653 / 690, 1e-9));
  });

  test('fonts never go below the design size by default', () {
    expect(data(const Size(280, 653)).sp(11), 11);
    expect(data(const Size(320, 568)).sp(11), 11);
  });

  test('large screen is capped', () {
    final d = data(const Size(744, 1133));
    expect(d.scaleWidth, 1.25);
    expect(d.scale, 1.25);
    expect(d.fontScale, 1.15);
  });

  test('uniform scale does not jump on rotation', () {
    final portrait = data(const Size(402, 874));
    final landscape = data(const Size(874, 402));
    expect(landscape.scale, portrait.scale);
    expect(landscape.fontScale, portrait.fontScale);
    expect(landscape.scaleHeight, 0.9); // 402 / 690 clamped
  });

  test('tap height has a platform floor', () {
    final small = const Size(280, 653);
    expect(data(small).tap(40), 48);
    expect(data(small, platform: TargetPlatform.iOS).tap(40), 44);
    expect(data(const Size(744, 1133)).tap(48), 60);
    expect(
      data(small, config: const FitScaleConfig(minTapTarget: 56)).tap(40),
      56,
    );
  });

  test('clamped honours min and max', () {
    final d = data(const Size(744, 1133)); // scale 1.25
    expect(d.clamped(40, max: 44), 44);
    expect(data(const Size(280, 653)).clamped(40, min: 40), 40);
  });

  test('zero size does not produce NaN', () {
    final d = data(Size.zero);
    expect(d.w(10), 9);
    expect(d.sp(10), 10);
  });

  test('equality follows config, size and platform', () {
    expect(data(const Size(400, 800)), data(const Size(400, 800)));
    expect(data(const Size(400, 800)) == data(const Size(401, 800)), isFalse);
  });

  test('isCompact', () {
    expect(data(const Size(402, 874)).isCompact, isTrue);
    expect(data(const Size(744, 1133)).isCompact, isFalse);
  });
}
