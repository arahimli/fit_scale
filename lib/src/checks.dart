import 'package:flutter/rendering.dart';

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
