// Rendered pages, on demand and cached. A page widget asks for its page at the scale it is
// drawn (pixels per point); the scale is rounded up to a quarter-octave step so small zoom
// changes reuse the same bitmap. Renders run one at a time in the backend's worker, the most
// recent request first (the pages on screen now, not those scrolled past). While a page is
// rendering the widget shows the nearest bitmap it already has, enlarged or reduced.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../images/decode.dart' show rgbaImage;
import '../style.dart';
import 'backend.dart';

class PageImages extends ChangeNotifier {
  PageImages(
    this.handle, {
    this.maxBytes = PreviewMetrics.pageCacheBytes,
    this.maxPixels = PreviewMetrics.maxPagePixels,
  });

  final PdfDocumentHandle handle;
  final int maxBytes;
  final int maxPixels;

  /// Bitmaps by page and scale step, least recently used first.
  final LinkedHashMap<(int, int), ui.Image> _images = LinkedHashMap();
  final List<(int, int)> _queue = [];
  final Set<(int, int)> _failed = {};
  (int, int)? _rendering;
  int _bytes = 0;
  bool _disposed = false;

  /// How many renders have finished (tests).
  @visibleForTesting
  int renders = 0;

  /// The step of a scale: pixels per point = 2^(step / 4).
  static int stepOf(double scale) =>
      (math.log(math.max(scale, 1e-3)) / math.ln2 * 4 - 1e-9).ceil();

  static double scaleOf(int step) => math.pow(2, step / 4).toDouble();

  /// The step for `page` at `scale`, kept within [maxPixels].
  int _step(int page, double scale) {
    final size = handle.pageSizes[page];
    final side = math.max(size.width, size.height);
    var step = stepOf(scale);
    while (step > -40 && side * scaleOf(step) > maxPixels) {
      step--;
    }
    return step;
  }

  /// The best bitmap of `page` for `scale` already rendered, and asks for the right one when it
  /// is missing.
  ui.Image? image(int page, double scale) {
    if (page < 0 || page >= handle.pageCount) return null;
    final step = _step(page, scale);
    final key = (page, step);
    final exact = _images.remove(key);
    if (exact != null) {
      _images[key] = exact;
      return exact;
    }
    _request(key);
    // The nearest step available: above first (reduced looks better than enlarged).
    ui.Image? best;
    var bestDistance = 1 << 30;
    for (final MapEntry(key: (p, s), value: image) in _images.entries) {
      if (p != page) continue;
      final distance = s >= step ? s - step : (step - s) * 2;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = image;
      }
    }
    return best;
  }

  void _request((int, int) key) {
    if (_failed.contains(key) || _rendering == key) return;
    _queue
      ..remove(key)
      ..add(key);
    // Only the most recent requests matter: the rest scrolled away.
    if (_queue.length > 24) _queue.removeRange(0, _queue.length - 24);
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_rendering != null || _queue.isEmpty || _disposed) return;
    final key = _queue.removeLast();
    _rendering = key;
    try {
      final (page, step) = key;
      final bitmap = await handle.render(page, scaleOf(step));
      if (_disposed) return;
      final image = await rgbaImage(
        bitmap.bgra,
        bitmap.width,
        bitmap.height,
        format: ui.PixelFormat.bgra8888,
      );
      if (_disposed) {
        image.dispose();
        return;
      }
      _images[key] = image;
      _bytes += image.width * image.height * 4;
      renders++;
      _evict();
      notifyListeners();
    } on Object {
      _failed.add(key);
    } finally {
      _rendering = null;
      if (!_disposed) unawaited(_pump());
    }
  }

  void _evict() {
    while (_bytes > maxBytes && _images.length > 1) {
      final oldest = _images.keys.first;
      final image = _images.remove(oldest)!;
      _bytes -= image.width * image.height * 4;
      image.dispose();
    }
  }

  /// Drops every bitmap (the document changed).
  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _queue.clear();
    _bytes = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}
