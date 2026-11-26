import 'package:flutter/widgets.dart';

/// How design numbers turn into real sizes.
///
/// Unlike linear scaling, every factor is clamped to
/// [minScale]..[maxScale], so a 280 px wide phone does not shrink the
/// layout to 78 % and an iPad does not blow it up to 200 %.
@immutable
class FitScaleConfig {
  const FitScaleConfig({
    this.designSize = const Size(360, 690),
    this.minScale = 0.9,
    this.maxScale = 1.25,
    this.minFontScale = 1.0,
    this.maxFontScale = 1.15,
    this.minTapTarget,
  })  : assert(minScale > 0 && minScale <= maxScale),
        assert(minFontScale > 0 && minFontScale <= maxFontScale),
        assert(minTapTarget == null || minTapTarget > 0);

  /// The frame the designer drew on (logical pixels).
  final Size designSize;

  /// Lowest and highest factor for widths, heights and uniform sizes.
  final double minScale;
  final double maxScale;

  /// Lowest and highest factor for font sizes, applied before the
  /// user's system text scale. The default 1.0 floor means fonts are
  /// never smaller than the design.
  final double minFontScale;
  final double maxFontScale;

  /// Smallest height for interactive sizes. Null picks the platform
  /// guideline: 44 on iOS and macOS, 48 everywhere else.
  final double? minTapTarget;

  FitScaleConfig copyWith({
    Size? designSize,
    double? minScale,
    double? maxScale,
    double? minFontScale,
    double? maxFontScale,
    double? minTapTarget,
  }) {
    return FitScaleConfig(
      designSize: designSize ?? this.designSize,
      minScale: minScale ?? this.minScale,
      maxScale: maxScale ?? this.maxScale,
      minFontScale: minFontScale ?? this.minFontScale,
      maxFontScale: maxFontScale ?? this.maxFontScale,
      minTapTarget: minTapTarget ?? this.minTapTarget,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FitScaleConfig &&
      other.designSize == designSize &&
      other.minScale == minScale &&
      other.maxScale == maxScale &&
      other.minFontScale == minFontScale &&
      other.maxFontScale == maxFontScale &&
      other.minTapTarget == minTapTarget;

  @override
  int get hashCode => Object.hash(
        designSize,
        minScale,
        maxScale,
        minFontScale,
        maxFontScale,
        minTapTarget,
      );
}
