import 'package:flutter/rendering.dart';

import 'hinge.dart';

/// Text checks shared by the test harness and [FitDebugOverlay], so a
/// problem highlighted on screen is the same problem a test reports.
///
/// Internal: not exported from the package.

/// One piece of text that failed a check.
class TextIssue {
  const TextIssue(this.paragraph, this.message);

  /// The paragraph that holds the text, for its position on screen.
  final RenderParagraph paragraph;
  final String message;
}

/// Every laid-out, non-empty [RenderParagraph] at or below [root].
Iterable<RenderParagraph> paragraphsBelow(RenderObject root) sync* {
  final pending = <RenderObject>[root];
  while (pending.isNotEmpty) {
    final node = pending.removeLast();
    if (node is RenderParagraph && isVisible(node)) yield node;
    node.visitChildren(pending.add);
  }
}

bool isVisible(RenderParagraph p) => p.attached && p.hasSize && !p.size.isEmpty;

/// Text drawn smaller than [minFontSize], system text scale included.
/// One issue per distinct text span.
List<TextIssue> smallText(
  Iterable<RenderParagraph> paragraphs,
  double minFontSize,
) {
  final issues = <TextIssue>[];
  final seen = <String>{};
  for (final paragraph in paragraphs) {
    if (!isVisible(paragraph)) continue;
    void visit(InlineSpan span, double inherited) {
      final size = span.style?.fontSize ?? inherited;
      if (span is TextSpan) {
        final text = span.text?.trim() ?? '';
        if (text.isNotEmpty && !isIconGlyph(text)) {
          final px = paragraph.textScaler.scale(size);
          if (px < minFontSize) {
            final msg = '"${snippet(text)}" renders at '
                '${px.toStringAsFixed(1)} px, below $minFontSize';
            if (seen.add(msg)) issues.add(TextIssue(paragraph, msg));
          }
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, size);
        }
      }
    }

    visit(paragraph.text, 14);
  }
  return issues;
}

/// Text cut off by `maxLines` (ellipsis, fade or clip).
List<TextIssue> truncatedText(Iterable<RenderParagraph> paragraphs) {
  final issues = <TextIssue>[];
  final seen = <String>{};
  for (final paragraph in paragraphs) {
    if (!isVisible(paragraph) || !paragraph.didExceedMaxLines) continue;
    final text = paragraph.text.toPlainText().trim();
    if (text.isEmpty || isIconGlyph(text)) continue;
    final msg = '"${snippet(text)}" is cut off '
        '(maxLines: ${paragraph.maxLines}, overflow: ${paragraph.overflow.name})';
    if (seen.add(msg)) issues.add(TextIssue(paragraph, msg));
  }
  return issues;
}

String snippet(String text) =>
    text.length > 40 ? '${text.substring(0, 40)}...' : text;

/// Icon fonts put glyphs in the Unicode private use area.
bool isIconGlyph(String text) =>
    text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF);

/// A tappable element from the semantics tree.
class TapTarget {
  const TapTarget(
    this.rect,
    this.label, {
    required this.cutByScreenEdge,
    Size? layoutSize,
  }) : layoutSize = layoutSize ?? Size.zero;

  /// Position on screen, in logical pixels: the drawn size, after every
  /// ancestor transform.
  final Rect rect;

  /// Size before ancestor transforms, in logical pixels. Differs from
  /// [rect]'s size when the target sits under a scaling `Transform` or
  /// `FittedBox`, for example a device-frame preview.
  final Size layoutSize;
  final String label;

  /// Partly off screen: its visible size says nothing about its real
  /// size, so size checks skip it (as Flutter's guideline does).
  final bool cutByScreenEdge;
}

/// Every node in the semantics tree below [root] that can be tapped or
/// long-pressed, the way Flutter's tap-target guidelines find them.
List<TapTarget> tapTargets(
  SemanticsNode root, {
  required double devicePixelRatio,
  required Size screen,
}) {
  final targets = <TapTarget>[];
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
    final r = devicePixelRatio;
    final rect = Rect.fromLTRB(
      bounds.left / r,
      bounds.top / r,
      bounds.right / r,
      bounds.bottom / r,
    );
    if (rect.isEmpty) return;
    targets.add(TapTarget(
      rect,
      data.label,
      layoutSize: node.rect.size,
      cutByScreenEdge: rect.left < 0 ||
          rect.top < 0 ||
          rect.right > screen.width + 0.01 ||
          rect.bottom > screen.height + 0.01,
    ));
  }

  visit(root);
  return targets;
}

/// Something on screen that lies across a fold or hinge.
class HingeIssue {
  const HingeIssue(this.rect, this.message);

  /// Screen coordinates, logical pixels.
  final Rect rect;
  final String message;
}

/// Text lines and tap targets that cross [hinge]. Text is checked line
/// by line, so a paragraph whose lines all stay on one side passes.
List<HingeIssue> hingeOverlaps(
  FitHinge hinge,
  Iterable<RenderParagraph> paragraphs,
  Iterable<TapTarget> targets,
) {
  final what = hinge.posture == FitPosture.flat ? 'hinge' : 'fold';
  final issues = <HingeIssue>[];
  final seen = <String>{};
  for (final p in paragraphs) {
    if (!isVisible(p)) continue;
    final text = p.text.toPlainText();
    final trimmed = text.trim();
    if (trimmed.isEmpty || isIconGlyph(trimmed)) continue;
    final toScreen = p.getTransformTo(null);
    final lines = p
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )
        .map((b) => MatrixUtils.transformRect(toScreen, b.toRect()));
    final crossing = lines.where(hinge.crosses).toList();
    if (crossing.isEmpty) continue;
    final msg = '"${snippet(trimmed)}" crosses the $what';
    if (seen.add(msg)) {
      issues.add(
          HingeIssue(crossing.reduce((a, b) => a.expandToInclude(b)), msg));
    }
  }
  for (final t in targets) {
    if (!hinge.crosses(t.rect)) continue;
    final name = t.label.trim().isEmpty ? '' : ' "${snippet(t.label.trim())}"';
    final msg = 'tap target$name crosses the $what';
    if (seen.add('$msg ${t.rect}')) issues.add(HingeIssue(t.rect, msg));
  }
  return issues;
}
