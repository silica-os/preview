// The state of a Preview window and every action on it: what is open, which image or page is
// current, the zoom, the rotation, the sidebar, the page layout, the page edits, search and text
// selection, and the undo history. The views only draw it; the toolbar, the shortcuts and the
// menus call the actions here.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'dart:io';

import '../export/export.dart' show saveImage;
import '../images/formats.dart';
import '../pdf/backend.dart';
import '../recent.dart';
import '../pdf/pages.dart';
import '../pdf/qpdf.dart';
import '../pdf/text.dart';
import '../style.dart';
import 'document.dart';
import 'history.dart';
import 'markup.dart';

enum SidebarMode { none, thumbnails, contents, notes, bookmarks, contactSheet }

enum PageLayout { continuous, single, two }

/// How the scale is chosen: the image at its size unless it is larger than the window
/// ([auto]), the whole image or page in the window ([fit]), the page width ([fitWidth]), or a
/// chosen scale ([manual]).
enum ZoomMode { auto, fit, fitWidth, manual }

/// How several images are sorted (the thumbnail menu's Sort By).
enum ImageOrder { name, path, date, size, kind }

/// The order of the search results in the sidebar: by number of matches or by page.
enum SearchOrder { rank, page }

/// A highlight colour, or an underline or strikethrough (PREVIEW-02 › Highlight).
class MarkupStyle {
  const MarkupStyle(this.kind, [this.colour = HighlightColour.yellow]);
  final PdfMarkupKind kind;
  final HighlightColour colour;

  /// Underlines and strikethroughs are red. *Provisional.*
  int get argb =>
      kind == PdfMarkupKind.highlight ? colour.color.toARGB32() : 0xFFE5322D;

  @override
  bool operator ==(Object other) =>
      other is MarkupStyle && other.kind == kind && other.colour == colour;

  @override
  int get hashCode => Object.hash(kind, colour);
}

class ViewerController extends ChangeNotifier {
  ViewerController({required this.loader});

  final DocumentLoader loader;

  Document? document;
  int current = 0;
  bool loading = false;

  /// Files that did not open, to tell the user once.
  final List<OpenException> failures = [];

  /// A PDF that needs its password ([passwordRetry]: the last one was wrong). The window shows
  /// the password view in place of the pages.
  String? passwordFor;
  bool passwordRetry = false;
  int passwordAttempts = 0;

  ZoomMode zoomMode = ZoomMode.auto;
  double _manualScale = 1;
  Size viewport = Size.zero;

  /// Whether zoom steps animate (tests without frames turn it off).
  bool animate = true;

  /// The display's pixels per inch, when the system tells it: a PDF's actual size is its
  /// physical size. Unknown, a PDF point is a pixel.
  double? displayPpi;

  SidebarMode sidebar = SidebarMode.none;
  SidebarMode _lastSidebar = SidebarMode.thumbnails;
  double sidebarWidth = PreviewMetrics.sidebarWidth;

  /// The keyboard focus is in the sidebar (its selection shows in the accent colour).
  bool sidebarFocused = false;

  PageLayout layout = PageLayout.continuous;
  bool inspector = false;

  final ScrollController vertical = ScrollController();
  final ScrollController horizontal = ScrollController();

  PageImages? pages;

  /// Undo, redo and the "Edited" state.
  final EditHistory history = EditHistory();

  // Search.
  bool searching = false;
  String query = '';
  final List<TextMatch> matches = [];
  int matchIndex = -1;
  bool searchDone = true;
  SearchOrder searchOrder = SearchOrder.rank;
  int _searchGeneration = 0;

  /// Selected text, one range per page.
  final List<PageSelection> selection = [];

  /// Text layouts by page of the file.
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

  /// Several files in the window.
  bool get several => (images?.images.length ?? 0) > 1;

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
        images.addAll(await loader.images(path));
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
      if (pdf != null) RecentFiles.add(pdfPath);
    } else if (images.isNotEmpty) {
      _show(ImageDocument(images));
      for (final path in {for (final i in images) i.path}.toList().reversed) {
        RecentFiles.add(path);
      }
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
      _openedBookmarks = item.pages.any((p) => p.bookmarked);
      // PDFs open with the sidebar: the table of contents when the file asks for it.
      sidebar = opensWithOutline(item.handle)
          ? SidebarMode.contents
          : SidebarMode.thumbnails;
    } on OpenException catch (e) {
      if (e.failure == OpenFailure.encrypted) {
        passwordRetry = password != null;
        if (password != null) passwordAttempts++;
        passwordFor = path;
      } else {
        failures.add(e);
      }
    }
    loading = false;
    _notify();
  }

  /// The password view was closed without a password.
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
    history.clear();
    _back.clear();
    _forward.clear();
    _annots.clear();
    _annotLoads.clear();
    chosenAnnotation = null;
    chosenShape = null;
    highlighting = false;
    imageOrder = null;
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

  /// The pages shown together with `page` in the single and two-page layouts. Two pages are a
  /// book: the first page alone, then 2–3, 4–5…
  List<int> spreadPages(int page) {
    if (layout != PageLayout.two || !isPdf) return [page];
    if (page <= 0) return [0];
    final first = page.isOdd ? page : page - 1;
    return [first, if (first + 1 < count) first + 1];
  }

  /// The size in points of what one screen shows: the current image, page or spread.
  Size get _unitSize {
    final item = pdf;
    if (item == null) return image?.turnedSize ?? Size.zero;
    if (count == 0) return Size.zero;
    var w = 0.0;
    var h = 0.0;
    for (final p in spreadPages(current)) {
      final s = item.pageSize(p);
      w += s.width;
      h = math.max(h, s.height);
    }
    return Size(w, h);
  }

  /// The widest page, in points.
  double get widestPage {
    final item = pdf;
    if (item == null) return 0;
    var w = 0.0;
    for (var i = 0; i < item.pageCount; i++) {
      w = math.max(w, item.pageSize(i).width);
    }
    return w;
  }

  /// Pixels per point at actual size: a PDF at its physical size on the display, an image
  /// pixel per point.
  double get actualScale =>
      isPdf ? (displayPpi ?? PreviewMetrics.pdfPointsPerInch) / 72 : 1;

  double get minScale => PreviewMetrics.minZoom * actualScale;
  double get maxScale => PreviewMetrics.maxZoom * actualScale;

  double _fitScale({bool widthOnly = false}) {
    final unit = _unitSize;
    if (unit.isEmpty || viewport.isEmpty) return 1;
    final w =
        (viewport.width - 2 * margin) /
        (layout == PageLayout.continuous && isPdf && widthOnly
            ? widestPage
            : unit.width);
    if (widthOnly) return w.clamp(minScale, maxScale);
    final h = (viewport.height - 2 * margin) / unit.height;
    return math.min(w, h).clamp(minScale, maxScale);
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
      return Size(widestPage * s + 2 * margin, math.max(height, 0));
    }
    final unit = _unitSize;
    return Size(unit.width * s + 2 * margin, unit.height * s + 2 * margin);
  }

  // -------------------------------------------------------------------------------------------
  // Zoom: steps of actual size (PDFs also stop at the fitted width), animated.

  /// The scales the zoom buttons go through.
  List<double> get zoomStops {
    final a = actualScale;
    final stops = [for (final z in PreviewMetrics.zoomSteps) z * a];
    if (isPdf && !viewport.isEmpty) {
      final fit = layout == PageLayout.continuous
          ? _fitScale(widthOnly: true)
          : _fitScale();
      if (!stops.any((s) => (s - fit).abs() < 1e-6)) stops.add(fit);
      stops.sort();
    }
    return stops;
  }

  double? _zoomFrom;
  double? _zoomTo;
  Duration? _zoomStart;
  Duration _zoomLength = Duration.zero;
  Offset? _zoomFocal;
  int _zoomFrame = 0;

  /// The scale being animated to, or the scale.
  double get _goal => _zoomTo ?? scale;

  bool get canZoomIn => document != null && _goal < maxScale * (1 - 1e-9);
  bool get canZoomOut => document != null && _goal > minScale * (1 + 1e-9);

  /// At actual size (the toolbar's actual size segment is disabled).
  bool get atActualSize =>
      document != null && (_goal - actualScale).abs() < 1e-6;

  void zoomIn() {
    final from = _goal;
    final next = zoomStops.where((s) => s > from * (1 + 1e-6));
    if (next.isEmpty) return;
    animateZoom(next.first);
  }

  void zoomOut() {
    final from = _goal;
    final next = zoomStops.where((s) => s < from * (1 - 1e-6));
    if (next.isEmpty) return;
    animateZoom(next.last);
  }

  /// Actual size: one image pixel per point, a PDF at its physical size. The toolbar's segment
  /// animates faster than the menu.
  void actualSize({bool fromToolbar = false}) => animateZoom(
    actualScale,
    duration: fromToolbar
        ? PreviewMetrics.actualSizeAnimation
        : PreviewMetrics.zoomAnimation,
  );

  void zoomToFit() {
    if (document == null) return;
    _stopZoom();
    _keepAnchor(
      () => zoomMode = isPdf && layout == PageLayout.continuous
          ? ZoomMode.fitWidth
          : ZoomMode.fit,
    );
  }

  /// A chosen scale at once, keeping the point `focal` of the view (its centre by default) in
  /// place.
  void zoomTo(double next, {Offset? focal}) {
    if (document == null) return;
    _stopZoom();
    _setScale(next, focal: focal);
  }

  void _setScale(double next, {Offset? focal}) {
    final clamped = next.clamp(minScale, maxScale);
    _keepAnchor(() {
      zoomMode = ZoomMode.manual;
      _manualScale = clamped;
    }, focal: focal);
  }

  /// Zooms to `target` in `duration` (the measured zoom step), easing in and out.
  void animateZoom(
    double target, {
    Duration duration = PreviewMetrics.zoomAnimation,
    Offset? focal,
  }) {
    if (document == null) return;
    final to = target.clamp(minScale, maxScale);
    final from = scale;
    if ((to - from).abs() < 1e-9) {
      _stopZoom();
      zoomTo(to, focal: focal);
      return;
    }
    if (!animate ||
        duration == Duration.zero ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
      zoomTo(to, focal: focal);
      return;
    }
    _zoomFrom = from;
    _zoomTo = to;
    _zoomStart = null;
    _zoomLength = duration;
    _zoomFocal = focal;
    final frame = ++_zoomFrame;
    _notify();
    SchedulerBinding.instance.scheduleFrameCallback((t) => _zoomStep(t, frame));
  }

  void _zoomStep(Duration now, int frame) {
    if (_disposed || frame != _zoomFrame) return;
    final from = _zoomFrom;
    final to = _zoomTo;
    if (from == null || to == null) return;
    final start = _zoomStart ??= now;
    final total = _zoomLength.inMicroseconds;
    final t = total <= 0
        ? 1.0
        : ((now - start).inMicroseconds / total).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(t);
    // In log space: every step looks as fast at any scale.
    final s = math.exp(
      math.log(from) + (math.log(to) - math.log(from)) * eased,
    );
    _setScale(t >= 1 ? to : s, focal: _zoomFocal);
    if (t >= 1) {
      _stopZoom();
      _notify();
      return;
    }
    SchedulerBinding.instance.scheduleFrameCallback((t) => _zoomStep(t, frame));
  }

  void _stopZoom() {
    _zoomFrame++;
    _zoomFrom = null;
    _zoomTo = null;
    _zoomStart = null;
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
      if (_disposed) return;
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

  /// The zoom as a percentage of actual size.
  int get percent => (scale / actualScale * 100).round();

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
    if (!isPdf || layout != PageLayout.continuous || !vertical.hasClients) {
      return;
    }
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
    goTo(
      layout == PageLayout.two && isPdf
          ? spreadPages(current).first - 1
          : current - 1,
    );
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
    current = isPdf && layout == PageLayout.two
        ? spreadPages(target).first
        : target;
    _notify();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (isPdf && layout == PageLayout.continuous) {
        _jump(pageTop(current) - margin, _offset(horizontal));
      } else {
        _jump(0, _offset(horizontal));
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Page Up and Page Down: a screen at once (no animation) in the continuous layout, a page
  /// (or spread) otherwise.
  void scrollPage(int direction) {
    if (isPdf && layout == PageLayout.continuous && vertical.hasClients) {
      final p = vertical.position;
      vertical.jumpTo(
        (p.pixels + direction * viewport.height * 0.9).clamp(
          p.minScrollExtent,
          p.maxScrollExtent,
        ),
      );
      scrolled();
      return;
    }
    direction < 0 ? previous() : next();
  }

  // Back and Forward: the pages jumped from (a thumbnail, an entry of the contents, a search
  // result, Go to Page).
  final List<int> _back = [];
  final List<int> _forward = [];

  bool get canGoBackInHistory => _back.isNotEmpty;
  bool get canGoForwardInHistory => _forward.isNotEmpty;

  /// Goes to `index`, remembering where it was for Back.
  void jumpTo(int index) {
    if (document == null || index == current) {
      goTo(index);
      return;
    }
    _back.add(current);
    _forward.clear();
    goTo(index);
  }

  void back() {
    if (_back.isEmpty) return;
    _forward.add(current);
    goTo(_back.removeLast());
  }

  void forward() {
    if (_forward.isEmpty) return;
    _back.add(current);
    goTo(_forward.removeLast());
  }

  void setLayout(PageLayout next) {
    if (layout == next || !isPdf) return;
    final page = current;
    layout = next;
    if (zoomMode == ZoomMode.fitWidth && next != PageLayout.continuous) {
      zoomMode = ZoomMode.fit;
    } else if (zoomMode == ZoomMode.fit && next == PageLayout.continuous) {
      zoomMode = ZoomMode.fitWidth;
    }
    goTo(page);
  }

  // -------------------------------------------------------------------------------------------
  // Sidebar.

  /// Whether the sidebar can show `mode` for what is open.
  bool canShowSidebar(SidebarMode mode) => switch (mode) {
    SidebarMode.none || SidebarMode.thumbnails => document != null,
    SidebarMode.contents => hasOutline,
    SidebarMode.notes || SidebarMode.bookmarks => isPdf,
    SidebarMode.contactSheet => document != null && count > 1,
  };

  void setSidebar(SidebarMode mode) {
    if (!canShowSidebar(mode)) return;
    if (sidebar != SidebarMode.none) _lastSidebar = sidebar;
    sidebar = mode;
    if (mode != SidebarMode.none) _lastSidebar = mode;
    _notify();
  }

  /// Hides the sidebar, or brings back the last kind it showed.
  void toggleSidebar() => setSidebar(
    sidebar == SidebarMode.none
        ? (canShowSidebar(_lastSidebar) ? _lastSidebar : SidebarMode.thumbnails)
        : SidebarMode.none,
  );

  /// Drags the sidebar's edge: 160 to 400 pt.
  void resizeSidebar(double width) {
    final w = width.clamp(
      PreviewMetrics.sidebarMinWidth,
      PreviewMetrics.sidebarMaxWidth,
    );
    if (w == sidebarWidth) return;
    sidebarWidth = w;
    _notify();
  }

  void focusSidebar(bool focused) {
    if (sidebarFocused == focused) return;
    sidebarFocused = focused;
    _notify();
  }

  bool get hasOutline => pdf?.handle.outline.isNotEmpty ?? false;

  // -------------------------------------------------------------------------------------------
  // Edits, undo and redo.

  bool get edited => history.edited;

  void undo() {
    history.undo();
    _afterEdit();
  }

  void redo() {
    history.redo();
    _afterEdit();
  }

  /// Applies `redo`, records it with its `undo`. A change Preview cannot write to the file
  /// (an image in a format it does not encode) is applied to the view only: not recorded.
  void _edit(VoidCallback redo, VoidCallback undo, {bool record = true}) {
    redo();
    if (record) history.record(Edit(undo: undo, redo: redo));
    _afterEdit();
  }

  void _afterEdit() {
    if (isPdf) {
      current = current.clamp(0, math.max(0, count - 1));
      selection.clear();
      if (matches.isNotEmpty || query.isNotEmpty) {
        final text = query;
        _clearSearch();
        if (searching && text.isNotEmpty) unawaited(find(text));
      }
    }
    _notify();
  }

  /// The document was written: no longer edited.
  void markSaved() {
    history.saved();
    _notify();
  }

  // -------------------------------------------------------------------------------------------
  // Rotation and flips.

  bool get canRotate => document != null;
  bool get canFlip => image != null;

  /// The direction of the last rotation or flip (the image view animates it).
  int lastTurn = 0;
  bool lastFlip = false;
  int turnCount = 0;

  void rotateLeft() => _turn(3);
  void rotateRight() => _turn(1);

  void _turn(int quarters) {
    final item = image;
    final doc = pdf;
    if (item != null) {
      void apply(int q) {
        item.quarterTurns = (item.quarterTurns + q) % 4;
        lastTurn = q == 1 ? 1 : -1;
        lastFlip = false;
        turnCount++;
      }

      _edit(
        () => apply(quarters),
        () => apply(4 - quarters),
        record: item.writable,
      );
    } else if (doc != null) {
      // The current page (both of a spread).
      final targets = [for (final p in spreadPages(current)) doc.pages[p]];
      void apply(int q) {
        for (final page in targets) {
          page.quarterTurns = (page.quarterTurns + q) % 4;
        }
      }

      _edit(() => apply(quarters), () => apply(4 - quarters));
    }
  }

  void flipHorizontal() {
    final item = image;
    if (item == null) return;
    // A flip is drawn before the rotation: on a turned image it reads the other way.
    void apply() {
      if (item.quarterTurns.isOdd) {
        item.flipVertical = !item.flipVertical;
      } else {
        item.flipHorizontal = !item.flipHorizontal;
      }
      lastFlip = true;
      lastTurn = 0;
      turnCount++;
    }

    _edit(apply, apply, record: item.writable);
  }

  void flipVertical() {
    final item = image;
    if (item == null) return;
    void apply() {
      if (item.quarterTurns.isOdd) {
        item.flipHorizontal = !item.flipHorizontal;
      } else {
        item.flipVertical = !item.flipVertical;
      }
      lastFlip = true;
      lastTurn = 0;
      turnCount++;
    }

    _edit(apply, apply, record: item.writable);
  }

  // -------------------------------------------------------------------------------------------
  // PDF pages: delete, insert a blank page, move, bookmarks.

  bool get canDeletePage => isPdf && count > 1;

  /// Removes the current page.
  void deletePage() {
    final doc = pdf;
    if (doc == null || doc.pageCount < 2) return;
    final at = current;
    final page = doc.pages[at];
    _edit(
      () {
        doc.pages.removeAt(at);
        current = math.min(at, doc.pageCount - 1);
      },
      () {
        doc.pages.insert(at, page);
        current = at;
      },
    );
  }

  /// Inserts a blank page the size of the current one after it, and makes it current.
  void insertBlankPage() {
    final doc = pdf;
    if (doc == null) return;
    final at = current + 1;
    final page = PdfPage.blank(doc.ownSize(current))
      ..quarterTurns = doc.turnsOf(current);
    _edit(
      () {
        doc.pages.insert(at, page);
        current = at;
      },
      () {
        doc.pages.removeAt(at);
        current = at - 1;
      },
    );
  }

  /// Moves page `from` to index `to` (in the list without it).
  void movePage(int from, int to) {
    final doc = pdf;
    if (doc == null || from == to) return;
    if (from < 0 || from >= doc.pageCount) return;
    final target = to.clamp(0, doc.pageCount - 1);
    void move(int a, int b) {
      final page = doc.pages.removeAt(a);
      doc.pages.insert(b, page);
      current = b;
    }

    _edit(() => move(from, target), () => move(target, from));
  }

  bool get currentBookmarked =>
      isPdf && count > 0 && pdf!.pages[current].bookmarked;

  /// Adds a bookmark on the current page, or removes it.
  void toggleBookmark() {
    final doc = pdf;
    if (doc == null || count == 0) return;
    final page = doc.pages[current];
    void flip() => page.bookmarked = !page.bookmarked;
    _edit(flip, flip);
  }

  /// The bookmarked pages, in order.
  List<int> get bookmarks => [
    for (final (i, p) in (pdf?.pages ?? const <PdfPage>[]).indexed)
      if (p.bookmarked) i,
  ];

  // -------------------------------------------------------------------------------------------
  // Text: layout cache, search, selection.

  /// The page of the file shown as page `page`, null for a blank page.
  int? sourceOf(int page) {
    final item = pdf;
    if (item == null || page < 0 || page >= item.pageCount) return null;
    return item.pages[page].source;
  }

  /// The text of `page` if already read.
  PdfTextLayout? textOf(int page) {
    final source = sourceOf(page);
    if (source == null) return isPdf ? _empty : null;
    return _texts[source];
  }

  static final PdfTextLayout _empty = PdfTextLayout('', const []);

  /// Reads the text of `page`.
  Future<PdfTextLayout> loadText(int page) {
    final item = pdf;
    final source = sourceOf(page);
    if (item == null || source == null) return Future.value(_empty);
    final known = _texts[source];
    if (known != null) return Future.value(known);
    return _textLoads[source] ??= item.handle.text(source).then((t) {
      _texts[source] = t;
      _textLoads.remove(source);
      return t;
    });
  }

  void openSearch() {
    if (!isPdf) return;
    searching = true;
    _notify();
  }

  /// Done: the find bar and the results go away.
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
    searching = true;
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

  /// The pages with matches and how many each has, in the chosen order.
  List<(int, int)> get resultPages {
    final counts = <int, int>{};
    for (final m in matches) {
      counts[m.page] = (counts[m.page] ?? 0) + 1;
    }
    final out = [for (final e in counts.entries) (e.key, e.value)];
    if (searchOrder == SearchOrder.rank) {
      out.sort((a, b) => b.$2 != a.$2 ? b.$2 - a.$2 : a.$1 - b.$1);
    } else {
      out.sort((a, b) => a.$1 - b.$1);
    }
    return out;
  }

  void setSearchOrder(SearchOrder order) {
    if (searchOrder == order) return;
    searchOrder = order;
    _notify();
  }

  /// Shows the first match of `page`.
  void showResult(int page) {
    final i = matches.indexWhere((m) => m.page == page);
    if (i < 0) return;
    if (page != current) {
      _back.add(current);
      _forward.clear();
    }
    _showMatch(i);
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
      final item = pdf;
      final layout = textOf(match.page);
      if (_disposed || item == null || layout == null) return;
      if (match.page >= item.pageCount) return;
      final rects = rangeRects(layout, match.start, match.end);
      final box = rects.isEmpty
          ? Rect.zero
          : turnRect(
              rects.first,
              item.ownSize(match.page),
              item.turnsOf(match.page),
            );
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
      if (textOf(s.page) case final layout?)
        layout.slice(s.start, s.end).trim(),
  ].where((t) => t.isNotEmpty).join('\n');

  // -------------------------------------------------------------------------------------------
  // PDF annotations: highlights, underlines, strikethroughs and notes, written into the file
  // when it is saved.

  /// The annotations by page of the file, once read.
  final Map<int, List<PdfAnnotation>> _annots = {};
  final Set<int> _annotLoads = {};

  /// Highlighting: a text selection becomes a markup of [markupStyle] when the drag ends.
  bool highlighting = false;
  MarkupStyle markupStyle = const MarkupStyle(PdfMarkupKind.highlight);

  /// The chosen annotation (a click on it), as (page, id).
  (int, int)? chosenAnnotation;

  /// The author written into new annotations.
  String author = Platform.environment['USER'] ?? '';

  /// The annotations of `page` when read (a read starts otherwise).
  List<PdfAnnotation> annotationsOf(int page) {
    final source = sourceOf(page);
    if (source == null) return const [];
    final known = _annots[source];
    if (known != null) return known;
    _loadAnnotations(source);
    return const [];
  }

  /// Reads the annotations of every page (the Highlights and Notes list).
  Future<void> loadAllAnnotations() async {
    final item = pdf;
    if (item == null) return;
    for (var page = 0; page < item.pageCount; page++) {
      final source = sourceOf(page);
      if (source == null || _annots.containsKey(source)) continue;
      await _loadAnnotations(source);
      if (_disposed || pdf != item) return;
    }
  }

  Future<void> _loadAnnotations(int source) async {
    final item = pdf;
    if (item == null || !_annotLoads.add(source)) return;
    try {
      final list = await item.handle.annotations(source);
      if (_disposed || pdf != item) return;
      _annots[source] = list;
      _notify();
    } on Object {
      _annots[source] = const [];
    } finally {
      _annotLoads.remove(source);
    }
  }

  /// Every annotation read so far, in page order: (page, annotation).
  List<(int, PdfAnnotation)> get allAnnotations => [
    for (var page = 0; page < count; page++)
      if (sourceOf(page) case final source? when _annots[source] != null)
        for (final a in _annots[source]!) (page, a),
  ];

  /// Whether the PDF allows annotations (its permissions), and they can be put on the current
  /// page (not a blank page added in Preview).
  bool get canAnnotate =>
      isPdf && (pdf!.security?.annotating ?? true) && sourceOf(current) != null;

  /// The toolbar's highlight button: turns highlighting on or off; turning it on with text
  /// selected marks that text at once.
  void toggleHighlighting() {
    if (!isPdf) return;
    highlighting = !highlighting;
    if (highlighting && canCopy && canAnnotate) unawaited(markSelection());
    _notify();
  }

  /// Chooses the highlight colour or style; with a selection, marks it at once.
  void setMarkupStyle(MarkupStyle style) {
    markupStyle = style;
    highlighting = true;
    if (canCopy) unawaited(markSelection());
    _notify();
  }

  /// Marks the selected text with [markupStyle] (one annotation per page).
  Future<void> markSelection({MarkupStyle? style}) async {
    final item = pdf;
    if (item == null) return;
    final use = style ?? markupStyle;
    final added = <(int, PdfAnnotation)>[];
    for (final s in [...selection]) {
      final source = sourceOf(s.page);
      final layout = textOf(s.page);
      if (source == null || layout == null || s.isEmpty) continue;
      final rects = rangeRects(layout, s.start, s.end);
      if (rects.isEmpty) continue;
      final a = await item.handle.addMarkup(
        source,
        use.kind,
        rects,
        use.argb,
        author: author,
      );
      added.add((source, a));
    }
    if (_disposed || pdf != item || added.isEmpty) return;
    selection.clear();
    await _refreshAnnotations({for (final (s, _) in added) s});
    _recordAnnotations(item, added);
  }

  /// Records annotations already added: undo removes them, redo adds them again.
  void _recordAnnotations(PdfItem item, List<(int, PdfAnnotation)> added) {
    var current = added;
    history.record(
      Edit(
        undo: () async {
          for (final (source, a) in current) {
            await item.handle.removeAnnotation(source, a.id);
          }
          await _refreshAnnotations({for (final (s, _) in current) s});
          _notify();
        },
        redo: () async {
          final again = <(int, PdfAnnotation)>[];
          for (final (source, a) in current) {
            final b = a.kind == PdfMarkupKind.note
                ? await item.handle.addNote(
                    source,
                    a.bounds.topLeft,
                    a.argb,
                    author: a.author,
                    contents: a.contents,
                  )
                : await item.handle.addMarkup(
                    source,
                    a.kind,
                    a.quads,
                    a.argb,
                    author: a.author,
                    contents: a.contents,
                  );
            again.add((source, b));
          }
          current = again;
          await _refreshAnnotations({for (final (s, _) in again) s});
          _notify();
        },
      ),
    );
    _notify();
  }

  Future<void> _refreshAnnotations(Set<int> sources) async {
    final item = pdf;
    if (item == null) return;
    for (final source in sources) {
      _annots[source] = await item.handle.annotations(source);
    }
    pages?.clear();
    _notify();
  }

  /// Adds a note on the current page, at `at` (page points) or near its top left.
  Future<PdfAnnotation?> addNote({Offset? at, String contents = ''}) async {
    final item = pdf;
    final source = sourceOf(current);
    if (item == null || source == null) return null;
    final a = await item.handle.addNote(
      source,
      at ?? const Offset(36, 36),
      0xFFFFD60A,
      author: author,
      contents: contents,
    );
    if (_disposed || pdf != item) return null;
    await _refreshAnnotations({source});
    chosenAnnotation = (current, a.id);
    _recordAnnotations(item, [(source, a)]);
    return a;
  }

  /// Changes an annotation's colour or text.
  Future<void> updateAnnotation(
    int page,
    PdfAnnotation a, {
    int? argb,
    String? contents,
  }) async {
    final item = pdf;
    final source = sourceOf(page);
    if (item == null || source == null) return;
    final before = (a.argb, a.contents);
    await item.handle.updateAnnotation(
      source,
      a.id,
      argb: argb,
      contents: contents,
    );
    await _refreshAnnotations({source});
    history.record(
      Edit(
        undo: () => unawaited(
          item.handle
              .updateAnnotation(
                source,
                a.id,
                argb: before.$1,
                contents: before.$2,
              )
              .then((_) => _refreshAnnotations({source})),
        ),
        redo: () => unawaited(
          item.handle
              .updateAnnotation(source, a.id, argb: argb, contents: contents)
              .then((_) => _refreshAnnotations({source})),
        ),
      ),
    );
    _notify();
  }

  /// Removes an annotation (undo puts it back).
  Future<void> removeAnnotation(int page, PdfAnnotation a) async {
    final item = pdf;
    final source = sourceOf(page);
    if (item == null || source == null) return;
    await item.handle.removeAnnotation(source, a.id);
    await _refreshAnnotations({source});
    if (chosenAnnotation == (page, a.id)) chosenAnnotation = null;
    var gone = a;
    history.record(
      Edit(
        undo: () async {
          gone = a.kind == PdfMarkupKind.note
              ? await item.handle.addNote(
                  source,
                  gone.bounds.topLeft,
                  gone.argb,
                  author: gone.author,
                  contents: gone.contents,
                )
              : await item.handle.addMarkup(
                  source,
                  gone.kind,
                  gone.quads,
                  gone.argb,
                  author: gone.author,
                  contents: gone.contents,
                );
          await _refreshAnnotations({source});
        },
        redo: () async {
          await item.handle.removeAnnotation(source, gone.id);
          await _refreshAnnotations({source});
        },
      ),
    );
    _notify();
  }

  void chooseAnnotation((int, int)? which) {
    chosenAnnotation = which;
    _notify();
  }

  // -------------------------------------------------------------------------------------------
  // Several images: close one, sort them.

  /// The order of the images (null: as opened).
  ImageOrder? imageOrder;

  /// Takes image `index` out of the window (its file is not touched).
  void closeImage(int index) {
    final doc = images;
    if (doc == null || doc.images.length < 2) return;
    if (index < 0 || index >= doc.images.length) return;
    // The document lets go of its pixels when it closes.
    doc.images.removeAt(index);
    current = current.clamp(0, doc.images.length - 1);
    _notify();
  }

  /// Sorts the images (null: back to the order they were opened in).
  void sortImages(ImageOrder? order) {
    final doc = images;
    if (doc == null) return;
    final shown = doc.images[current];
    imageOrder = order;
    int compare(ImageItem a, ImageItem b) => switch (order) {
      ImageOrder.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      ImageOrder.path => a.path.compareTo(b.path),
      ImageOrder.date => _modified(a).compareTo(_modified(b)),
      ImageOrder.size => a.fileSize.compareTo(b.fileSize),
      ImageOrder.kind => a.format.label.compareTo(b.format.label),
      null => doc.opened.indexOf(a).compareTo(doc.opened.indexOf(b)),
    };
    doc.images.sort(compare);
    current = doc.images.indexOf(shown);
    _notify();
  }

  static DateTime _modified(ImageItem item) {
    try {
      return File(item.path).lastModifiedSync();
    } on FileSystemException {
      return DateTime(0);
    }
  }

  // -------------------------------------------------------------------------------------------
  // Image markup, Adjust Size.

  /// The chosen shape of the current image.
  MarkupShape? chosenShape;

  /// The style new shapes get: the last one chosen in the markup toolbar.
  final MarkupShape shapeTemplate = MarkupShape(
    kind: ShapeKind.rectangle,
    a: Offset.zero,
    b: Offset.zero,
  );

  /// Changes the style of the chosen shape (recorded) and of the shapes to come.
  void styleShape(void Function(MarkupShape shape) change) {
    change(shapeTemplate);
    final item = image;
    final shape = chosenShape;
    if (item != null && shape != null && item.markup.contains(shape)) {
      final before = [for (final s in item.markup) s.copy()];
      change(shape);
      final index = item.markup.indexOf(shape);
      recordMarkup(item, before);
      chosenShape = item.markup[index];
    }
    _notify();
  }

  /// Records a change of the current image's markup from `before` to its present state.
  void recordMarkup(ImageItem item, List<MarkupShape> before) {
    final after = [for (final s in item.markup) s.copy()];
    final was = [for (final s in before) s.copy()];
    void put(List<MarkupShape> shapes) {
      item.markup
        ..clear()
        ..addAll([for (final s in shapes) s.copy()]);
      chosenShape = null;
    }

    history.record(Edit(undo: () => put(was), redo: () => put(after)));
    _notify();
  }

  /// Adds `shape` to the current image, chosen.
  void addShape(MarkupShape shape) {
    final item = image;
    if (item == null || !item.writable) return;
    final before = [for (final s in item.markup) s.copy()];
    item.markup.add(shape);
    recordMarkup(item, before);
    chosenShape = shape;
    _notify();
  }

  /// Removes the chosen shape.
  void deleteShape() {
    final item = image;
    final shape = chosenShape;
    if (item == null || shape == null) return;
    final before = [for (final s in item.markup) s.copy()];
    item.markup.remove(shape);
    recordMarkup(item, before);
  }

  void chooseShape(MarkupShape? shape) {
    chosenShape = shape;
    _notify();
  }

  /// Adjust Size: the current image's new size in pixels.
  void resizeImage(Size size) {
    final item = image;
    if (item == null || !item.writable || size.isEmpty) return;
    final before = item.resized;
    final after = size == item.content.size ? null : size;
    if (before == after) return;
    _edit(() => item.resized = after, () => item.resized = before);
  }

  // -------------------------------------------------------------------------------------------
  // Files: save, revert, rename, keywords, permissions.

  /// The file as it was opened, kept before the first save over it (Revert To › Last Opened).
  final Map<String, String> _originals = {};

  /// Whether Revert can bring the file back as it was opened.
  bool get canRevert =>
      document != null &&
      (edited || _originalsOf().any(_originals.containsKey));

  List<String> _originalsOf() => switch (document) {
    ImageDocument(:final images) => [for (final i in images) i.path],
    PdfDocument(:final pdf) => [pdf.path],
    null => const [],
  };

  /// Whether the document has changes the file does not have.
  bool get canSave => edited;

  /// The keywords chosen in the inspector, written on save (null: unchanged).
  String? newKeywords;

  bool _saving = false;

  /// Writes the changes into the file(s), then shows the document again from them.
  Future<void> save() async {
    final doc = document;
    if (doc == null || !edited || _saving) return;
    _saving = true;
    try {
      for (final path in _originalsOf()) {
        await _keepOriginal(path);
      }
      switch (doc) {
        case ImageDocument(:final images):
          for (final item in images) {
            if (item.writable && item.changed) await saveImage(item);
          }
          await _reload(doc, images: [for (final i in images) i.path]);
        case PdfDocument(:final pdf):
          await _savePdf(pdf);
          await _reload(doc, pdf: pdf.path, password: _passwordAfterSave(pdf));
      }
    } finally {
      _saving = false;
    }
  }

  String? _passwordAfterSave(PdfItem item) {
    final chosen = item.newSecurity;
    if (chosen == null) return item.password;
    return chosen.isOpen ? null : chosen.userPassword;
  }

  Future<void> _savePdf(PdfItem item) => writePdfTo(item.path);

  /// Writes the PDF with its changes to `out`: the annotations through poppler into a copy,
  /// then the pages, bookmarks, keywords and permissions through qpdf. `security` overrides the
  /// permissions chosen with Edit Permissions.
  Future<void> writePdfTo(String out, {PdfSecurity? security}) async {
    final item = pdf;
    if (item == null) return;
    final writer = loader.writer;
    final slash = out.lastIndexOf('/');
    final dir = slash < 0 ? '.' : out.substring(0, slash);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final annotated = '$dir/.${baseName(out)}.$stamp.annotated';
    await item.handle.saveTo(annotated);
    try {
      final chosen = security ?? item.newSecurity;
      final needsWriter =
          !item.pagesUnchanged ||
          item.pages.any((p) => p.bookmarked) ||
          _openedBookmarks ||
          newKeywords != null ||
          chosen != null;
      if (needsWriter && writer != null) {
        await writer.write(
          [
            for (final p in item.pages)
              if (p.source case final source?)
                SourcePage(
                  annotated,
                  source,
                  password: item.password,
                  quarterTurns: p.quarterTurns,
                  bookmarked: p.bookmarked,
                )
              else
                BlankPage(p.turnedSize, bookmarked: p.bookmarked),
          ],
          out,
          security: chosen,
          keywords: newKeywords,
        );
      } else {
        await File(annotated).rename(out);
      }
    } finally {
      final left = File(annotated);
      if (left.existsSync()) await left.delete();
    }
  }

  /// The PDF had bookmarks when opened (removing them all still needs the writer).
  bool _openedBookmarks = false;

  /// Where the files as opened are kept until the window closes: Preview's cache folder
  /// (`$XDG_CACHE_HOME/preview`), a temporary folder under `flutter test`.
  static Directory get _originalsRoot {
    final env = Platform.environment;
    if (env.containsKey('FLUTTER_TEST')) return Directory.systemTemp;
    final cache = env['XDG_CACHE_HOME'] ?? '${env['HOME'] ?? '/tmp'}/.cache';
    return Directory('$cache/preview')..createSync(recursive: true);
  }

  /// Drops the copies a Preview that did not close cleanly left behind (one Preview runs per
  /// session: those of a running window cannot be there yet).
  static void forgetOriginals() {
    try {
      for (final dir in _originalsRoot.listSync()) {
        if (dir is Directory && baseName(dir.path).startsWith('original-')) {
          dir.deleteSync(recursive: true);
        }
      }
    } on FileSystemException {
      // Nothing to clean.
    }
  }

  /// Copies `path` aside before it is first overwritten.
  Future<void> _keepOriginal(String path) async {
    if (_originals.containsKey(path)) return;
    final dir = await _originalsRoot.createTemp('original-');
    final copy = '${dir.path}/${baseName(path)}';
    await File(path).copy(copy);
    _originals[path] = copy;
  }

  /// Revert To › Last Opened: the file as it was opened, without the changes since.
  Future<void> revert() async {
    final doc = document;
    if (doc == null) return;
    for (final path in _originalsOf()) {
      final copy = _originals.remove(path);
      if (copy == null) continue;
      await File(copy).copy(path);
      await File(copy).parent.delete(recursive: true);
    }
    switch (doc) {
      case ImageDocument(:final images):
        await _reload(doc, images: [for (final i in images) i.path]);
      case PdfDocument(:final pdf):
        await _reload(doc, pdf: pdf.path, password: pdf.password);
    }
  }

  /// Opens the same files again, keeping the view: the current page, the zoom, the sidebar,
  /// the layout.
  Future<void> _reload(
    Document old, {
    List<String>? images,
    String? pdf,
    String? password,
  }) async {
    final keep = (current, zoomMode, _manualScale, sidebar, layout, inspector);
    if (images != null) {
      final items = <ImageItem>[];
      for (final path in {...images}) {
        try {
          items.addAll(await loader.images(path));
        } on OpenException catch (e) {
          failures.add(e);
        }
      }
      if (_disposed || items.isEmpty) return;
      _show(ImageDocument(items));
    } else if (pdf != null) {
      final PdfItem item;
      try {
        item = await loader.pdfFile(pdf, password: password);
      } on OpenException catch (e) {
        failures.add(e);
        _notify();
        return;
      }
      if (_disposed) {
        await item.handle.close();
        return;
      }
      _show(PdfDocument(item));
      _openedBookmarks = item.pages.any((p) => p.bookmarked);
    }
    current = keep.$1.clamp(0, math.max(0, count - 1));
    zoomMode = keep.$2;
    _manualScale = keep.$3;
    sidebar = keep.$4;
    layout = isPdf ? keep.$5 : PageLayout.continuous;
    inspector = keep.$6;
    newKeywords = null;
    _notify();
  }

  /// Renames the file to `name` in its folder. Throws [FileSystemException].
  Future<void> rename(String name) async {
    final doc = document;
    if (doc == null || name.contains('/')) return;
    final old = switch (doc) {
      ImageDocument() => image!.path,
      PdfDocument(:final pdf) => pdf.path,
    };
    final slash = old.lastIndexOf('/');
    final target = '${slash < 0 ? '' : old.substring(0, slash + 1)}$name';
    if (target == old) return;
    if (File(target).existsSync()) {
      throw FileSystemException('exists', target);
    }
    await File(old).rename(target);
    final copy = _originals.remove(old);
    if (copy != null) _originals[target] = copy;
    switch (doc) {
      case ImageDocument():
        image!.path = target;
      case PdfDocument(:final pdf):
        pdf.path = target;
    }
    _notify();
  }

  /// The keywords of the PDF (Inspector › Keywords), changed: written on save.
  List<String> get keywords {
    final text = newKeywords ?? pdf?.handle.info.keywords ?? '';
    return [
      for (final k in text.split(RegExp(r'[,;]')))
        if (k.trim().isNotEmpty) k.trim(),
    ];
  }

  void setKeywords(List<String> words) {
    final item = pdf;
    if (item == null) return;
    final before = newKeywords;
    final after = words.join(', ');
    _edit(() => newKeywords = after, () => newKeywords = before);
  }

  /// Edit Permissions: the encryption and permissions written on save.
  void setSecurity(PdfSecurity security) {
    final item = pdf;
    if (item == null) return;
    final before = item.newSecurity;
    _edit(() => item.newSecurity = security, () => item.newSecurity = before);
  }

  /// Saves (when there is something to save) and lets go of the document: the window closes.
  Future<void> saveAndDispose() async {
    try {
      if (edited) await save();
    } on Object {
      // Closing must not fail: the file stays as it was.
    }
    dispose();
  }

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

  /// Tells the views something changed outside the controller's own actions.
  void changed() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    for (final copy in _originals.values) {
      try {
        File(copy).parent.deleteSync(recursive: true);
      } on FileSystemException {
        // Already gone.
      }
    }
    _originals.clear();
    _disposed = true;
    _searchGeneration++;
    _stopZoom();
    document?.dispose();
    pages?.dispose();
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }
}

/// Whether the PDF asks to open with its table of contents (and has one).
bool opensWithOutline(PdfDocumentHandle handle) =>
    handle.pageMode == PdfPageMode.outlines && handle.outline.isNotEmpty;

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
