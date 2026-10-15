// Text on PDF pages, in pure Dart over the layout the backend gives (one box per character):
// finding a string, the boxes of a range of characters (one per line), and the character under
// the pointer for selecting.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'backend.dart';

/// A found string: page, first character, end (exclusive).
class TextMatch {
  const TextMatch(this.page, this.start, this.end);
  final int page;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is TextMatch &&
      other.page == page &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(page, start, end);

  @override
  String toString() => 'TextMatch($page, $start, $end)';
}

/// Lowercase without the most common accents: a search for "citta" finds "città".
String _fold(String c) {
  final lower = c.toLowerCase();
  const from = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
  const to = 'aaaaaaeeeeiiiiooooouuuucn';
  final i = from.indexOf(lower);
  return i < 0 ? lower : to[i];
}

/// Collapses runs of white space (line breaks included) to one space.
bool _space(String c) => c.trim().isEmpty;

/// Every occurrence of `query` in the page's text, case and accent insensitive; white space
/// in the query matches any run of white space (words split across lines).
List<TextMatch> findInLayout(int page, PdfTextLayout layout, String query) {
  final q = [for (final r in query.trim().runes) _fold(String.fromCharCode(r))];
  if (q.isEmpty) return const [];
  final chars = layout.chars;
  final out = <TextMatch>[];
  var i = 0;
  while (i < chars.length) {
    var j = i;
    var k = 0;
    while (k < q.length && j < chars.length) {
      if (_space(q[k])) {
        if (!_space(chars[j])) break;
        while (j < chars.length && _space(chars[j])) {
          j++;
        }
        while (k < q.length && _space(q[k])) {
          k++;
        }
        continue;
      }
      if (_fold(chars[j]) != q[k]) break;
      j++;
      k++;
    }
    if (k == q.length) {
      out.add(TextMatch(page, i, j));
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

/// The boxes covering characters `start` to `end` (exclusive): one per line, in page points.
List<Rect> rangeRects(PdfTextLayout layout, int start, int end) {
  final out = <Rect>[];
  final last = math.min(end, layout.length);
  Rect? line;
  for (var i = math.max(0, start); i < last; i++) {
    final r = layout.rects[i];
    if (r.isEmpty || _space(layout.chars[i])) continue;
    if (line != null &&
        (r.center.dy - line.center.dy).abs() < line.height / 2 &&
        r.left >= line.left - 1) {
      line = line.expandToInclude(r);
    } else {
      if (line != null) out.add(line);
      line = r;
    }
  }
  if (line != null) out.add(line);
  return out;
}

/// The index of the character at `point` (page points), or the nearest one on the nearest
/// line; null on a page without text. `after` tells whether the point is past the middle of
/// that character (the selection then ends after it).
(int, bool)? charAt(PdfTextLayout layout, Offset point) {
  int? best;
  var bestScore = double.infinity;
  for (var i = 0; i < layout.length; i++) {
    final r = layout.rects[i];
    if (r.isEmpty) continue;
    if (r.contains(point)) {
      best = i;
      break;
    }
    // Lines first: vertical distance weighs more than horizontal.
    final dy = point.dy < r.top
        ? r.top - point.dy
        : (point.dy > r.bottom ? point.dy - r.bottom : 0.0);
    final dx = point.dx < r.left
        ? r.left - point.dx
        : (point.dx > r.right ? point.dx - r.right : 0.0);
    final score = dy * 1000 + dx;
    if (score < bestScore) {
      bestScore = score;
      best = i;
    }
  }
  if (best == null) return null;
  return (best, point.dx > layout.rects[best].center.dx);
}

/// A selection of text on one page: characters `start` to `end` (exclusive).
class PageSelection {
  const PageSelection(this.page, this.start, this.end);
  final int page;
  final int start;
  final int end;

  bool get isEmpty => end <= start;

  @override
  bool operator ==(Object other) =>
      other is PageSelection &&
      other.page == page &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(page, start, end);
}
