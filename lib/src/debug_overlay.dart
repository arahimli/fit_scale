import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'checks.dart';
import 'scope.dart';

/// Kind of problem [FitDebugOverlay] highlights.
enum FitDebugProblemKind {
  /// A tappable element smaller than the platform minimum. Red.
  tapTarget,

  /// Text drawn smaller than `minFontSize`. Purple.
  smallText,

  /// Text cut off by `maxLines`. Orange.
  truncatedText,
}

/// One problem found on screen, with where it is.
@immutable
class FitDebugProblem {
  const FitDebugProblem(this.kind, this.rect, this.message);

  final FitDebugProblemKind kind;

  /// Position in the overlay's coordinates (logical pixels).
  final Rect rect;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is FitDebugProblem &&
      other.kind == kind &&
      other.rect == rect &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, rect, message);

  @override
  String toString() => '[${kind.name}] $message';
}

/// Shows fit_scale's checks live on top of a running app.
///
/// A panel in the corner shows the window class, screen size, scale
/// factors and system text scale; tap it to collapse it. Problems are
/// outlined with the same thresholds the test harness uses:
///
/// * red: a tappable element smaller than 48×48 (Android) or 44×44 (iOS),
/// * purple: text drawn smaller than [minFontSize],
/// * orange: text cut off by `maxLines`.
///
/// Overflow is not repeated: Flutter already draws its striped bar.
///
/// Put it inside your `FitScaleScope` so the panel can show the factors:
///
/// ```dart
/// FitScaleScope(
///   child: FitDebugOverlay(child: MaterialApp(...)),
/// )
/// ```
///
/// Off unless [enabled], which defaults to debug builds. While on it
/// keeps the semantics tree alive to find tap targets, and scans after
/// each frame, so leave it off in release builds.
class FitDebugOverlay extends StatefulWidget {
  const FitDebugOverlay({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
    this.minFontSize = 11,
    this.minTapTarget,
    this.showPanel = true,
    this.panelAlignment = Alignment.bottomLeft,
    this.panelTextStyle,
    this.onProblems,
  });

  final Widget child;
  final bool enabled;

  /// Same meaning as the harness's `minFontSize`.
  final double minFontSize;

  /// Null picks 44 on iOS and macOS, 48 elsewhere.
  final double? minTapTarget;

  final bool showPanel;
  final Alignment panelAlignment;

  /// Merged over the panel's 12 px white text, for example to set the
  /// font family. The panel sits above your app's theme, so it does not
  /// inherit it.
  final TextStyle? panelTextStyle;

  /// Called with the full list whenever it changes, for logging.
  final ValueChanged<List<FitDebugProblem>>? onProblems;

  @override
  State<FitDebugOverlay> createState() => _FitDebugOverlayState();
}

class _FitDebugOverlayState extends State<FitDebugOverlay> {
  final _childKey = GlobalKey();
  SemanticsHandle? _semantics;
  List<FitDebugProblem> _problems = const [];
  bool _collapsed = false;
  bool _scanScheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(FitDebugOverlay old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !old.enabled) _start();
    if (!widget.enabled && old.enabled) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    _semantics ??= SemanticsBinding.instance.ensureSemantics();
    _scheduleScan();
  }

  void _stop() {
    _semantics?.dispose();
    _semantics = null;
    _problems = const [];
  }

  /// Runs once after the next frame, then re-arms itself, so it follows
  /// every frame without ever asking for one.
  void _scheduleScan() {
    if (_scanScheduled) return;
    _scanScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scanScheduled = false;
      if (!mounted || !widget.enabled) return;
      _scan();
      _scheduleScan();
    });
  }

  void _scan() {
    final overlay = context.findRenderObject();
    final root = _childKey.currentContext?.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize || root == null) return;
    final origin = overlay.localToGlobal(Offset.zero);

    Rect boxOf(RenderBox box) => MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        ).shift(-origin);

    final paragraphs = paragraphsBelow(root).toList();
    final found = <FitDebugProblem>[
      ..._tapTargets(root, origin),
      for (final issue in smallText(paragraphs, widget.minFontSize))
        FitDebugProblem(
          FitDebugProblemKind.smallText,
          boxOf(issue.paragraph),
          issue.message,
        ),
      for (final issue in truncatedText(paragraphs))
        FitDebugProblem(
          FitDebugProblemKind.truncatedText,
          boxOf(issue.paragraph),
          issue.message,
        ),
    ];

    if (listEquals(found, _problems)) return;
    setState(() => _problems = List.unmodifiable(found));
    widget.onProblems?.call(_problems);
  }

  double get _minTap =>
      widget.minTapTarget ??
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 44.0,
        _ => 48.0,
      };

  /// Same rule as Flutter's tap-target accessibility guidelines.
  Iterable<FitDebugProblem> _tapTargets(RenderObject root, Offset origin) {
    final rootNode = root.owner?.semanticsOwner?.rootSemanticsNode;
    if (rootNode == null) return const [];
    final view = View.maybeOf(context);
    final ratio = view?.devicePixelRatio ?? 1;
    final screen = (view?.physicalSize ?? Size.infinite) / ratio;
    final min = _minTap;
    final problems = <FitDebugProblem>[];

    void visit(SemanticsNode node) {
      node.visitChildren((child) {
        visit(child);
        return true;
      });
      if (node.isMergedIntoParent) return;
      final data = node.getSemanticsData();
      // hasFlag is deprecated from Flutter 3.32, but its replacement
      // (flagsCollection) does not exist on 3.24, the minimum supported.
      // ignore: deprecated_member_use
      if (data.hasFlag(SemanticsFlag.isHidden)) return;
      if (!data.hasAction(SemanticsAction.tap) &&
          !data.hasAction(SemanticsAction.longPress)) {
        return;
      }
      var bounds = node.rect;
      for (SemanticsNode? n = node; n != null; n = n.parent) {
        final t = n.transform;
        if (t != null) bounds = MatrixUtils.transformRect(t, bounds);
      }
      final rect = Rect.fromLTRB(
        bounds.left / ratio,
        bounds.top / ratio,
        bounds.right / ratio,
        bounds.bottom / ratio,
      );
      if (rect.isEmpty) return;
      // Elements cut by the screen edge are skipped, as in Flutter's
      // guideline: their visible part says nothing about their size.
      if (rect.left < 0 ||
          rect.top < 0 ||
          rect.right > screen.width + 0.01 ||
          rect.bottom > screen.height + 0.01) {
        return;
      }
      if (rect.width + 0.01 < min || rect.height + 0.01 < min) {
        problems.add(FitDebugProblem(
          FitDebugProblemKind.tapTarget,
          rect.shift(-origin),
          'tap target ${rect.width.toStringAsFixed(0)}x'
          '${rect.height.toStringAsFixed(0)}, below '
          '${min.toStringAsFixed(0)}x${min.toStringAsFixed(0)}',
        ));
      }
    }

    visit(rootNode);
    return problems;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    _scheduleScan();
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        KeyedSubtree(key: _childKey, child: widget.child),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ProblemPainter(_problems)),
          ),
        ),
        if (widget.showPanel)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: widget.panelAlignment,
                child: ExcludeSemantics(child: _panel(context)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    final fit = FitScale.maybeOf(context);
    final size = fit?.size ?? MediaQuery.maybeSizeOf(context) ?? Size.zero;
    final textScale =
        (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling)
                .scale(10) /
            10;
    String f(double v) => v.toStringAsFixed(2);
    final counts = {
      for (final kind in FitDebugProblemKind.values)
        kind: _problems.where((p) => p.kind == kind).length,
    };
    final summary = _problems.isEmpty
        ? 'no problems'
        : [
            if (counts[FitDebugProblemKind.tapTarget]! > 0)
              '${counts[FitDebugProblemKind.tapTarget]} tap',
            if (counts[FitDebugProblemKind.smallText]! > 0)
              '${counts[FitDebugProblemKind.smallText]} small text',
            if (counts[FitDebugProblemKind.truncatedText]! > 0)
              '${counts[FitDebugProblemKind.truncatedText]} cut text',
          ].join(' · ');

    final lines = _collapsed
        ? ['fit · ${_problems.isEmpty ? 'ok' : '${_problems.length} !'}']
        : [
            '${fit?.windowClass.name ?? 'no FitScaleScope'} · '
                '${size.width.toStringAsFixed(0)}×'
                '${size.height.toStringAsFixed(0)}',
            if (fit != null)
              'w ${f(fit.scaleWidth)}  h ${f(fit.scaleHeight)}  '
                  'r ${f(fit.scale)}  sp ${f(fit.fontScale)}',
            'text ×${textScale.toStringAsFixed(2)} · $summary',
          ];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: () => setState(() => _collapsed = !_collapsed),
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xDD202124),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Text(
                  line,
                  // Fixed size: the panel must stay readable and not be
                  // flagged by the checks it reports.
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: _problems.isEmpty || line != lines.last
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFFFFB4A9),
                    decoration: TextDecoration.none,
                  ).merge(widget.panelTextStyle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemPainter extends CustomPainter {
  _ProblemPainter(this.problems);

  final List<FitDebugProblem> problems;

  static const _colors = {
    FitDebugProblemKind.tapTarget: Color(0xFFE53935),
    FitDebugProblemKind.smallText: Color(0xFF8E24AA),
    FitDebugProblemKind.truncatedText: Color(0xFFFB8C00),
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in problems) {
      final color = _colors[p.kind]!;
      canvas
        ..drawRect(p.rect, Paint()..color = color.withAlpha(0x26))
        ..drawRect(
          p.rect.deflate(1),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_ProblemPainter old) =>
      !listEquals(old.problems, problems);
}
