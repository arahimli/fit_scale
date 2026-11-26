import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// How a foldable is held, as far as the layout is concerned.
enum FitPosture {
  /// A physical hinge between two flat screens (Surface Duo spanned).
  flat,

  /// Half open with a vertical fold: left and right halves, like a book.
  book,

  /// Half open with a horizontal fold: top and bottom halves, the bottom
  /// one lying on a table.
  tabletop,
}

/// A fold or hinge that splits the screen in two.
///
/// Only separating features count, by Flutter's own rule: a hinge with a
/// width, or a fold that is half open. A fully opened fold is ignored, so
/// the whole screen stays one surface. Display cutouts never count.
@immutable
class FitHinge {
  const FitHinge({
    required this.bounds,
    required this.axis,
    required this.posture,
  });

  /// The first separating fold or hinge in [features], or null.
  /// [features] come from `MediaQuery.displayFeaturesOf(context)`.
  static FitHinge? fromDisplayFeatures(Iterable<ui.DisplayFeature> features) {
    for (final f in features) {
      if (f.type == ui.DisplayFeatureType.cutout) continue;
      final halfOpen = f.state == ui.DisplayFeatureState.postureHalfOpened;
      if (!(f.bounds.shortestSide > 0 || halfOpen)) continue;
      if (f.bounds.longestSide == 0) continue;
      final axis =
          f.bounds.height >= f.bounds.width ? Axis.vertical : Axis.horizontal;
      return FitHinge(
        bounds: f.bounds,
        axis: axis,
        posture: !halfOpen
            ? FitPosture.flat
            : axis == Axis.vertical
                ? FitPosture.book
                : FitPosture.tabletop,
      );
    }
    return null;
  }

  /// Where the fold or hinge is, in screen coordinates (logical pixels).
  /// A fold can be zero pixels wide.
  final Rect bounds;

  /// [Axis.vertical]: the hinge runs top to bottom and splits the screen
  /// into left and right. [Axis.horizontal]: top and bottom.
  final Axis axis;

  final FitPosture posture;

  bool get splitsLeftRight => axis == Axis.vertical;

  /// True when [rect] (screen coordinates) lies across the hinge, so part
  /// of it would sit on the fold or be hidden by the hinge.
  bool crosses(Rect rect) {
    if (rect.isEmpty) return false;
    final overlapsAlong = splitsLeftRight
        ? rect.top < bounds.bottom && rect.bottom > bounds.top
        : rect.left < bounds.right && rect.right > bounds.left;
    if (!overlapsAlong) return false;
    return splitsLeftRight
        ? rect.left < bounds.right && rect.right > bounds.left
        : rect.top < bounds.bottom && rect.bottom > bounds.top;
  }

  @override
  bool operator ==(Object other) =>
      other is FitHinge &&
      other.bounds == bounds &&
      other.axis == axis &&
      other.posture == posture;

  @override
  int get hashCode => Object.hash(bounds, axis, posture);

  @override
  String toString() => 'FitHinge(${posture.name}, $bounds)';
}
