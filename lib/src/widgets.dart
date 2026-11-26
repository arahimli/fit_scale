import 'package:flutter/widgets.dart';

import 'scope.dart';

/// A box with a design height that grows when its content needs more.
///
/// Use it instead of `SizedBox(height: x.h)` for anything that holds
/// text: on a small screen or with a large system font, a fixed height
/// cuts the text off and overflows. With [interactive] the height is
/// also never below the platform's touch-target minimum.
class FitBox extends StatelessWidget {
  const FitBox({
    super.key,
    required this.height,
    this.interactive = false,
    this.alignment,
    this.child,
  });

  /// Design height. The real minimum height is scaled from this.
  final double height;

  /// Treat as a touch target (button, list tile).
  final bool interactive;

  /// Where to place a child that is shorter than the minimum.
  final AlignmentGeometry? alignment;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final fit = context.fit;
    final minHeight = interactive ? fit.tap(height) : fit.h(height);
    final content = alignment == null
        ? child
        : Align(alignment: alignment!, heightFactor: 1, child: child);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: content,
    );
  }
}

/// A square that stays square on every aspect ratio.
///
/// `width: 56.w, height: 56.h` turns a circle into an oval as soon as
/// the screen's proportions differ from the design; this does not.
class FitSquare extends StatelessWidget {
  const FitSquare({super.key, required this.size, this.child});

  /// Design side length.
  final double size;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: context.fit.r(size), child: child);
  }
}
