import 'package:flutter/widgets.dart';

/// A device to render a screen on: logical size and platform.
@immutable
class FitDevice {
  const FitDevice(
    this.name,
    this.size, {
    this.platform = TargetPlatform.android,
  });

  final String name;

  /// Logical pixels, portrait unless the name says otherwise.
  final Size size;

  /// Picks the tap-target guideline (44 on iOS, 48 on Android) and the
  /// platform the app thinks it runs on.
  final TargetPlatform platform;

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

  /// Where linear scaling breaks first.
  static const small = [foldCover, iphoneSe1, androidCompact, iphoneSe3];

  /// Common modern phones.
  static const phones = [iphone16Pro, pixel9, iphone16ProMax];

  static const all = [
    ...small,
    ...phones,
    ipadMini,
    phoneLandscape,
  ];
}
