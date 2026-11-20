# font_face.dart

**Purpose:** Models font variation axes and OpenType font file metadata parsed from binary font bytes.

**How it works:** Reads the fvar table of downloaded TrueType and OpenType files to extract weight and italic axes for variable font support.

**Key components:** `FontAxis`, `FontFileAxes`, `LoadedFontFace`, `FontFaceStatus`, `FontFacePreview`
