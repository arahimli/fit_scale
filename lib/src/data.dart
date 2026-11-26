import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'config.dart';

/// Scale factors for one screen (or one pane) size.
///
/// Get it with `context.fit` below a [FitScaleScope].
@immutable
class FitScaleData {
  const FitScaleData._({
    required this.config,
    required this.size,
    required this.platform,
    required this.scaleWidth,
    required this.scaleHeight,
    required this.scale,
    required this.fontScale,
  });

  factory FitScaleData({
    required FitScaleConfig config,
    required Size size,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    final design = config.designSize;
    assert(!design.isEmpty, 'designSize must not be empty');

    double clamp(double v) => v.isFinite
        ? v.clamp(config.minScale, config.maxScale)
        : config.minScale;

    // Uniform and font factors use the shortest side, so they do not
    // jump when the device rotates.
    final shortest = size.shortestSide / design.shortestSide;

    return FitScaleData._(
      config: config,
      size: size,
      platform: platform,
      scaleWidth: clamp(size.width / design.width),
      scaleHeight: clamp(size.height / design.height),
      scale: clamp(shortest),
      fontScale: shortest.isFinite
          ? shortest.clamp(config.minFontScale, config.maxFontScale)
          : config.minFontScale,
    );
  }

  final FitScaleConfig config;

  /// The size the factors were computed from.
  final Size size;
  final TargetPlatform platform;

  /// Clamped factor for horizontal sizes.
  final double scaleWidth;

  /// Clamped factor for vertical sizes.
  final double scaleHeight;

  /// Clamped factor for sizes that must keep their shape
  /// (squares, circles, radii, icons, touch targets).
  final double scale;

  /// Clamped factor for font sizes. The system text scale is applied
  /// on top of this by Flutter, so do not multiply it in yourself.
  final double fontScale;

  /// A horizontal design size (padding, widths).
  double w(double v) => v * scaleWidth;

  /// A vertical design size (gaps, heights of non-text boxes).
  double h(double v) => v * scaleHeight;

  /// A size that keeps its shape on any aspect ratio.
  double r(double v) => v * scale;

  /// A font size. Never below the design size by default.
  double sp(double v) => v * fontScale;

  /// Smallest height an interactive element may have here.
  double get minTapTarget =>
      config.minTapTarget ??
      switch (platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 44.0,
        _ => 48.0,
      };

  /// Height for a button, tile or other interactive element:
  /// the uniform size, but never below [minTapTarget].
  double tap(double v) => math.max(r(v), minTapTarget);

  /// A uniform size with your own floor and ceiling.
  double clamped(double v, {double? min, double? max}) {
    var out = r(v);
    if (min != null && out < min) out = min;
    if (max != null && out > max) out = max;
    return out;
  }

  /// Shortest side below 600 (phones, foldable covers), whatever the
  /// orientation. For layout decisions use [windowClass], which follows
  /// the width.
  bool get isCompact => size.shortestSide < 600;

  /// Width class of this screen or pane.
  FitWindowClass get windowClass => config.breakpoints.widthClass(size.width);

  /// Height class of this screen or pane.
  FitHeightClass get heightClass => config.breakpoints.heightClass(size.height);

  /// Builds the result for the current [windowClass].
  ///
  /// Mobile first: a class without a builder uses the nearest narrower
  /// one, down to [compact]. Only the chosen builder runs.
  ///
  /// ```dart
  /// fit.when(compact: () => OneColumn(), expanded: () => TwoColumns())
  /// ```
  T when<T>({
    required T Function() compact,
    T Function()? medium,
    T Function()? expanded,
    T Function()? large,
    T Function()? extraLarge,
  }) {
    final builders = [compact, medium, expanded, large, extraLarge];
    for (var i = windowClass.index; i >= 0; i--) {
      final builder = builders[i];
      if (builder != null) return builder();
    }
    return compact();
  }

  /// A value for the current [windowClass], with the same fallback as
  /// [when]: `fit.pick(compact: 1, medium: 2, expanded: 3)` columns.
  T pick<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? large,
    T? extraLarge,
  }) {
    final values = [compact, medium, expanded, large, extraLarge];
    for (var i = windowClass.index; i >= 0; i--) {
      final value = values[i];
      if (value != null) return value;
    }
    return compact;
  }

  @override
  bool operator ==(Object other) =>
      other is FitScaleData &&
      other.config == config &&
      other.size == size &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(config, size, platform);

  @override
  String toString() => 'FitScaleData(size: $size, w: '
      '${scaleWidth.toStringAsFixed(3)}, h: ${scaleHeight.toStringAsFixed(3)}, '
      'r: ${scale.toStringAsFixed(3)}, sp: ${fontScale.toStringAsFixed(3)})';
}
