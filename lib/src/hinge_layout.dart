import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'hinge.dart';
import 'scope.dart';

/// Two panes on either side of a fold or hinge, one layout otherwise.
///
/// When a separating fold or hinge crosses this widget (see [FitHinge]),
/// [start] fills the part before it and [end] the part after it: left
/// and right in book posture or on a Surface Duo (right and left in
/// right-to-left text), top and bottom in tabletop posture. Nothing is
/// placed on the hinge itself. Otherwise [single] fills the widget.
///
/// ```dart
/// FitHingeLayout(
///   single: (_) => const OrderColumn(),
///   start: (_) => const OrderSummary(),
///   end: (_) => const OrderActions(),
/// )
/// ```
///
/// It does not have to fill the screen: it measures where it is after
/// layout and, if it is not at the screen origin (below an app bar, for
/// example), corrects the split on the next frame.
class FitHingeLayout extends StatefulWidget {
  const FitHingeLayout({
    super.key,
    required this.single,
    required this.start,
    required this.end,
  });

  final WidgetBuilder single;
  final WidgetBuilder start;
  final WidgetBuilder end;

  @override
  State<FitHingeLayout> createState() => _FitHingeLayoutState();
}

class _FitHingeLayoutState extends State<FitHingeLayout> {
  /// This widget's position on screen, from the last frame.
  Offset _origin = Offset.zero;
  bool _measureScheduled = false;

  void _measureAfterFrame() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero);
      if ((origin - _origin).distance > 0.5) {
        setState(() => _origin = origin);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hinge = FitScale.hingeOf(context);
    if (hinge == null) return Builder(builder: widget.single);
    _measureAfterFrame();
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final local = hinge.bounds.shift(-_origin);
        final area = Offset.zero & size;
        if (!size.isFinite || !hinge.crosses(area)) {
          return Builder(builder: widget.single);
        }
        if (hinge.splitsLeftRight) {
          // Row lays children right to left in RTL, so measure from there.
          final before = rtl ? size.width - local.right : local.left;
          final gap = local.width;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: before.clamp(0, size.width),
                child: Builder(builder: widget.start),
              ),
              SizedBox(width: gap),
              Expanded(child: Builder(builder: widget.end)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: local.top.clamp(0, size.height),
              child: Builder(builder: widget.start),
            ),
            SizedBox(height: local.height),
            Expanded(child: Builder(builder: widget.end)),
          ],
        );
      },
    );
  }
}
