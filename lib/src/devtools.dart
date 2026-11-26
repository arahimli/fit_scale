import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'scope.dart';

/// State the fit_scale DevTools extension reads and changes, through
/// VM service extensions registered in debug and profile builds:
///
/// * `ext.fit_scale.state`: size, window class, factors, hinge, text
///   scale and the debug overlay's problems, as JSON,
/// * `ext.fit_scale.setTextScale` (`scale`: a number, or `off`): show the
///   app at another system text size without changing device settings,
/// * `ext.fit_scale.setOverlay` (`enabled`: `true`, `false` or
///   `default`): switch `FitDebugOverlay` on or off.
abstract final class FitDevTools {
  /// Text scale forced from DevTools, or null for the device's own.
  static final textScale = ValueNotifier<double?>(null);

  /// Overlay forced on or off from DevTools, or null for the widget's
  /// own `enabled`.
  static final overlay = ValueNotifier<bool?>(null);

  /// Latest problems from a `FitDebugOverlay`, as JSON maps.
  static List<Map<String, Object?>> problems = const [];

  static bool _registered = false;

  /// Registers the service extensions once. Called by `FitScaleScope`;
  /// does nothing in release builds.
  static void ensureRegistered() {
    if (_registered || kReleaseMode) return;
    _registered = true;
    for (final name in const ['state', 'setTextScale', 'setOverlay']) {
      _register(name, (args) => handle(name, args));
    }
  }

  /// Runs one service extension method. Public for tests.
  @visibleForTesting
  static Map<String, Object?> handle(String name, Map<String, String> args) {
    switch (name) {
      case 'state':
        return state();
      case 'setTextScale':
        final raw = args['scale'];
        textScale.value =
            raw == null || raw == 'off' ? null : double.parse(raw);
        return {'textScale': textScale.value};
      case 'setOverlay':
        overlay.value = switch (args['enabled']) {
          'true' => true,
          'false' => false,
          _ => null,
        };
        return {'overlay': overlay.value};
    }
    throw ArgumentError.value(name, 'name', 'unknown fit_scale extension');
  }

  /// What `ext.fit_scale.state` returns.
  @visibleForTesting
  static Map<String, Object?> state() {
    final fit = FitScale.global;
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final systemScale = view == null
        ? 1.0
        : MediaQueryData.fromView(view).textScaler.scale(10) / 10;
    final hinge = fit?.hinge;
    return {
      'connected': fit != null,
      if (fit != null) ...{
        'width': fit.size.width,
        'height': fit.size.height,
        'windowClass': fit.windowClass.name,
        'heightClass': fit.heightClass.name,
        'scaleWidth': fit.scaleWidth,
        'scaleHeight': fit.scaleHeight,
        'scale': fit.scale,
        'fontScale': fit.fontScale,
        'minTapTarget': fit.minTapTarget,
        'designWidth': fit.config.designSize.width,
        'designHeight': fit.config.designSize.height,
      },
      'hinge': hinge == null
          ? null
          : {
              'posture': hinge.posture.name,
              'left': hinge.bounds.left,
              'top': hinge.bounds.top,
              'width': hinge.bounds.width,
              'height': hinge.bounds.height,
            },
      'systemTextScale': systemScale,
      'forcedTextScale': textScale.value,
      'forcedOverlay': overlay.value,
      'problems': problems,
    };
  }

  static void _register(
    String name,
    Map<String, Object?> Function(Map<String, String> args) handler,
  ) {
    developer.registerExtension('ext.fit_scale.$name', (method, args) async {
      try {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(handler(args)),
        );
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          '$e',
        );
      }
    });
  }
}
