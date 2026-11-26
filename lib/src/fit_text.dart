import 'package:flutter/widgets.dart';

/// Text that shrinks only when it does not fit, and never below
/// [minFontSize].
///
/// For text in a space that cannot grow: an avatar, a badge, a chip, a
/// one-line header. With a large system text size the text gets smaller
/// until it fits, but [minFontSize] is a floor on the size actually
/// drawn (system text scale included), the same number the
/// `FitCheck.minFont` test check uses. If it still does not fit at the
/// floor, [overflow] applies.
///
/// With unbounded width and height (in a `Row` without `Expanded`, for
/// example) there is nothing to fit into and it behaves like [Text].
/// Like any [LayoutBuilder], it cannot report intrinsic sizes.
class FitText extends StatelessWidget {
  const FitText(
    this.data, {
    super.key,
    this.style,
    this.minFontSize = 11,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.semanticsLabel,
  })  : assert(minFontSize > 0),
        assert(maxLines == null || maxLines > 0);

  final String data;

  /// Merged with the ambient [DefaultTextStyle]. Its font size is the
  /// largest size used.
  final TextStyle? style;

  /// Smallest size drawn on screen, in logical pixels, after the system
  /// text scale.
  final double minFontSize;

  /// Null lets the text wrap onto as many lines as the height allows.
  final int? maxLines;

  /// What to do when the text does not fit even at [minFontSize].
  /// With [maxLines] null, an ellipsis becomes a clip so all lines show.
  final TextOverflow overflow;

  final TextAlign? textAlign;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ambient = DefaultTextStyle.of(context);
    final base = ambient.style.merge(style);
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final direction = Directionality.of(context);
    final align = textAlign ?? ambient.textAlign ?? TextAlign.start;
    final lines = maxLines ?? ambient.maxLines;
    // Flutter ellipsizes the first line when maxLines is null, which
    // would undo the wrapping the size was chosen for; clip instead.
    final effectiveOverflow = lines == null && overflow == TextOverflow.ellipsis
        ? TextOverflow.clip
        : overflow;

    return LayoutBuilder(
      builder: (context, constraints) {
        var size = base.fontSize ?? 14;
        if (constraints.hasBoundedWidth || constraints.hasBoundedHeight) {
          size = _fit(
            base: base,
            largest: size,
            scaler: scaler,
            direction: direction,
            align: align,
            lines: lines,
            constraints: constraints,
          );
        }
        return Text(
          data,
          style: base.copyWith(fontSize: size),
          maxLines: lines,
          overflow: effectiveOverflow,
          textAlign: align,
          semanticsLabel: semanticsLabel,
        );
      },
    );
  }

  double _fit({
    required TextStyle base,
    required double largest,
    required TextScaler scaler,
    required TextDirection direction,
    required TextAlign align,
    required int? lines,
    required BoxConstraints constraints,
  }) {
    bool fits(double fontSize) {
      final painter = TextPainter(
        text: TextSpan(text: data, style: base.copyWith(fontSize: fontSize)),
        textDirection: direction,
        textAlign: align,
        textScaler: scaler,
        maxLines: lines,
      )..layout(maxWidth: constraints.maxWidth);
      final ok = !painter.didExceedMaxLines &&
          painter.height <= constraints.maxHeight + 0.01 &&
          // A word wider than the box would be broken mid-word.
          painter.minIntrinsicWidth <= constraints.maxWidth + 0.01;
      painter.dispose();
      return ok;
    }

    if (fits(largest)) return largest;

    // Already at or below the floor: never shrink further.
    if (scaler.scale(largest) <= minFontSize) return largest;

    // Smallest logical size whose drawn size reaches the floor. The
    // scaler can be non-linear (Android 14+), so search for it.
    var lo = 0.0, hi = largest;
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      if (scaler.scale(mid) >= minFontSize) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    final floor = hi;
    if (!fits(floor)) return floor;

    // floor fits, largest does not: find the largest size that fits.
    var good = floor, bad = largest;
    for (var i = 0; i < 12; i++) {
      final mid = (good + bad) / 2;
      if (fits(mid)) {
        good = mid;
      } else {
        bad = mid;
      }
    }
    return good;
  }
}
