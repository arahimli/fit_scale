import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// Needed on Flutter 3.24, where foundation.dart does not export @internal.
// ignore: unnecessary_import
import 'package:meta/meta.dart';

import 'breakpoints.dart';
import 'config.dart';
import 'data.dart';
import 'hinge.dart';

/// Provides [FitScaleData] to everything below it.
///
/// Put one above your app (or above `MaterialApp.home`). Nest another
/// with [useLayoutSize] to scale a pane by its own size instead of the
/// screen's, for split views and tablets.
///
/// Widgets read sizes through `context.fit` and rebuild only when the
/// size actually changes. The root scope (one without [useLayoutSize])
/// also publishes its data as [FitScale.global] for the optional
/// `56.w`-style extensions in `package:fit_scale/extensions.dart`; when
/// that data changes it rebuilds its whole subtree, because extension
/// calls have no `context` to depend on.
class FitScaleScope extends StatefulWidget {
  const FitScaleScope({
    super.key,
    this.config = const FitScaleConfig(),
    this.useLayoutSize = false,
    required this.child,
  });

  final FitScaleConfig config;

  /// Scale by the space this widget gets from its parent instead of
  /// the whole screen. Such a scope never becomes [FitScale.global].
  final bool useLayoutSize;

  final Widget child;

  @override
  State<FitScaleScope> createState() => _FitScaleScopeState();
}

class _FitScaleScopeState extends State<FitScaleScope> {
  /// Data this scope last published as [FitScale.global].
  FitScaleData? _published;

  @override
  void dispose() {
    if (_published != null && identical(FitScale._global, _published)) {
      FitScale._global = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    if (!widget.useLayoutSize) {
      final data = _data(
        screen,
        displayFeatures: MediaQuery.displayFeaturesOf(context),
      );
      _publish(context, data);
      return _FitScaleInherited(data: data, child: widget.child);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbounded axes (inside a scroll view) fall back to the screen.
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : screen.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : screen.height,
        );
        return _FitScaleInherited(data: _data(size), child: widget.child);
      },
    );
  }

  FitScaleData _data(
    Size size, {
    List<ui.DisplayFeature> displayFeatures = const [],
  }) =>
      FitScaleData(
        config: widget.config,
        size: size,
        platform: defaultTargetPlatform,
        displayFeatures: displayFeatures,
      );

  void _publish(BuildContext context, FitScaleData data) {
    final changed = _published != null && _published != data;
    _published = data;
    FitScale._global = data;
    if (changed && FitScale._extensionsUsed) {
      // Extension calls (`16.w`) do not register a dependency, so mark
      // every descendant dirty. Allowed during build because they are
      // all below the widget being built. Skipped entirely in apps that
      // only use context.fit.
      void markDirty(Element element) {
        element.markNeedsBuild();
        element.visitChildren(markDirty);
      }

      (context as Element).visitChildren(markDirty);
    }
  }
}

enum _Aspect { classes, hinge }

class _FitScaleInherited extends InheritedModel<_Aspect> {
  const _FitScaleInherited({required this.data, required super.child});

  final FitScaleData data;

  @override
  bool updateShouldNotify(_FitScaleInherited old) => data != old.data;

  /// Widgets that only asked for the window or height class rebuild only
  /// when a class changes, not on every pixel of a resize.
  @override
  bool updateShouldNotifyDependent(
    _FitScaleInherited old,
    Set<_Aspect> dependencies,
  ) =>
      (dependencies.contains(_Aspect.classes) &&
          (data.windowClass != old.data.windowClass ||
              data.heightClass != old.data.heightClass)) ||
      (dependencies.contains(_Aspect.hinge) && data.hinge != old.data.hinge);
}

/// Lookup helpers for [FitScaleData].
abstract final class FitScale {
  static FitScaleData? _global;
  static bool _extensionsUsed = false;

  /// Data of the root [FitScaleScope] currently in the tree, or null.
  ///
  /// Used by `package:fit_scale/extensions.dart`. Prefer `context.fit`
  /// in your own code: it follows nested scopes and rebuilds only the
  /// widgets that read it.
  static FitScaleData? get global => _global;

  /// [global] for `package:fit_scale/extensions.dart`. Also records that
  /// extensions are in use, which turns on the root scope's subtree
  /// rebuild on size changes.
  @internal
  static FitScaleData? globalForExtensions() {
    _extensionsUsed = true;
    return _global;
  }

  /// Window class of the nearest scope. Rebuilds the caller only when
  /// the window or height class changes.
  static FitWindowClass windowClassOf(BuildContext context) =>
      _classesOf(context).windowClass;

  /// Height class of the nearest scope. Rebuilds the caller only when
  /// the window or height class changes.
  static FitHeightClass heightClassOf(BuildContext context) =>
      _classesOf(context).heightClass;

  /// The fold or hinge splitting the screen, or null. Rebuilds the
  /// caller only when it changes (unfolding, posture change).
  static FitHinge? hingeOf(BuildContext context) =>
      _aspectOf(context, _Aspect.hinge).hinge;

  static FitScaleData _classesOf(BuildContext context) =>
      _aspectOf(context, _Aspect.classes);

  static FitScaleData _aspectOf(BuildContext context, _Aspect aspect) {
    final data = InheritedModel.inheritFrom<_FitScaleInherited>(
      context,
      aspect: aspect,
    )?.data;
    if (data == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No FitScaleScope found.'),
        ErrorHint(
          'Wrap your app in FitScaleScope(config: FitScaleConfig('
          'designSize: Size(w, h)), child: ...).',
        ),
      ]);
    }
    return data;
  }

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
