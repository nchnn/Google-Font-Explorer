import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// A single OpenType variation axis read from a font file.
@immutable
class FontAxis {
  const FontAxis({
    required this.tag,
    required this.min,
    required this.defaultValue,
    required this.max,
  });

  /// Four-character axis tag, for example `wght` or `ital`.
  final String tag;

  final double min;
  final double defaultValue;
  final double max;

  /// Whether the axis can actually interpolate between two values.
  bool get isUsable => max > min;

  /// Clamps [value] to the range advertised by the font file.
  double clamp(double value) => value.clamp(min, max);
}

/// Variation axes discovered inside a downloaded font file.
///
/// Google Fonts catalogue metadata does not say whether a file is variable, so
/// the service reads the real `fvar` table from the bytes it downloads.
@immutable
class FontFileAxes {
  const FontFileAxes({this.weight, this.italic});

  static const FontFileAxes none = FontFileAxes();

  /// The `wght` axis when the file supports variable weight.
  final FontAxis? weight;

  /// The `ital` axis when the file supports variable italic.
  final FontAxis? italic;

  bool get isVariable => weight != null || italic != null;

  /// Parses a TrueType or OpenType font and returns its `wght` and `ital` axes.
  ///
  /// Returns [none] for static fonts, WOFF containers, malformed data, and any
  /// file that does not include a usable `fvar` table. Parsing never throws.
  static FontFileAxes parse(Uint8List bytes) {
    if (bytes.length < 12) {
      return none;
    }

    try {
      final data = ByteData.sublistView(bytes);
      final signature = data.getUint32(0);

      int directoryOffset;
      if (signature == 0x74746366) {
        // 'ttcf' font collection. Use the first font in the collection.
        if (bytes.length < 16) {
          return none;
        }
        directoryOffset = data.getUint32(12);
      } else if (signature == 0x00010000 ||
          signature == 0x4F54544F ||
          signature == 0x74727565) {
        directoryOffset = 0;
      } else {
        // WOFF, WOFF2, and unknown containers.
        return none;
      }

      if (directoryOffset + 12 > bytes.length) {
        return none;
      }

      final numTables = data.getUint16(directoryOffset + 4);
      if (numTables <= 0 || numTables > 512) {
        return none;
      }

      final recordsStart = directoryOffset + 12;
      for (var i = 0; i < numTables; i++) {
        final record = recordsStart + (i * 16);
        if (record + 16 > bytes.length) {
          return none;
        }
        if (data.getUint32(record) != 0x66766172) {
          continue;
        }
        // 'fvar'
        final offset = data.getUint32(record + 8);
        final length = data.getUint32(record + 12);
        if (offset + length > bytes.length || length < 16) {
          return none;
        }
        return _parseFvar(data, offset, length);
      }
    } catch (_) {
      // Truncated or malformed font data: treat it as a static file.
    }

    return none;
  }

  static FontFileAxes _parseFvar(ByteData data, int offset, int length) {
    final axesArrayOffset = data.getUint16(offset + 4);
    final axisCount = data.getUint16(offset + 8);
    final axisSize = data.getUint16(offset + 10);

    if (axisCount <= 0 || axisCount > 64 || axisSize < 20) {
      return none;
    }

    final axesStart = offset + axesArrayOffset;
    final axesEnd = axesStart + (axisCount * axisSize);
    if (axesStart < offset || axesEnd > offset + length) {
      return none;
    }

    FontAxis? weight;
    FontAxis? italic;
    for (var i = 0; i < axisCount; i++) {
      final axisOffset = axesStart + (i * axisSize);
      final tag = _tagAt(data, axisOffset);
      final axis = FontAxis(
        tag: tag,
        min: _fixed16Dot16(data, axisOffset + 4),
        defaultValue: _fixed16Dot16(data, axisOffset + 8),
        max: _fixed16Dot16(data, axisOffset + 12),
      );
      if (tag == 'wght' && axis.isUsable) {
        weight = axis;
      } else if (tag == 'ital' && axis.isUsable) {
        italic = axis;
      }
    }

    return FontFileAxes(weight: weight, italic: italic);
  }

  static String _tagAt(ByteData data, int offset) {
    return String.fromCharCodes(<int>[
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    ]);
  }

  static double _fixed16Dot16(ByteData data, int offset) {
    return data.getInt32(offset) / 65536.0;
  }
}

/// A genuine font face that has been registered with the Flutter engine or the
/// `google_fonts` package.
@immutable
class LoadedFontFace {
  const LoadedFontFace({
    required this.family,
    required this.requestedWeight,
    required this.requestedItalic,
    required this.registeredFamily,
    required this.actualWeight,
    required this.actualItalic,
    this.fallbacks = const [],
    this.axes = FontFileAxes.none,
    this.fromGoogleFonts = false,
    this.fileUrl,
  });

  /// Catalogue family name the face belongs to.
  final String family;

  /// Weight that was requested when this face was loaded.
  final int requestedWeight;

  /// Whether italic was requested when this face was loaded.
  final bool requestedItalic;

  /// Family name passed to `FontLoader` or returned by `google_fonts`.
  final String registeredFamily;

  /// Fallback families to try when [registeredFamily] is unavailable.
  final List<String> fallbacks;

  /// Genuine weight of the registered file, not the requested weight.
  final int actualWeight;

  /// Genuine italic state of the registered file.
  final bool actualItalic;

  /// Variation axes detected in the registered file.
  final FontFileAxes axes;

  /// Whether this face came from the `google_fonts` fallback path.
  final bool fromGoogleFonts;

  /// Download URL for catalogue faces, when known.
  final String? fileUrl;

  FontAxis? get weightAxis => axes.weight;
  FontAxis? get italicAxis => axes.italic;

  String get normalizedFamily => family.trim().toLowerCase();

  /// Returns a copy of this face labelled with a different requested style.
  ///
  /// The registered family and its bytes are shared, which is what allows one
  /// variable file to serve many requested weights without new downloads.
  LoadedFontFace forRequest({required int weight, required bool italic}) {
    return LoadedFontFace(
      family: family,
      requestedWeight: weight,
      requestedItalic: italic,
      registeredFamily: registeredFamily,
      fallbacks: fallbacks,
      actualWeight: actualWeight,
      actualItalic: actualItalic,
      axes: axes,
      fromGoogleFonts: fromGoogleFonts,
      fileUrl: fileUrl,
    );
  }
}

/// How closely the currently available face matches the requested style.
enum FontFaceStatus {
  /// The exact genuine face is loaded and used.
  actual,

  /// A variable face is adjusted through its `wght` and/or `ital` axis.
  variable,

  /// The requested variant is known but is not loaded yet, so the preview is
  /// synthesised from another loaded face.
  simulated,

  /// No exact variant exists, so the nearest genuine face is used.
  approximate,

  /// Nothing is loaded for this family yet.
  unloaded,
}

/// Synchronous preview decision for one family, weight, and italic combination.
@immutable
class FontFacePreview {
  const FontFacePreview({
    required this.status,
    required this.family,
    required this.renderWeight,
    required this.renderItalic,
    this.fallbacks = const [],
    this.weightAxis,
    this.italicAxis,
    this.actualWeight,
    this.actualItalic = false,
    this.simulatedWeight = false,
    this.simulatedItalic = false,
    this.face,
  });

  factory FontFacePreview.unloaded({required String family}) {
    return FontFacePreview(
      status: FontFaceStatus.unloaded,
      family: family,
      renderWeight: 400,
      renderItalic: false,
    );
  }

  final FontFaceStatus status;

  /// Family name to pass to [TextStyle].
  final String family;

  final List<String> fallbacks;

  /// Weight the text style should request after axis clamping.
  final int renderWeight;

  final bool renderItalic;

  final FontAxis? weightAxis;
  final FontAxis? italicAxis;

  final int? actualWeight;
  final bool actualItalic;

  /// Whether the rendered weight is synthetic rather than from the font file.
  final bool simulatedWeight;

  /// Whether the rendered italic is synthetic rather than from the font file.
  final bool simulatedItalic;

  /// The genuine face backing this preview, when one exists.
  final LoadedFontFace? face;

  bool get hasFace => face != null;
  bool get usesVariableWeight => weightAxis != null;
  bool get usesVariableItalic => renderItalic && italicAxis != null;
}
