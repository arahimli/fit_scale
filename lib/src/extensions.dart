import 'package:flutter/widgets.dart';

import 'data.dart';
import 'scope.dart';

/// `56.w`-style sizes, read from the root [FitScaleScope].
///
/// Same names as flutter_screenutil, so migrating is an import change.
/// The values are clamped like everything else in fit_scale.
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

  /// Fraction of the screen width: `0.5.sw` is half of it.
  double get sw => toDouble() * _global.size.width;

  /// Fraction of the screen height: `0.5.sh` is half of it.
  double get sh => toDouble() * _global.size.height;

  /// `SizedBox(height: this.h)`.
  Widget get verticalSpace => SizedBox(height: h);

  /// `SizedBox(width: this.w)`.
  Widget get horizontalSpace => SizedBox(width: w);
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
