import 'package:flutter/widgets.dart';

/// Width class of a screen or pane, after Material 3's window size
/// classes.
enum FitWindowClass {
  /// Phones in portrait. Below [FitBreakpoints.medium] (600).
  compact,

  /// Unfolded foldables, small tablets in portrait. 600–839.
  medium,

  /// Tablets, phones in landscape. 840–1199.
  expanded,

  /// Large tablets in landscape, desktop windows. 1200–1599.
  large,

  /// Wide desktop windows. 1600 and up.
  extraLarge;

  /// True when this class is [other] or wider.
  bool isAtLeast(FitWindowClass other) => index >= other.index;
}

/// Height class of a screen or pane. A phone in landscape is
/// [FitWindowClass.expanded] by width but [compact] by height.
enum FitHeightClass {
  /// Below [FitBreakpoints.mediumHeight] (480): phones in landscape.
  compact,

  /// 480–899.
  medium,

  /// 900 and up.
  expanded;

  bool isAtLeast(FitHeightClass other) => index >= other.index;
}

/// Where each class starts, in logical pixels. Defaults follow
/// Material 3.
@immutable
class FitBreakpoints {
  const FitBreakpoints({
    this.medium = 600,
    this.expanded = 840,
    this.large = 1200,
    this.extraLarge = 1600,
    this.mediumHeight = 480,
    this.expandedHeight = 900,
  })  : assert(0 < medium && medium < expanded),
        assert(expanded < large && large < extraLarge),
        assert(0 < mediumHeight && mediumHeight < expandedHeight);

  final double medium;
  final double expanded;
  final double large;
  final double extraLarge;
  final double mediumHeight;
  final double expandedHeight;

  FitWindowClass widthClass(double width) {
    if (width >= extraLarge) return FitWindowClass.extraLarge;
    if (width >= large) return FitWindowClass.large;
    if (width >= expanded) return FitWindowClass.expanded;
    if (width >= medium) return FitWindowClass.medium;
    return FitWindowClass.compact;
  }

  FitHeightClass heightClass(double height) {
    if (height >= expandedHeight) return FitHeightClass.expanded;
    if (height >= mediumHeight) return FitHeightClass.medium;
    return FitHeightClass.compact;
  }

  @override
  bool operator ==(Object other) =>
      other is FitBreakpoints &&
      other.medium == medium &&
      other.expanded == expanded &&
      other.large == large &&
      other.extraLarge == extraLarge &&
      other.mediumHeight == mediumHeight &&
      other.expandedHeight == expandedHeight;

  @override
  int get hashCode => Object.hash(
        medium,
        expanded,
        large,
        extraLarge,
        mediumHeight,
        expandedHeight,
      );
}
