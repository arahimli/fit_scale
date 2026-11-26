import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'config.dart';
import 'data.dart';
import 'scope.dart';

/// The `ScreenUtil()` instance API, answered by fit_scale's root scope,
/// so `ScreenUtil().setWidth(10)` keeps working after
/// `dart run fit_scale:migrate` renames it to `FitScreenUtil()`.
///
/// Sizes are clamped like the rest of fit_scale. Screen metrics come from
/// the app's view. Static screenutil calls (`ScreenUtil.init`,
/// `registerToBuild`, `ensureScreenSize`) have no counterpart: use
/// `FitScaleScope`.
class FitScreenUtil {
  factory FitScreenUtil() => const FitScreenUtil._();
  const FitScreenUtil._();

  FitScaleData get _fit {
    final data = FitScale.global;
    if (data == null) {
      throw FlutterError(
        'FitScreenUtil() needs a FitScaleScope (or FitScreenUtilInit) '
        'above the app.',
      );
    }
    return data;
  }

  MediaQueryData get _media => MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.implicitView ??
            WidgetsBinding.instance.platformDispatcher.views.first,
      );

  double get screenWidth => _fit.size.width;
  double get screenHeight => _fit.size.height;
  double get scaleWidth => _fit.scaleWidth;
  double get scaleHeight => _fit.scaleHeight;
  double get scaleText => _fit.fontScale;
  Orientation get orientation =>
      screenWidth > screenHeight ? Orientation.landscape : Orientation.portrait;
  double get pixelRatio => _media.devicePixelRatio;
  double get statusBarHeight => _media.padding.top;
  double get bottomBarHeight => _media.padding.bottom;

  /// The user's system text scale for a 1.0 font (screenutil's name).
  double get textScaleFactor => _media.textScaler.scale(1);

  double setWidth(num width) => _fit.w(width.toDouble());
  double setHeight(num height) => _fit.h(height.toDouble());
  double setSp(num fontSize) => _fit.sp(fontSize.toDouble());
  double radius(num r) => _fit.r(r.toDouble());
  double diameter(num d) => d * math.max(_fit.scaleWidth, _fit.scaleHeight);
  double diagonal(num d) =>
      d *
      (_fit.scaleWidth * _fit.scaleHeight)
          .clamp(_fit.config.minScale, _fit.config.maxScale)
          .toDouble();

  SizedBox setVerticalSpacing(num height) =>
      SizedBox(height: setHeight(height));
  SizedBox setVerticalSpacingFromWidth(num height) =>
      SizedBox(height: setWidth(height));
  SizedBox setHorizontalSpacing(num width) => SizedBox(width: setWidth(width));
  SizedBox setHorizontalSpacingRadius(num width) =>
      SizedBox(width: radius(width));
  SizedBox setVerticalSpacingRadius(num height) =>
      SizedBox(height: radius(height));
  SizedBox setHorizontalSpacingDiameter(num width) =>
      SizedBox(width: diameter(width));
  SizedBox setVerticalSpacingDiameter(num height) =>
      SizedBox(height: diameter(height));
  SizedBox setHorizontalSpacingDiagonal(num width) =>
      SizedBox(width: diagonal(width));
  SizedBox setVerticalSpacingDiagonal(num height) =>
      SizedBox(height: diagonal(height));
}

/// Builds a [FitScaleScope] from `ScreenUtilInit`'s arguments, so code
/// migrated from flutter_screenutil compiles with one rename:
/// `ScreenUtilInit(` → `FitScreenUtilInit(` (which
/// `dart run fit_scale:migrate` does for you).
///
/// [designSize], [builder] and [child] work as in screenutil. The other
/// screenutil arguments are accepted so the call still compiles, and
/// ignored: fit_scale always clamps, never shrinks fonts below the
/// design, and rebuilds through `context.fit`. Replace this with a
/// plain [FitScaleScope] when convenient.
class FitScreenUtilInit extends StatelessWidget {
  const FitScreenUtilInit({
    super.key,
    this.designSize = const Size(360, 690),
    this.builder,
    this.child,
    this.config,
    this.minTextAdapt,
    this.splitScreenMode,
    this.useInheritedMediaQuery,
    this.ensureScreenSize,
    this.enableScaleWH,
    this.enableScaleText,
    this.rebuildFactor,
    this.fontSizeResolver,
    this.responsiveWidgets,
    this.excludeWidgets,
  }) : assert(builder != null || child != null);

  final Size designSize;

  /// Called with this widget's context and [child], as in screenutil.
  final Widget Function(BuildContext context, Widget? child)? builder;
  final Widget? child;

  /// Other fit_scale settings; its design size is replaced by
  /// [designSize].
  final FitScaleConfig? config;

  // Accepted for source compatibility, ignored.
  final bool? minTextAdapt;
  final bool? splitScreenMode;
  final bool? useInheritedMediaQuery;
  final bool? ensureScreenSize;
  final Object? enableScaleWH;
  final Object? enableScaleText;
  final Object? rebuildFactor;
  final Object? fontSizeResolver;
  final Object? responsiveWidgets;
  final Object? excludeWidgets;

  @override
  Widget build(BuildContext context) {
    return FitScaleScope(
      config: (config ?? const FitScaleConfig()).copyWith(
        designSize: designSize,
      ),
      child: builder == null
          ? child!
          : Builder(builder: (context) => builder!(context, child)),
    );
  }
}
