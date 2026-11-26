import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'data.dart';
import 'scope.dart';

/// `56.w`-style sizes, read from the root [FitScaleScope].
///
/// Same names as flutter_screenutil 5.9, so swapping its import for
/// `package:fit_scale/extensions.dart` compiles. The values are clamped
/// like everything else in fit_scale.
extension FitScaleNum on num {
  /// Horizontal design size. Same as `context.fit.w(this)`.
  double get w => _global.w(toDouble());

  /// Vertical design size. Same as `context.fit.h(this)`.
  double get h => _global.h(toDouble());

  /// Size that keeps its shape. Same as `context.fit.r(this)`.
  double get r => _global.r(toDouble());

  /// Font size. Same as `context.fit.sp(this)`.
  double get sp => _global.sp(toDouble());

  /// Height of an interactive element, never below the platform's
  /// touch-target minimum. Same as `context.fit.tap(this)`.
  double get tap => _global.tap(toDouble());

  /// Scaled by the larger of the width and height factors
  /// (screenutil's "diameter"), clamped.
  double get dm => toDouble() * _diameter;

  /// Scaled by the product of the width and height factors
  /// (screenutil's "diagonal"), clamped.
  double get dg => toDouble() * _diagonal;

  /// The smaller of the design size and [sp]. fit_scale's fonts never
  /// shrink below the design by default, so this is usually the design
  /// size itself.
  double get spMin => math.min(toDouble(), sp);

  /// Same as [spMin] (screenutil's older name).
  double get sm => spMin;

  /// The larger of the design size and [sp].
  double get spMax => math.max(toDouble(), sp);

  /// Fraction of the screen width: `0.5.sw` is half of it.
  double get sw => toDouble() * _global.size.width;

  /// Fraction of the screen height: `0.5.sh` is half of it.
  double get sh => toDouble() * _global.size.height;

  /// `SizedBox(height: this.h)`.
  SizedBox get verticalSpace => SizedBox(height: h);

  /// `SizedBox(height: this.w)`.
  SizedBox get verticalSpaceFromWidth => SizedBox(height: w);

  /// `SizedBox(width: this.w)`.
  SizedBox get horizontalSpace => SizedBox(width: w);

  /// `SizedBox(width: this.r)`.
  SizedBox get horizontalSpaceRadius => SizedBox(width: r);

  /// `SizedBox(height: this.r)`.
  SizedBox get verticalSpacingRadius => SizedBox(height: r);

  /// `SizedBox(width: this.dm)`.
  SizedBox get horizontalSpaceDiameter => SizedBox(width: dm);

  /// `SizedBox(height: this.dm)`.
  SizedBox get verticalSpacingDiameter => SizedBox(height: dm);

  /// `SizedBox(width: this.dg)`.
  SizedBox get horizontalSpaceDiagonal => SizedBox(width: dg);

  /// `SizedBox(height: this.dg)`.
  SizedBox get verticalSpacingDiagonal => SizedBox(height: dg);
}

/// screenutil's `EdgeInsets` extensions, scaled by fit_scale.
extension FitScaleEdgeInsets on EdgeInsets {
  EdgeInsets get r => _map((v) => v.r);
  EdgeInsets get dm => _map((v) => v.dm);
  EdgeInsets get dg => _map((v) => v.dg);

  /// Every side scaled by the width factor.
  EdgeInsets get w => _map((v) => v.w);

  /// Every side scaled by the height factor.
  EdgeInsets get h => _map((v) => v.h);

  EdgeInsets _map(double Function(double) f) => EdgeInsets.fromLTRB(
        f(left),
        f(top),
        f(right),
        f(bottom),
      );
}

/// screenutil's `BorderRadius` extensions, scaled by fit_scale.
extension FitScaleBorderRadius on BorderRadius {
  BorderRadius get r => _map((r) => r.r);
  BorderRadius get w => _map((r) => r.w);
  BorderRadius get h => _map((r) => r.h);

  BorderRadius _map(Radius Function(Radius) f) => BorderRadius.only(
        topLeft: f(topLeft),
        topRight: f(topRight),
        bottomLeft: f(bottomLeft),
        bottomRight: f(bottomRight),
      );
}

/// screenutil's `BoxConstraints` extensions, scaled by fit_scale.
extension FitScaleBoxConstraints on BoxConstraints {
  BoxConstraints get r => _map((v) => v.r, (v) => v.r);

  /// Widths by the width factor, heights by the height factor.
  BoxConstraints get hw => _map((v) => v.w, (v) => v.h);
  BoxConstraints get w => _map((v) => v.w, (v) => v.w);
  BoxConstraints get h => _map((v) => v.h, (v) => v.h);

  BoxConstraints _map(
    double Function(double) width,
    double Function(double) height,
  ) =>
      BoxConstraints(
        minWidth: width(minWidth),
        maxWidth: width(maxWidth),
        minHeight: height(minHeight),
        maxHeight: height(maxHeight),
      );
}

/// screenutil's `Radius` extensions, scaled by fit_scale.
extension FitScaleRadius on Radius {
  Radius get r => Radius.elliptical(x.r, y.r);
  Radius get dm => Radius.elliptical(x.dm, y.dm);
  Radius get dg => Radius.elliptical(x.dg, y.dg);
  Radius get w => Radius.elliptical(x.w, y.w);
  Radius get h => Radius.elliptical(x.h, y.h);
}

double get _diameter => math.max(_global.scaleWidth, _global.scaleHeight);

double get _diagonal {
  final g = _global;
  return (g.scaleWidth * g.scaleHeight)
      .clamp(g.config.minScale, g.config.maxScale)
      .toDouble();
}

FitScaleData get _global {
  final data = FitScale.globalForExtensions();
  if (data == null) {
    throw FlutterError.fromParts([
      ErrorSummary('No root FitScaleScope found.'),
      ErrorDescription(
        'A fit_scale extension such as 16.w was used, but no FitScaleScope '
        'without useLayoutSize is in the tree.',
      ),
      ErrorHint(
        'Wrap your app in FitScaleScope(config: FitScaleConfig('
        'designSize: Size(w, h)), child: MaterialApp(...)).',
      ),
    ]);
  }
  return data;
}
