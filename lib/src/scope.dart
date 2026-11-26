import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'data.dart';

/// Provides [FitScaleData] to everything below it.
///
/// Put one above your app (or above `MaterialApp.home`). Nest another
/// with [useLayoutSize] to scale a pane by its own size instead of the
/// screen's, for split views and tablets.
///
/// There is no global singleton: widgets read sizes through
/// `context.fit` and rebuild only when the size actually changes.
class FitScaleScope extends StatelessWidget {
  const FitScaleScope({
    super.key,
    this.config = const FitScaleConfig(),
    this.useLayoutSize = false,
    required this.child,
  });

  final FitScaleConfig config;

  /// Scale by the space this widget gets from its parent instead of
  /// the whole screen.
  final bool useLayoutSize;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    if (!useLayoutSize) return _provide(screen);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded axes (inside a scroll view) fall back to the screen.
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : screen.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : screen.height,
        );
        return _provide(size);
      },
    );
  }

  Widget _provide(Size size) {
    return _FitScaleInherited(
      data: FitScaleData(
        config: config,
        size: size,
        platform: defaultTargetPlatform,
      ),
      child: child,
    );
  }
}

class _FitScaleInherited extends InheritedWidget {
  const _FitScaleInherited({required this.data, required super.child});

  final FitScaleData data;

  @override
  bool updateShouldNotify(_FitScaleInherited old) => data != old.data;
}

/// Lookup helpers for [FitScaleData].
abstract final class FitScale {
  /// The nearest [FitScaleData]. Throws if there is no [FitScaleScope].
  static FitScaleData of(BuildContext context) {
    final data = maybeOf(context);
    if (data == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No FitScaleScope found.'),
        ErrorDescription(
          '${context.widget.runtimeType} read context.fit, but there is no '
          'FitScaleScope above it.',
        ),
        ErrorHint(
          'Wrap your app in FitScaleScope(config: FitScaleConfig('
          'designSize: Size(w, h)), child: ...).',
        ),
      ]);
    }
    return data;
  }

  /// The nearest [FitScaleData], or null.
  static FitScaleData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FitScaleInherited>()?.data;
}

extension FitScaleContext on BuildContext {
  /// Scale factors for this place in the tree.
  FitScaleData get fit => FitScale.of(this);
}
