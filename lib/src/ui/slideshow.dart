// The slideshow (PREVIEW-01 › Slideshow, View › Slideshow ⇧⌘F): the pages or images on black,
// fitted to the height (a spread in the two-page layout). Moving the pointer shows a control HUD
// (287 × 74, 32 pt from the bottom, radius 8) with previous, play/pause, next and close buttons
// of 61 × 52. Playing, it turns a page about every 5 s with a dissolve; previous and next cut at
// once. Esc ends it.
//
// The reference fills the display with a window of its own; Silica's embedder cannot ask for a
// full-screen window yet, so the slideshow covers Preview's window.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../model/viewer.dart';
import '../style.dart';
import 'image_view.dart';
import 'symbol.dart';

class Slideshow extends StatefulWidget {
  const Slideshow({super.key, required this.controller, required this.onEnd});
  final ViewerController controller;
  final VoidCallback onEnd;

  @override
  State<Slideshow> createState() => SlideshowState();
}

class SlideshowState extends State<Slideshow> {
  final FocusNode _focus = FocusNode(debugLabel: 'slideshow');
  Timer? _advance;
  Timer? _hide;
  bool playing = true;
  bool hudShown = false;

  /// Turning by itself dissolves; previous and next cut.
  bool _dissolve = false;

  ViewerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _schedule();
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _advance?.cancel();
    _hide?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _schedule() {
    _advance?.cancel();
    if (!playing) return;
    _advance = Timer(PreviewMetrics.slideshowInterval, () {
      if (!mounted) return;
      if (!c.canGoForward) {
        setState(() => playing = false);
        return;
      }
      _dissolve = true;
      c.next();
      _schedule();
    });
  }

  void previous() {
    _dissolve = false;
    c.previous();
    _schedule();
  }

  void next() {
    _dissolve = false;
    c.next();
    _schedule();
  }

  void togglePlay() {
    setState(() => playing = !playing);
    _schedule();
  }

  void _showHud() {
    _hide?.cancel();
    if (!hudShown) setState(() => hudShown = true);
    // Provisional: how long the HUD stays without moving the pointer was not measured.
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => hudShown = false);
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onEnd();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      previous();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown) {
      next();
    } else if (key == LogicalKeyboardKey.space) {
      togglePlay();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _slide(Size view, double dpr) {
    final pdf = c.pdf;
    if (pdf != null) {
      final spread = c.spreadPages(c.current);
      var w = 0.0;
      var h = 0.0;
      for (final p in spread) {
        final s = pdf.pageSize(p);
        w += s.width;
        h = math.max(h, s.height);
      }
      final scale = math.min(view.width / w, view.height / h);
      return Row(
        key: ValueKey('slide ${spread.first}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in spread)
            _page(p, pdf.pageSize(p) * scale, scale * dpr),
        ],
      );
    }
    final item = c.image;
    if (item == null) return const SizedBox.shrink();
    final turned = item.turnedSize;
    final scale = math.min(
      view.width / math.max(1, turned.width),
      view.height / math.max(1, turned.height),
    );
    return ShownImage(
      key: ValueKey('slide ${c.current}'),
      item: item,
      scale: scale,
    );
  }

  Widget _page(int page, Size size, double pixels) {
    final source = c.sourceOf(page);
    final image = source == null ? null : c.pages?.image(source, pixels);
    return Container(
      width: size.width,
      height: size.height,
      color: const Color(0xFFFFFFFF),
      child: image == null
          ? null
          : RotatedBox(
              quarterTurns: c.pdf!.turnsOf(page),
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final pages = c.pages;
    Widget content() => LayoutBuilder(
      builder: (context, box) {
        final slide = _slide(box.biggest, dpr);
        return AnimatedSwitcher(
          duration: _dissolve
              ? PreviewMetrics.slideshowDissolve
              : Duration.zero,
          child: Center(key: slide.key, child: slide),
        );
      },
    );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: MouseRegion(
        onHover: (_) => _showHud(),
        child: ColoredBox(
          key: const ValueKey('slideshow'),
          color: const Color(0xFF000000),
          child: Stack(
            children: [
              Positioned.fill(
                child: pages == null
                    ? content()
                    : ListenableBuilder(
                        listenable: pages,
                        builder: (_, _) => content(),
                      ),
              ),
              if (hudShown)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: PreviewMetrics.slideshowHudBottom,
                  child: Center(child: _hud()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    const fg = Color(0xFFE6E6E6);
    Widget button(String key, String icon, String fallback, VoidCallback? on) =>
        GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: on,
          child: SizedBox.fromSize(
            size: PreviewMetrics.slideshowButton,
            child: Center(
              child: PreviewSymbol(
                icon,
                size: 22,
                color: on == null ? const Color(0x66E6E6E6) : fg,
                fallback: fallback,
              ),
            ),
          ),
        );
    return Container(
      key: const ValueKey('slideshow hud'),
      width: PreviewMetrics.slideshowHud.width,
      height: PreviewMetrics.slideshowHud.height,
      decoration: BoxDecoration(
        color: const Color(0xE6323232),
        borderRadius: BorderRadius.circular(PreviewMetrics.slideshowHudRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          button(
            'slideshow previous',
            'backward',
            '⏮',
            c.canGoBack ? previous : null,
          ),
          button(
            'slideshow play',
            playing ? 'pause' : 'play',
            playing ? '⏸' : '▶',
            togglePlay,
          ),
          button(
            'slideshow next',
            'forward',
            '⏭',
            c.canGoForward ? next : null,
          ),
          button('slideshow close', 'xmark', '✕', widget.onEnd),
        ],
      ),
    );
  }
}
