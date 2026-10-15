// Decoding the supported formats, EXIF, exporting, and the portal's protocol (mocked channel).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:preview/src/export/export.dart';
import 'package:preview/src/images/decode.dart';
import 'package:preview/src/images/formats.dart';
import 'package:preview/src/model/document.dart';
import 'package:preview/src/pdf/poppler.dart';
import 'package:preview/src/portal.dart';

import 'support/fake_pdf.dart';
import 'support/samples.dart';

void main() {
  final loader = DocumentLoader(pdf: FakePdfBackend({}));

  test('every supported image format decodes', () async {
    final dir = tempDir(addTearDown);
    final source = halves(8, 6);
    final animated = img.Image(width: 4, height: 4)
      ..addFrame(img.Image(width: 4, height: 4));
    final files = {
      'a.png': img.encodePng(source),
      'a.jpg': img.encodeJpg(source),
      'a.gif': img.encodeGif(source),
      'a.bmp': img.encodeBmp(source),
      'a.tif': img.encodeTiff(source),
      'a.svg': utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6">'
        '<rect width="4" height="6" fill="red"/></svg>',
      ),
      'anim.gif': img.encodeGif(animated),
    };
    for (final MapEntry(key: name, value: bytes) in files.entries) {
      final item = await loader.image(write(dir, name, bytes));
      addTearDown(item.dispose);
      expect(item.size.width, name == 'anim.gif' ? 4 : 8, reason: name);
      if (name == 'anim.gif') {
        expect((item.content as RasterContent).frames, 2);
      }
      if (name == 'a.svg') expect(item.content, isA<VectorContent>());
      if (name == 'a.tif') expect(item.colour.model, ColourModel.rgb);
    }
  });

  test('a HEIC file is recognised and refused', () async {
    final dir = tempDir(addTearDown);
    final path = write(dir, 'x.heic', [
      0,
      0,
      0,
      24,
      ...ascii.encode('ftypheic'),
      0,
      0,
    ]);
    await expectLater(
      loader.image(path),
      throwsA(
        isA<OpenException>().having(
          (e) => e.failure,
          'failure',
          OpenFailure.unsupported,
        ),
      ),
    );
  });

  test('a damaged PNG fails as damaged', () async {
    final dir = tempDir(addTearDown);
    final png = img.encodePng(halves(8, 8));
    final path = write(dir, 'x.png', png.sublist(0, 40));
    await expectLater(
      loader.image(path),
      throwsA(
        isA<OpenException>().having(
          (e) => e.failure,
          'failure',
          OpenFailure.damaged,
        ),
      ),
    );
  });

  test('EXIF fields of a JPEG', () async {
    final source = halves(4, 4)
      ..exif.imageIfd['Make'] = img.IfdValueAscii('Silica')
      ..exif.imageIfd['Model'] = img.IfdValueAscii('Test Camera');
    final fields = await readExif(img.encodeJpg(source), FileFormat.jpeg);
    expect(fields, contains(('Image Make', 'Silica')));
    expect(fields, contains(('Image Model', 'Test Camera')));
  });

  group('export', () {
    late ImageItem item;
    late Directory dir;
    setUp(() async {
      dir = tempDir(addTearDown);
      item = await loader.image(
        write(dir, 'photo.png', img.encodePng(halves(4, 2))),
      );
      addTearDown(item.dispose);
    });

    test('PNG keeps the pixels, with the rotation applied', () async {
      item.quarterTurns = 1;
      final path = '${dir.path}/out.png';
      await exportImage(item, const ExportOptions(ExportFormat.png), path);
      final back = img.decodePng(File(path).readAsBytesSync())!;
      expect((back.width, back.height), (2, 4));
      // Turned clockwise: the red left half is now on top.
      expect(back.getPixel(0, 0).r, 255);
      expect(back.getPixel(0, 3).b, 255);
    });

    test('JPEG with a quality, flipped', () async {
      item.flipHorizontal = true;
      final best = await encodeShown(item, Encoding.jpeg, quality: 1);
      final least = await encodeShown(item, Encoding.jpeg, quality: 0);
      final back = img.decodeJpg(best)!;
      expect((back.width, back.height), (4, 2));
      expect(back.getPixel(0, 0).b, greaterThan(200));
      expect(least.length, lessThanOrEqualTo(best.length));
      expect(
        const ExportOptions(ExportFormat.jpeg).fileName('/a/photo.png'),
        'photo.jpg',
      );
    });

    test('PDF of one page the size of the image', () async {
      final path = '${dir.path}/out.pdf';
      await exportImage(item, const ExportOptions(ExportFormat.pdf), path);
      final bytes = File(path).readAsBytesSync();
      expect(ascii.decode(bytes.sublist(0, 8)), '%PDF-1.4');
      if (!PopplerBackend.available) return;
      final doc = await const PopplerBackend().open(path);
      addTearDown(doc.close);
      expect(doc.pageCount, 1);
      expect(doc.pageSizes.single.width, 4);
      final page = await doc.render(0, 1);
      // BGRA: red at the left.
      expect(page.bgra.sublist(0, 4), [0, 0, 255, 255]);
    });
  });

  group('portal', () {
    const channel = MethodChannel('test/dbus', JSONMethodCodec());
    late List<MethodCall> calls;
    late Object? Function(MethodCall) answer;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return answer(call);
          });
    });

    Future<void> respond(String path, int code, Map<String, Object?> results) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              channel.name,
              channel.codec.encodeMethodCall(
                MethodCall('signal', {
                  'id': 3,
                  'path': path,
                  'member': 'Response',
                  'args': [code, results],
                }),
              ),
              (_) {},
            );

    test('Open: the chosen URIs become paths', () async {
      answer = (call) => call.method == 'subscribe'
          ? 3
          : ['/org/freedesktop/portal/desktop/request/1_2/preview1'];
      final dialogs = PortalFileDialogs(
        channel: channel,
        parentWindow: () async => 'wayland:h4ndle',
      );
      final result = dialogs.open(title: 'Open');
      await pumpEventQueue();
      final call = calls.last.arguments as Map;
      expect(call['method'], 'OpenFile');
      expect(call['signature'], 'ssa{sv}');
      // The dialog is attached to Preview's window.
      expect((call['args'] as List)[0], 'wayland:h4ndle');
      expect((call['args'] as List)[2], containsPair('multiple', true));
      await respond('/org/freedesktop/portal/desktop/request/1_2/preview1', 0, {
        'uris': ['file:///tmp/a%20b.png', 'https://example.com/x'],
      });
      expect(await result, ['/tmp/a b.png']);
    });

    test('Save: cancelled is null, a failure throws', () async {
      var n = 0;
      answer = (call) => call.method == 'subscribe' ? 3 : ['/req/${++n}'];
      final dialogs = PortalFileDialogs(channel: channel);
      final cancelled = dialogs.save(title: 'Export', name: 'a.png');
      await pumpEventQueue();
      expect((calls.last.arguments as Map)['method'], 'SaveFile');
      // No handle (an embedder without exportHandle): no parent window.
      expect(((calls.last.arguments as Map)['args'] as List)[0], '');
      expect(
        ((calls.last.arguments as Map)['args'] as List)[2],
        containsPair('current_name', 'a.png'),
      );
      await respond('/req/1', 1, {});
      expect(await cancelled, isNull);
      final failed = dialogs.save(title: 'Export', name: 'a.png');
      final check = expectLater(failed, throwsA(isA<FileDialogUnavailable>()));
      await pumpEventQueue();
      await respond('/req/2', 2, {});
      await check;
    });

    test('the real channel is never used under flutter test', () async {
      await expectLater(
        PortalFileDialogs().open(title: 'Open'),
        throwsA(isA<FileDialogUnavailable>()),
      );
    });
  });

  test('the fake backend lays text out on its grid', () {
    expect(fakeLayout(['ab']).rects.length, 2);
  });
}
