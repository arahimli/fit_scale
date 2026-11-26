import 'package:flutter/widgets.dart';

import 'scope.dart';

/// Scales every font below it by the screen's font factor, so text
/// styles keep their design sizes and nothing needs `fit.sp`.
///
/// It sets the ambient text scaler (`MediaQuery.textScalerOf`) to the
/// font factor composed with the user's system text size, which every
/// `Text` uses: Material and Cupertino themes, your own styles, and
/// `FitText` all follow, with no dependency on any theme class.
///
/// ```dart
/// FitScaleScope(
///   child: MaterialApp(
///     builder: (context, child) => FitTextScale(child: child!),
///     home: const CheckoutPage(),
///   ),
/// )
/// ```
///
/// Below it, write plain font sizes (`fontSize: 14`), not `fit.sp(14)`:
/// that would apply the factor twice.
class FitTextScale extends StatelessWidget {
  const FitTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = context.fit.fontScale;
    final media = MediaQuery.of(context);
    final system = media.textScaler;
    // Already applied by a FitTextScale higher up: do not compound.
    if (system is FitTextScaler) return child;
    return MediaQuery(
      data: media.copyWith(textScaler: FitTextScaler(system, factor)),
      child: child,
    );
  }
}

/// The system text scaler applied after a design font factor.
///
/// The factor goes first so a non-linear system scaler (Android 14+)
/// still sees the size it would see in a hand-scaled layout.
@immutable
class FitTextScaler extends TextScaler {
  const FitTextScaler(this.system, this.factor);

  /// The user's text size setting.
  final TextScaler system;

  /// The design font factor, `FitScaleData.fontScale`.
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize * factor);

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => system.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is FitTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);

  @override
  String toString() => 'FitTextScaler(×$factor, $system)';
}
