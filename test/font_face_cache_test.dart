import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/models/font_face.dart';
import 'package:type_studio/models/font_model.dart';
import 'package:type_studio/services/font_service.dart';

Uint8List _createVariableFontBytes({
  int minWeight = 100,
  int defaultWeight = 400,
  int maxWeight = 900,
}) {
  final bytes = Uint8List(72);
  final data = ByteData.sublistView(bytes);

  // Table directory header
  data.setUint32(0, 0x00010000); // TrueType signature
  data.setUint16(4, 1); // 1 table
  data.setUint16(6, 0); // searchRange
  data.setUint16(8, 0); // entrySelector
  data.setUint16(10, 0); // rangeShift

  // Table record: 'fvar'
  data.setUint32(12, 0x66766172); // 'fvar'
  data.setUint32(16, 0); // checkSum
  data.setUint32(20, 28); // offset to fvar table
  data.setUint32(24, 40); // length of fvar table

  // 'fvar' table start at offset 28
  const tableOffset = 28;
  data.setUint16(tableOffset + 0, 1); // majorVersion
  data.setUint16(tableOffset + 2, 0); // minorVersion
  data.setUint16(tableOffset + 4, 16); // axesArrayOffset from table start
  data.setUint16(tableOffset + 6, 2); // reserved
  data.setUint16(tableOffset + 8, 1); // axisCount: 1 axis
  data.setUint16(tableOffset + 10, 20); // axisSize: 20 bytes
  data.setUint16(tableOffset + 12, 0); // instanceCount
  data.setUint16(tableOffset + 14, 0); // instanceSize

  // Axis record at tableOffset + 16 = 44
  const axisOffset = tableOffset + 16;
  data.setUint32(axisOffset + 0, 0x77676874); // 'wght'
  data.setInt32(axisOffset + 4, minWeight * 65536); // Fixed 16.16 min
  data.setInt32(axisOffset + 8, defaultWeight * 65536); // Fixed 16.16 default
  data.setInt32(axisOffset + 12, maxWeight * 65536); // Fixed 16.16 max
  data.setUint16(axisOffset + 16, 0); // flags
  data.setUint16(axisOffset + 18, 256); // nameID

  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontFileAxes Binary Parser', () {
    test('returns none for empty or truncated bytes', () {
      expect(FontFileAxes.parse(Uint8List(0)), FontFileAxes.none);
      expect(FontFileAxes.parse(Uint8List(11)), FontFileAxes.none);
    });

    test('returns none for non-TrueType signatures (such as WOFF or text)', () {
      final woffBytes = Uint8List(32)..buffer.asByteData().setUint32(0, 0x774F4646);
      expect(FontFileAxes.parse(woffBytes), FontFileAxes.none);
    });

    test('returns none when table directory contains no fvar table', () {
      final bytes = Uint8List(32);
      bytes.buffer.asByteData().setUint32(0, 0x00010000);
      bytes.buffer.asByteData().setUint16(4, 1);
      // Table tag 'head' instead of 'fvar'
      bytes.buffer.asByteData().setUint32(12, 0x68656164);
      expect(FontFileAxes.parse(bytes), FontFileAxes.none);
    });

    test('parses variable font with wght axis and clamps values', () {
      final bytes = _createVariableFontBytes(
        minWeight: 100,
        defaultWeight: 400,
        maxWeight: 900,
      );

      final axes = FontFileAxes.parse(bytes);
      expect(axes.isVariable, isTrue);
      expect(axes.weight, isNotNull);
      expect(axes.weight!.tag, 'wght');
      expect(axes.weight!.min, 100.0);
      expect(axes.weight!.defaultValue, 400.0);
      expect(axes.weight!.max, 900.0);
      expect(axes.weight!.isUsable, isTrue);

      // Clamping checks
      expect(axes.weight!.clamp(50.0), 100.0);
      expect(axes.weight!.clamp(550.0), 550.0);
      expect(axes.weight!.clamp(1000.0), 900.0);
    });
  });

  group('FontService Face Key & Metadata Resolution', () {
    test('faceKey produces normalized, consistent keys', () {
      expect(FontService.faceKey('Roboto', 400), 'roboto_400_normal');
      expect(FontService.faceKey('Open Sans', 700), 'open_sans_700_normal');
      expect(FontService.faceKey('Merriweather', 400, italic: true), 'merriweather_400_italic');
    });

    test('resolvePreviewFace returns unloaded when cache is empty', () {
      final service = FontService.instance..clearCache();
      const font = FontModel(
        name: 'TestUnloaded',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w400, FontWeight.w700],
      );

      final preview = service.resolvePreviewFace(font, weight: 400);
      expect(preview.status, FontFaceStatus.unloaded);
      expect(preview.family, 'TestUnloaded');
    });

    test('resolvePreviewFace returns actual when exact face is cached', () {
      final service = FontService.instance..clearCache();
      const face = LoadedFontFace(
        family: 'TestExact',
        requestedWeight: 700,
        requestedItalic: false,
        registeredFamily: 'TestExact__ts_700',
        actualWeight: 700,
        actualItalic: false,
      );
      service.debugCacheFace(face);

      const font = FontModel(
        name: 'TestExact',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w400, FontWeight.w700],
      );

      final preview = service.resolvePreviewFace(font, weight: 700);
      expect(preview.status, FontFaceStatus.actual);
      expect(preview.family, 'TestExact__ts_700');
      expect(preview.simulatedWeight, isFalse);
    });

    test('resolvePreviewFace returns variable when variable base exists', () {
      final service = FontService.instance..clearCache();
      final varBytes = _createVariableFontBytes();
      final axes = FontFileAxes.parse(varBytes);

      final face = LoadedFontFace(
        family: 'TestVariable',
        requestedWeight: 400,
        requestedItalic: false,
        registeredFamily: 'TestVariable',
        actualWeight: 400,
        actualItalic: false,
        axes: axes,
      );
      service.debugCacheFace(face);

      const font = FontModel(
        name: 'TestVariable',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w100, FontWeight.w400, FontWeight.w700, FontWeight.w900],
      );

      // Request weight 700 without loading a 700 file
      final preview = service.resolvePreviewFace(font, weight: 700);
      expect(preview.status, FontFaceStatus.variable);
      expect(preview.usesVariableWeight, isTrue);
      expect(preview.renderWeight, 700);
    });

    test('resolvePreviewFace returns simulated when static font has exact variant uncached', () {
      final service = FontService.instance..clearCache();
      const face = LoadedFontFace(
        family: 'TestStaticSimulated',
        requestedWeight: 400,
        requestedItalic: false,
        registeredFamily: 'TestStaticSimulated',
        actualWeight: 400,
        actualItalic: false,
      );
      service.debugCacheFace(face);

      const font = FontModel(
        name: 'TestStaticSimulated',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w400, FontWeight.w700],
        variants: ['regular', '700'],
        files: {
          'regular': 'https://example.com/regular.ttf',
          '700': 'https://example.com/700.ttf',
        },
      );

      // Request 700 when only 400 is cached
      final preview = service.resolvePreviewFace(font, weight: 700);
      expect(preview.status, FontFaceStatus.simulated);
      expect(preview.simulatedWeight, isTrue);
      expect(preview.actualWeight, 400);
    });
  });

  group('FontService ensureFace Caching & Deduplication', () {
    late FontService service;

    setUp(() {
      service = FontService.instance..clearCache();
      service.debugHttpClient = null;
      service.debugGoogleFallbackEnabled = false;
    });

    tearDown(() {
      service.clearCache();
      service.debugHttpClient = null;
      service.debugGoogleFallbackEnabled = true;
    });

    test('ensureFace deduplicates in-flight downloads for identical requests', () async {
      var fetchCount = 0;
      final completer = Completer<http.Response>();

      service.debugHttpClient = MockClient((request) async {
        fetchCount++;
        return completer.future;
      });

      const font = FontModel(
        name: 'DedupeFont',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/dedupe.ttf'},
      );
      service.registerFonts([font]);

      // Fire two simultaneous requests for the same face
      final f1 = service.ensureFace(font, weight: 400);
      final f2 = service.ensureFace(font, weight: 400);

      // Yield to let the async download slot acquisition fire the HTTP call
      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, 1, reason: 'Only one network request should be initiated');

      completer.complete(
        http.Response.bytes(Uint8List.fromList([1, 2, 3, 4]), 200),
      );

      final r1 = await f1;
      final r2 = await f2;

      expect(r1.family, font.name);
      expect(r2.family, font.name);

      // Third request is an instant cache hit
      final r3 = await service.ensureFace(font, weight: 400);
      expect(fetchCount, 1, reason: 'Cache hit should not make network calls');
      expect(r3.registeredFamily, r1.registeredFamily);
    });

    test('failed face load cleans up pending map so subsequent call can retry', () async {
      var attempts = 0;
      service.debugHttpClient = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response('Server Error', 500);
        }
        return http.Response.bytes(Uint8List.fromList([1, 2, 3, 4]), 200);
      });

      const font = FontModel(
        name: 'RetryFont',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/retry.ttf'},
      );
      service.registerFonts([font]);

      // First attempt fails
      await expectLater(
        service.ensureFace(font, weight: 400),
        throwsA(isA<FontApiException>()),
      );

      // Second attempt retries and succeeds
      final face = await service.ensureFace(font, weight: 400);
      expect(attempts, 2);
      expect(face.family, font.name);
    });

    test('ensureFace reuses cached variable face without downloading separate weights', () async {
      var fetchCount = 0;
      final varBytes = _createVariableFontBytes();

      service.debugHttpClient = MockClient((request) async {
        fetchCount++;
        return http.Response.bytes(varBytes, 200);
      });

      const font = FontModel(
        name: 'VarFamily',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w100, FontWeight.w400, FontWeight.w700, FontWeight.w900],
        files: {
          'regular': 'https://example.com/var.ttf',
          '700': 'https://example.com/var_700.ttf',
        },
      );
      service.registerFonts([font]);

      // Load base face
      final baseFace = await service.ensureFace(font, weight: 400);
      expect(fetchCount, 1);
      expect(baseFace.axes.isVariable, isTrue);

      // Request 700: should reuse variable base and perform zero additional downloads
      final boldFace = await service.ensureFace(font, weight: 700);
      expect(fetchCount, 1, reason: 'Variable font face must be reused without new downloads');
      expect(boldFace.requestedWeight, 700);
      expect(boldFace.registeredFamily, baseFace.registeredFamily);
    });

    test('static font preview changes weight and italic without triggering downloads', () async {
      var fetchCount = 0;
      service.debugHttpClient = MockClient((request) async {
        fetchCount++;
        return http.Response.bytes(Uint8List.fromList([1, 2, 3, 4]), 200);
      });

      const font = FontModel(
        name: 'StaticOutfit',
        category: 'Sans Serif',
        description: 'Test',
        weights: [
          FontWeight.w100,
          FontWeight.w200,
          FontWeight.w300,
          FontWeight.w400,
          FontWeight.w500,
          FontWeight.w600,
          FontWeight.w700,
          FontWeight.w800,
          FontWeight.w900,
        ],
        files: {
          'regular': 'https://example.com/outfit_regular.ttf',
          '700': 'https://example.com/outfit_700.ttf',
          '900': 'https://example.com/outfit_900.ttf',
        },
      );
      service.registerFonts([font]);

      // 1. Initial selection loads only the default/base face (400)
      await service.ensureFontLoaded(font.name, font: font);
      expect(fetchCount, 1, reason: 'Initial load must download only the base face');

      // 2. Client-side preview for any weight/italic combination
      const testWeights = [
        FontWeight.w100,
        FontWeight.w300,
        FontWeight.w500,
        FontWeight.w700,
        FontWeight.w900,
      ];

      for (final w in testWeights) {
        for (final italic in [false, true]) {
          final style = service.previewStyle(
            font,
            const TextStyle(fontSize: 24),
            weight: w,
            italic: italic,
          );
          expect(style.fontWeight, w);
          expect(style.fontStyle, italic ? FontStyle.italic : FontStyle.normal);
        }
      }

      // 3. Verify zero network downloads occurred during customization
      expect(fetchCount, 1, reason: 'Changing weight and italic must trigger zero additional downloads');
    });
  });
}
