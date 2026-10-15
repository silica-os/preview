// The state of a Preview window and every action on it: what is open, which image or page is
// current, the zoom, the rotation, the sidebar, the page layout, search and text selection.
// The views only draw it; the toolbar, the shortcuts and the menus call the actions here.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../images/formats.dart';
import '../pdf/backend.dart';
import '../pdf/pages.dart';
import '../pdf/text.dart';
import '../style.dart';
import 'document.dart';

enum SidebarMode { none, thumbnails, contents }

enum PageLayout { continuous, single, two }

/// How the scale is chosen: the image at its size unless it is larger than the window
/// ([auto]), the whole image or page in the window ([fit]), the page width ([fitWidth]), or a
/// chosen scale ([manual]).
enum ZoomMode { auto, fit, fitWidth, manual }

class ViewerController extends ChangeNotifier {
  ViewerController({required this.loader});

  final DocumentLoader loader;

  Document? document;
  int current = 0;
  bool loading = false;

  /// Files that did not open, to tell the user once.
  final List<OpenException> failures = [];

  /// A PDF that needs its password ([passwordRetry]: the last one was wrong).
  String? passwordFor;
  bool passwordRetry = false;

  ZoomMode zoomMode = ZoomMode.auto;
  double _manualScale = 1;
  Size viewport = Size.zero;

  SidebarMode sidebar = SidebarMode.none;
  PageLayout layout = PageLayout.continuous;
  bool inspector = false;

  final ScrollController vertical = ScrollController();
  final ScrollController horizontal = ScrollController();

  PageImages? pages;

  // Search.
  bool searching = false;
  String query = '';
  final List<TextMatch> matches = [];
  int matchIndex = -1;
  bool searchDone = true;
  int _searchGeneration = 0;

  /// Selected text, one range per page.
  final List<PageSelection> selection = [];

  final Map<int, PdfTextLayout> _texts = {};
  final Map<int, Future<PdfTextLayout>> _textLoads = {};

  bool _disposed = false;

  // -------------------------------------------------------------------------------------------
  // What is open.

  ImageDocument? get images => switch (document) {
    final ImageDocument d => d,
    _ => null,
  };

  PdfItem? get pdf => switch (document) {
    final PdfDocument d => d.pdf,
    _ => null,
  };

  ImageItem? get image => images?.images[current];

  bool get isPdf => pdf != null;

  /// How many images or pages.
  int get count => document?.count ?? 0;

  /// Opens `paths` in this window, replacing what it showed. Images open together; a PDF opens
  /// alone (the first one when several are given; the rest are reported).
  Future<void> open(List<String> paths) async {
    if (paths.isEmpty) return;
    loading = true;
    failures.clear();
    _notify();
    final images = <ImageItem>[];
    String? pdfPath;
    for (final path in paths) {
      try {
        final (format, _) = await loader.probe(path);
        if (format == FileFormat.pdf) {
          if (pdfPath == null && images.isEmpty) {
            pdfPath = path;
          } else {
            failures.add(
              OpenException(path, OpenFailure.unsupported, 'one PDF at a time'),
            );
          }
          continue;
        }
        if (pdfPath != null) {
          failures.add(
            OpenException(path, OpenFailure.unsupported, 'with a PDF'),
          );
          continue;
        }
        images.add(await loader.image(path));
      } on OpenException catch (e) {
        failures.add(e);
      }
    }
    if (_disposed) {
      for (final i in images) {
        i.dispose();
      }
      return;
    }
    if (pdfPath != null) {
      await openPdf(pdfPath);
    } else if (images.isNotEmpty) {
      _show(ImageDocument(images));
      // Several images: the thumbnails are how to move between them.
      sidebar = images.length > 1 ? SidebarMode.thumbnails : SidebarMode.none;
    }
    loading = false;
    _notify();
  }

  /// Opens a PDF, with its password when it has one.
  Future<void> openPdf(String path, {String? password}) async {
    try {
      final item = await loader.pdfFile(path, password: password);
      if (_disposed) {
        await item.handle.close();
        return;
      }
      passwordFor = null;
      passwordRetry = false;
      _show(PdfDocument(item));
      sidebar = SidebarMode.none;
    } on OpenException catch (e) {
      if (e.failure == OpenFailure.encrypted) {
        passwordRetry = password != null;
        passwordFor = path;
      } else {
        failures.add(e);
      }
    }
    loading = false;
    _notify();
  }

  /// The password sheet was cancelled.
  void cancelPassword() {
    passwordFor = null;
    passwordRetry = false;
    _notify();
  }

  void _show(Document next) {
    document?.dispose();
    pages?.dispose();
    pages = null;
    document = next;
    current = 0;
    zoomMode = next is PdfDocument ? ZoomMode.fitWidth : ZoomMode.auto;
    _manualScale = 1;
    _texts.clear();
    _textLoads.clear();
    selection.clear();
    _clearSearch();
    searching = false;
    if (next is PdfDocument) {
      pages = PageImages(next.pdf.handle);
      layout = PageLayout.continuous;
    }
    _jump(0, 0);
  }

  /// The failures were shown.
  void clearFailures() {
    failures.clear();
    _notify();
  }

  // -------------------------------------------------------------------------------------------
  // Geometry. Lengths in logical pixels at the current scale unless named "points".

  double get margin =>
      isPdf ? PreviewMetrics.pageMargin : PreviewMetrics.imageMargin;

  /// The pages of spread `index` in the single and two-page layouts.
  List<int> spreadPages(int page) {
    if (layout != PageLayout.two) return [page];
    final first = page - page % 2;
    return [first, if (first + 1 < count) first + 1];
  }

  /// The size in points of what one screen shows: the current image, page or spread.
  Size get _unitSize {
    final item = pdf;
    if (item == null) return image?.turnedSize ?? Size.zero;
    if (count == 0) return Size.zero;
    final spread = spreadPages(current);
    var w = 0.0;
    var h = 0.0;
    for (final p in spread) {
      final s = item.pageSize(p);
      w += s.width;
      h = math.max(h, s.height);
    }
    return Size(w + PreviewMetrics.pageGap * (spread.length - 1), h);
  }

  /// The widest page, in points.
  double get _widestPage {
    final item = pdf;
    if (item == null) return 0;
    var w = 0.0;
    for (var i = 0; i < item.pageCount; i++) {
      w = math.max(w, item.pageSize(i).width);
    }
    return w;
  }

  double _fitScale({bool widthOnly = false}) {
    final unit = _unitSize;
    if (unit.isEmpty || viewport.isEmpty) return 1;
    final w =
        (viewport.width - 2 * margin) /
        (layout == PageLayout.continuous && isPdf && widthOnly
            ? _widestPage
            : unit.width);
    if (widthOnly)
      return w.clamp(PreviewMetrics.minZoom, PreviewMetrics.maxZoom);
    final h = (viewport.height - 2 * margin) / unit.height;
    return math.min(w, h).clamp(PreviewMetrics.minZoom, PreviewMetrics.maxZoom);
  }

  /// Pixels per point (images: per image pixel).
  double get scale => switch (zoomMode) {
    ZoomMode.manual => _manualScale,
    ZoomMode.fit => _fitScale(),
    ZoomMode.fitWidth => _fitScale(widthOnly: true),
    ZoomMode.auto => math.min(1, _fitScale()),
  };

  /// The view's size (the views tell it while laying out; no rebuild needed).
  void setViewport(Size size) {
    if (size == viewport) return;
    viewport = size;
  }

  /// Top of page `i` in the continuous layout.
  double pageTop(int i) {
    final item = pdf!;
    final s = scale;
    var y = margin;
    for (var j = 0; j < i && j < item.pageCount; j++) {
      y += item.pageSize(j).height * s + PreviewMetrics.pageGap;
    }
    return y;
  }

  /// The size of everything that scrolls.
  Size get contentSize {
    final s = scale;
    final item = pdf;
    if (item != null && layout == PageLayout.continuous) {
      final last = item.pageCount;
      final height = pageTop(last) - PreviewMetrics.pageGap + margin;
      return Size(_widestPage * s + 2 * margin, math.max(height, 0));
    }
    final unit = _unitSize;
    return Size(unit.width * s + 2 * margin, unit.height * s + 2 * margin);
  }

  // -------------------------------------------------------------------------------------------
  // Zoom.

  bool get canZoomIn =>
      document != null && scale < PreviewMetrics.maxZoom - 1e-9;
  bool get canZoomOut =>
      document != null && scale > PreviewMetrics.minZoom + 1e-9;

  void zoomIn() => zoomTo(scale * PreviewMetrics.zoomStep);
  void zoomOut() => zoomTo(scale / PreviewMetrics.zoomStep);
  void actualSize() => zoomTo(1);

  void zoomToFit() {
    if (document == null) return;
    _keepAnchor(
      () => zoomMode = isPdf && layout == PageLayout.continuous
          ? ZoomMode.fitWidth
          : ZoomMode.fit,
    );
  }

  /// A chosen scale, keeping the point `focal` of the view (its centre by default) in place.
  void zoomTo(double next, {Offset? focal}) {
    if (document == null) return;
    final clamped = next.clamp(PreviewMetrics.minZoom, PreviewMetrics.maxZoom);
    _keepAnchor(() {
      zoomMode = ZoomMode.manual;
      _manualScale = clamped;
    }, focal: focal);
  }

  /// Pinch and ⌘-scroll: multiplies the scale.
  void zoomBy(double factor, {Offset? focal}) =>
      zoomTo(scale * factor, focal: focal);

  /// Changes the scale with `change`, then scrolls so the content under `focal` stays there.
  void _keepAnchor(VoidCallback change, {Offset? focal}) {
    final f = focal ?? viewport.center(Offset.zero);
    final before = _contentPoint(f);
    change();
    _notify();
    if (before == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final after = _viewPoint(before);
      _jump(after.dy - f.dy, after.dx - f.dx);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  double _offset(ScrollController c) => c.hasClients ? c.offset : 0;

  /// The free space left and above the content when it is smaller than the view.
  Offset get _padding {
    final size = contentSize;
    return Offset(
      math.max(0, (viewport.width - size.width) / 2),
      math.max(0, (viewport.height - size.height) / 2),
    );
  }

  /// The view point `f` in content points: (page, x, y within the page) for PDFs in the
  /// continuous layout, (-1, x, y) otherwise.
  (int, double, double)? _contentPoint(Offset f) {
    if (document == null) return null;
    final s = scale;
    final pad = _padding;
    final x = (_offset(horizontal) + f.dx - pad.dx - margin) / s;
    final y = _offset(vertical) + f.dy - pad.dy;
    if (isPdf && layout == PageLayout.continuous) {
      final page = pageAtOffset(y);
      return (page, x, (y - pageTop(page)) / s);
    }
    return (-1, x, (y - margin) / s);
  }

  Offset _viewPoint((int, double, double) point) {
    final (page, x, y) = point;
    final s = scale;
    final pad = _padding;
    final top = page >= 0 ? pageTop(page) : margin;
    return Offset(x * s + margin + pad.dx, top + y * s + pad.dy);
  }

  void _jump(double y, double x) {
    if (vertical.hasClients) {
      final p = vertical.position;
      vertical.jumpTo(
        y.clamp(
          p.minScrollExtent,
          math.max(p.minScrollExtent, p.maxScrollExtent),
        ),
      );
    }
    if (horizontal.hasClients) {
      final p = horizontal.position;
      horizontal.jumpTo(
        x.clamp(
          p.minScrollExtent,
          math.max(p.minScrollExtent, p.maxScrollExtent),
        ),
      );
    }
  }

  /// The zoom as a percentage.
  int get percent => (scale * 100).round();

  // -------------------------------------------------------------------------------------------
  // Pages and images.

  /// The page at `y` (content offset) in the continuous layout.
  int pageAtOffset(double y) {
    final item = pdf;
    if (item == null) return 0;
    final s = scale;
    var top = margin;
    for (var i = 0; i < item.pageCount; i++) {
      final bottom = top + item.pageSize(i).height * s;
      if (y < bottom + PreviewMetrics.pageGap / 2) return i;
      top = bottom + PreviewMetrics.pageGap;
    }
    return math.max(0, item.pageCount - 1);
  }

  /// The continuous view scrolled: the current page is the one a third of the way down.
  void scrolled() {
    if (!isPdf || layout != PageLayout.continuous || !vertical.hasClients)
      return;
    final page = pageAtOffset(vertical.offset + viewport.height / 3);
    if (page != current) {
      current = page;
      _notify();
    }
  }

  bool get canGoBack => current > 0;
  bool get canGoForward =>
      isPdf ? spreadPages(current).last < count - 1 : current < count - 1;

  void previous() {
    if (!canGoBack) return;
    goTo(layout == PageLayout.two && isPdf ? current - 2 : current - 1);
  }

  void next() {
    if (!canGoForward) return;
    goTo(
      layout == PageLayout.two && isPdf
          ? spreadPages(current).last + 1
          : current + 1,
    );
  }

  void first() => goTo(0);
  void last() => goTo(count - 1);

  /// Shows image or page `index`.
  void goTo(int index) {
    if (document == null || count == 0) return;
    final target = index.clamp(0, count - 1);
    current = isPdf && layout == PageLayout.two ? target - target % 2 : target;
    _notify();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (isPdf && layout == PageLayout.continuous) {
        _jump(pageTop(current) - margin, _offset(horizontal));
      } else {
        _jump(0, _offset(horizontal));
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void setLayout(PageLayout next) {
    if (layout == next || !isPdf) return;
    final page = current;
    layout = next;
    if (zoomMode == ZoomMode.fitWidth && next != PageLayout.continuous) {
      zoomMode = ZoomMode.fit;
    }
    goTo(page);
  }

  void setSidebar(SidebarMode mode) {
    if (mode == SidebarMode.contents && !hasOutline) return;
    sidebar = mode;
    _notify();
  }

  /// The sidebar button: hides it, or shows the thumbnails (the last kind would be nicer;
  /// the reference behaviour is not measured).
  void toggleSidebar() => setSidebar(
    sidebar == SidebarMode.none ? SidebarMode.thumbnails : SidebarMode.none,
  );

  bool get hasOutline => pdf?.handle.outline.isNotEmpty ?? false;

  // -------------------------------------------------------------------------------------------
  // Rotation and flips.

  bool get canRotate => document != null;
  bool get canFlip => image != null;

  void rotateLeft() => _turn(3);
  void rotateRight() => _turn(1);

  void _turn(int quarters) {
    final item = image;
    final doc = pdf;
    if (item != null) {
      item.quarterTurns = (item.quarterTurns + quarters) % 4;
    } else if (doc != null) {
      doc.quarterTurns = (doc.quarterTurns + quarters) % 4;
      selection.clear();
    } else {
      return;
    }
    _notify();
  }

  void flipHorizontal() {
    final item = image;
    if (item == null) return;
    // A flip is drawn before the rotation: on a turned image it reads the other way.
    if (item.quarterTurns.isOdd) {
      item.flipVertical = !item.flipVertical;
    } else {
      item.flipHorizontal = !item.flipHorizontal;
    }
    _notify();
  }

  void flipVertical() {
    final item = image;
    if (item == null) return;
    if (item.quarterTurns.isOdd) {
      item.flipHorizontal = !item.flipHorizontal;
    } else {
      item.flipVertical = !item.flipVertical;
    }
    _notify();
  }

  // -------------------------------------------------------------------------------------------
  // Text: layout cache, search, selection.

  /// The text of `page` if already read.
  PdfTextLayout? textOf(int page) => _texts[page];

  /// Reads the text of `page`.
  Future<PdfTextLayout> loadText(int page) {
    final item = pdf;
    if (item == null) return Future.value(PdfTextLayout('', const []));
    final known = _texts[page];
    if (known != null) return Future.value(known);
    return _textLoads[page] ??= item.handle.text(page).then((t) {
      _texts[page] = t;
      _textLoads.remove(page);
      return t;
    });
  }

  void openSearch() {
    if (!isPdf) return;
    searching = true;
    _notify();
  }

  void closeSearch() {
    searching = false;
    _clearSearch();
    _notify();
  }

  void _clearSearch() {
    _searchGeneration++;
    query = '';
    matches.clear();
    matchIndex = -1;
    searchDone = true;
  }

  /// Finds `text` in every page; the first match from the current page on becomes current.
  Future<void> find(String text) async {
    final item = pdf;
    if (item == null) return;
    final generation = ++_searchGeneration;
    query = text;
    matches.clear();
    matchIndex = -1;
    if (text.trim().isEmpty) {
      searchDone = true;
      _notify();
      return;
    }
    searchDone = false;
    _notify();
    for (var page = 0; page < item.pageCount; page++) {
      final layout = await loadText(page);
      if (generation != _searchGeneration || _disposed) return;
      final found = findInLayout(page, layout, text);
      if (found.isEmpty) continue;
      matches.addAll(found);
      if (matchIndex < 0 && page >= current) {
        _showMatch(matches.length - found.length);
      }
      _notify();
    }
    searchDone = true;
    if (matchIndex < 0 && matches.isNotEmpty) _showMatch(0);
    _notify();
  }

  void findNext() {
    if (matches.isEmpty) return;
    _showMatch((matchIndex + 1) % matches.length);
  }

  void findPrevious() {
    if (matches.isEmpty) return;
    _showMatch((matchIndex - 1 + matches.length) % matches.length);
  }

  void _showMatch(int index) {
    matchIndex = index;
    final match = matches[index];
    if (spreadPages(current).contains(match.page) &&
        layout != PageLayout.continuous) {
      _notify();
      return;
    }
    if (layout != PageLayout.continuous) {
      goTo(match.page);
      return;
    }
    current = match.page;
    _notify();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final rects = rangeRects(_texts[match.page]!, match.start, match.end);
      final pageSize = pdf!.handle.pageSizes[match.page];
      final box = rects.isEmpty
          ? Rect.zero
          : turnRect(rects.first, pageSize, pdf!.quarterTurns);
      final y = pageTop(match.page) + box.top * scale;
      final view = _offset(vertical);
      if (y < view || y > view + viewport.height - 40) {
        _jump(y - viewport.height / 3, _offset(horizontal));
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Selects characters `a` to `b` of `page` (in any order), replacing the selection.
  void select(int page, int a, int b) {
    selection
      ..clear()
      ..add(PageSelection(page, math.min(a, b), math.max(a, b)));
    _notify();
  }

  void clearSelection() {
    if (selection.isEmpty) return;
    selection.clear();
    _notify();
  }

  bool get canCopy => selection.any((s) => !s.isEmpty);

  /// Selects all the text of the document.
  Future<void> selectAll() async {
    final item = pdf;
    if (item == null) return;
    final all = <PageSelection>[];
    for (var page = 0; page < item.pageCount; page++) {
      final layout = await loadText(page);
      if (_disposed || pdf != item) return;
      if (layout.length > 0) all.add(PageSelection(page, 0, layout.length));
    }
    selection
      ..clear()
      ..addAll(all);
    _notify();
  }

  /// The selected text, pages separated by a line break.
  String get selectedText => [
    for (final s in selection)
      if (_texts[s.page] case final layout?)
        layout.slice(s.start, s.end).trim(),
  ].where((t) => t.isNotEmpty).join('\n');

  // -------------------------------------------------------------------------------------------

  void toggleInspector() {
    if (document == null) return;
    inspector = !inspector;
    _notify();
  }

  void closeInspector() {
    inspector = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchGeneration++;
    document?.dispose();
    pages?.dispose();
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }
}

/// A rectangle on a page of `size` (points, unrotated) after `turns` quarter turns clockwise.
Rect turnRect(Rect r, Size size, int turns) => switch (turns % 4) {
  1 => Rect.fromLTRB(
    size.height - r.bottom,
    r.left,
    size.height - r.top,
    r.right,
  ),
  2 => Rect.fromLTRB(
    size.width - r.right,
    size.height - r.bottom,
    size.width - r.left,
    size.height - r.top,
  ),
  3 => Rect.fromLTRB(
    r.top,
    size.width - r.right,
    r.bottom,
    size.width - r.left,
  ),
  _ => r,
};

/// The inverse of [turnRect] for a point: from the turned page back to page points.
Offset unturnPoint(Offset p, Size size, int turns) => switch (turns % 4) {
  1 => Offset(p.dy, size.height - p.dx),
  2 => Offset(size.width - p.dx, size.height - p.dy),
  3 => Offset(size.width - p.dy, p.dx),
  _ => p,
};
