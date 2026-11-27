import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'checks.dart';
import 'devtools.dart';
import 'hinge.dart';
import 'scope.dart';

/// Kind of problem [FitDebugOverlay] highlights.
enum FitDebugProblemKind {
  /// A tappable element smaller than the platform minimum. Red.
  tapTarget,

  /// Text drawn smaller than `minFontSize`. Purple.
  smallText,

  /// Text cut off by `maxLines`. Orange.
  truncatedText,

  /// Text or a tap target lying across a fold or hinge. Teal.
  hingeOverlap,
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
/// * orange: text cut off by `maxLines`,
/// * teal: text or a tap target across a fold or hinge, which is drawn
///   as a dark band.
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
  final _childSemantics = _SemanticsSink();
  SemanticsHandle? _semantics;
  List<FitDebugProblem> _problems = const [];
  FitHinge? _hinge;
  Rect? _hingeRect;
  bool _collapsed = false;
  bool _scanScheduled = false;

  /// [FitDebugOverlay.enabled], unless DevTools forced it on or off.
  bool get _enabled => FitDevTools.overlay.value ?? widget.enabled;

  @override
  void initState() {
    super.initState();
    FitDevTools.overlay.addListener(_onForced);
    if (_enabled) _start();
  }

  void _onForced() {
    if (!mounted) return;
    setState(() => _enabled ? _start() : _stop());
  }

  @override
  void didUpdateWidget(FitDebugOverlay old) {
    super.didUpdateWidget(old);
    final wasEnabled = FitDevTools.overlay.value ?? old.enabled;
    if (_enabled && !wasEnabled) _start();
    if (!_enabled && wasEnabled) _stop();
  }

  @override
  void dispose() {
    FitDevTools.overlay.removeListener(_onForced);
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
    FitDevTools.problems = const [];
  }

  /// Runs once after the next frame, then re-arms itself, so it follows
  /// every frame without ever asking for one.
  void _scheduleScan() {
    if (_scanScheduled) return;
    _scanScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scanScheduled = false;
      if (!mounted || !_enabled) return;
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
    final targets = _targets(root);
    final hinge = FitHinge.fromDisplayFeatures(
      MediaQuery.maybeDisplayFeaturesOf(context) ?? const [],
    );
    final min = _minTap;
    final found = <FitDebugProblem>[
      // Layout size, not drawn size: a preview that scales the whole app
      // down (a device frame, FittedBox) does not shrink the real button.
      for (final t in targets)
        if (!t.cutByScreenEdge &&
            (t.layoutSize.width + 0.01 < min ||
                t.layoutSize.height + 0.01 < min))
          FitDebugProblem(
            FitDebugProblemKind.tapTarget,
            t.rect.shift(-origin),
            'tap target ${t.layoutSize.width.toStringAsFixed(0)}x'
            '${t.layoutSize.height.toStringAsFixed(0)}, below '
            '${min.toStringAsFixed(0)}x${min.toStringAsFixed(0)}',
          ),
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
      if (hinge != null)
        for (final issue in hingeOverlaps(hinge, paragraphs, targets))
          FitDebugProblem(
            FitDebugProblemKind.hingeOverlap,
            issue.rect.shift(-origin),
            issue.message,
          ),
    ];
    final hingeRect = hinge?.bounds.shift(-origin);

    if (listEquals(found, _problems) && hingeRect == _hingeRect) return;
    final problemsChanged = !listEquals(found, _problems);
    setState(() {
      _problems = List.unmodifiable(found);
      _hinge = hinge;
      _hingeRect = hingeRect;
    });
    if (problemsChanged) widget.onProblems?.call(_problems);
    FitDevTools.problems = [
      for (final p in _problems)
        {
          'kind': p.kind.name,
          'message': p.message,
          'left': p.rect.left,
          'top': p.rect.top,
          'width': p.rect.width,
          'height': p.rect.height,
        },
    ];
  }

  double get _minTap =>
      widget.minTapTarget ??
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 44.0,
        _ => 48.0,
      };

  List<TapTarget> _targets(RenderObject root) {
    // Only the child's own nodes: not a sibling route, another overlay or
    // anything else above or beside this widget.
    final own = _childSemantics.node;
    final rootNode = own != null && own.attached
        ? own
        : root.owner?.semanticsOwner?.rootSemanticsNode;
    if (rootNode == null) return const [];
    final view = View.maybeOf(context);
    final ratio = view?.devicePixelRatio ?? 1;
    return tapTargets(
      rootNode,
      devicePixelRatio: ratio,
      screen: (view?.physicalSize ?? Size.infinite) / ratio,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    _scheduleScan();
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        KeyedSubtree(
          key: _childKey,
          child: _SemanticsCapture(sink: _childSemantics, child: widget.child),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ProblemPainter(_problems, _hingeRect),
            ),
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
            if (counts[FitDebugProblemKind.hingeOverlap]! > 0)
              '${counts[FitDebugProblemKind.hingeOverlap]} on '
                  '${_hinge?.posture == FitPosture.flat ? 'hinge' : 'fold'}',
          ].join(' · ');

    final lines = _collapsed
        ? ['fit · ${_problems.isEmpty ? 'ok' : '${_problems.length} !'}']
        : [
            '${fit?.windowClass.name ?? 'no FitScaleScope'} · '
                '${size.width.toStringAsFixed(0)}×'
                '${size.height.toStringAsFixed(0)}'
                '${_hinge == null ? '' : ' · ${_hinge!.posture.name} '
                    '${_hinge!.posture == FitPosture.flat ? 'hinge' : 'fold'}'}',
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

/// Holds the semantics node [_SemanticsCapture] built for the child.
class _SemanticsSink {
  SemanticsNode? node;
}

/// Gives the overlay's child its own semantics container and records the
/// node, so the overlay can scan just that subtree. Works in release
/// builds too, unlike `RenderObject.debugSemantics`.
class _SemanticsCapture extends SingleChildRenderObjectWidget {
  const _SemanticsCapture({required this.sink, super.child});

  final _SemanticsSink sink;

  @override
  _RenderSemanticsCapture createRenderObject(BuildContext context) =>
      _RenderSemanticsCapture(sink);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSemanticsCapture renderObject,
  ) =>
      renderObject.sink = sink;
}

class _RenderSemanticsCapture extends RenderProxyBox {
  _RenderSemanticsCapture(this.sink);

  _SemanticsSink sink;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..explicitChildNodes = true;
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    sink.node = node;
    super.assembleSemanticsNode(node, config, children);
  }

  @override
  void detach() {
    sink.node = null;
    super.detach();
  }
}

class _ProblemPainter extends CustomPainter {
  _ProblemPainter(this.problems, this.hinge);

  final List<FitDebugProblem> problems;
  final Rect? hinge;

  static const _colors = {
    FitDebugProblemKind.tapTarget: Color(0xFFE53935),
    FitDebugProblemKind.smallText: Color(0xFF8E24AA),
    FitDebugProblemKind.truncatedText: Color(0xFFFB8C00),
    FitDebugProblemKind.hingeOverlap: Color(0xFF00897B),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final h = hinge;
    if (h != null) {
      // A fold can be zero pixels wide: draw at least a 4 px band.
      final band = h.width < 4 && h.height > h.width
          ? Rect.fromCenter(center: h.center, width: 4, height: h.height)
          : h.height < 4 && h.width > h.height
              ? Rect.fromCenter(center: h.center, width: h.width, height: 4)
              : h;
      canvas.drawRect(band, Paint()..color = const Color(0x80202124));
    }
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
      old.hinge != hinge || !listEquals(old.problems, problems);
}
