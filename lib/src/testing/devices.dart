import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A device to render a screen on: logical size and platform.
@immutable
class FitDevice {
  const FitDevice(
    this.name,
    this.size, {
    this.platform = TargetPlatform.android,
    this.displayFeatures = const [],
  });

  final String name;

  /// Logical pixels, portrait unless the name says otherwise.
  final Size size;

  /// Picks the tap-target guideline (44 on iOS, 48 on Android) and the
  /// platform the app thinks it runs on.
  final TargetPlatform platform;

  /// Folds, hinges and cutouts, in logical pixels, as the device reports
  /// them through `MediaQuery.displayFeaturesOf`.
  final List<ui.DisplayFeature> displayFeatures;

  /// The same device rotated. Display features are dropped: they move
  /// when the device rotates.
  FitDevice get landscape => FitDevice(
        '${name}_landscape',
        Size(size.height, size.width),
        platform: platform,
      );

  @override
  String toString() =>
      '$name ${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}';
}

/// Real device sizes, from the smallest in use to tablets.
abstract final class FitDevices {
  static const foldCover = FitDevice('fold_cover', Size(280, 653));
  static const iphoneSe1 =
      FitDevice('iphone_se1', Size(320, 568), platform: TargetPlatform.iOS);
  static const androidCompact = FitDevice('android_compact', Size(360, 640));
  static const iphoneSe3 =
      FitDevice('iphone_se3', Size(375, 667), platform: TargetPlatform.iOS);
  static const iphone16Pro =
      FitDevice('iphone16pro', Size(402, 874), platform: TargetPlatform.iOS);
  static const pixel9 = FitDevice('pixel9', Size(412, 923));
  static const iphone16ProMax = FitDevice(
    'iphone16promax',
    Size(440, 956),
    platform: TargetPlatform.iOS,
  );
  static const ipadMini =
      FitDevice('ipad_mini', Size(744, 1133), platform: TargetPlatform.iOS);
  static const phoneLandscape = FitDevice(
    'phone_landscape',
    Size(874, 402),
    platform: TargetPlatform.iOS,
  );

  /// Galaxy Z Fold unfolded: the medium window class.
  static const foldOpen = FitDevice('fold_open', Size(673, 841));

  /// iPad Pro 13-inch in portrait: the expanded window class.
  static const ipadPro13 =
      FitDevice('ipad_pro13', Size(1032, 1376), platform: TargetPlatform.iOS);

  /// Where linear scaling breaks first.
  static const small = [foldCover, iphoneSe1, androidCompact, iphoneSe3];

  /// Common modern phones.
  static const phones = [iphone16Pro, pixel9, iphone16ProMax];

  /// Medium and expanded window classes, for breakpoint layouts.
  static const tablets = [foldOpen, ipadMini, ipadPro13];

  /// Galaxy Z Fold unfolded and half open: a vertical fold, book posture.
  static const foldBook = FitDevice(
    'fold_book',
    Size(673, 841),
    displayFeatures: [
      ui.DisplayFeature(
        bounds: Rect.fromLTWH(336.5, 0, 0, 841),
        type: ui.DisplayFeatureType.fold,
        state: ui.DisplayFeatureState.postureHalfOpened,
      ),
    ],
  );

  /// Galaxy Z Flip half open on a table: a horizontal fold, tabletop
  /// posture.
  static const flipTabletop = FitDevice(
    'flip_tabletop',
    Size(412, 915),
    displayFeatures: [
      ui.DisplayFeature(
        bounds: Rect.fromLTWH(0, 457.5, 412, 0),
        type: ui.DisplayFeatureType.fold,
        state: ui.DisplayFeatureState.postureHalfOpened,
      ),
    ],
  );

  /// Surface Duo spanned across both screens: a 34 px physical hinge.
  static const surfaceDuo = FitDevice(
    'surface_duo',
    Size(1114, 720),
    displayFeatures: [
      ui.DisplayFeature(
        bounds: Rect.fromLTWH(540, 0, 34, 720),
        type: ui.DisplayFeatureType.hinge,
        state: ui.DisplayFeatureState.postureFlat,
      ),
    ],
  );

  /// Devices with a fold or hinge splitting the screen. Not in [all]:
  /// add them where your app supports foldables.
  static const foldables = [foldBook, flipTabletop, surfaceDuo];

  static const all = [
    ...small,
    ...phones,
    ...tablets,
    phoneLandscape,
  ];
}
