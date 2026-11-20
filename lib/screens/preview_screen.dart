import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/font_face.dart';
import '../models/font_model.dart';
import '../services/font_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_pill_navigation.dart';
import '../widgets/typography_controls_card.dart';

/// Screen for testing typography settings with a fixed Live Preview header
/// and an independently scrollable customization controls area.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _settleTimer;
  String? _scheduledFamily;
  FontWeight? _scheduledWeight;
  bool? _scheduledItalic;

  /// Family already passed to [FontService.ensureFontLoaded] by this screen.
  ///
  /// `selectFont` also preloads the family. This guard stops the screen from
  /// queueing a second load for the same family on every dependency change.
  String? _requestedFont;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadSelectedFont();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Loads the selected family once so the preview swaps from the fallback.
  ///
  /// Only families with a file URL go through this path. Families without one
  /// are resolved by `google_fonts` in [FontService.previewStyle].
  void _preloadSelectedFont() {
    final font = AppState.of(context).selectedFont;
    if (_requestedFont == font.name) return;
    _requestedFont = font.name;
    if (font.files.isEmpty) return;

    FontService.instance
        .ensureFontLoaded(font.name, font: font)
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {});
  }

  void _scheduleVariantLoadIfNeeded(
    FontModel font,
    FontWeight weight,
    bool isItalic,
  ) {
    final previewFace = FontService.instance.resolvePreviewFace(
      font,
      weight: weight.value,
      italic: isItalic,
    );
    if (previewFace.status != FontFaceStatus.simulated &&
        previewFace.status != FontFaceStatus.approximate) {
      _settleTimer?.cancel();
      _settleTimer = null;
      _scheduledFamily = font.name;
      _scheduledWeight = weight;
      _scheduledItalic = isItalic;
      return;
    }

    if (_scheduledFamily == font.name &&
        _scheduledWeight == weight &&
        _scheduledItalic == isItalic) {
      return;
    }

    _scheduledFamily = font.name;
    _scheduledWeight = weight;
    _scheduledItalic = isItalic;

    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      FontService.instance
          .ensureFace(font, weight: weight.value, italic: isItalic)
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((_) {});
    });
  }

  TextStyle _getPreviewStyle({
    required FontModel font,
    required double fontSize,
    required FontWeight fontWeight,
    required bool isItalic,
    required Color color,
    required double height,
    required double letterSpacing,
  }) {
    return FontService.instance.previewStyle(
      font,
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      ),
      weight: fontWeight,
      italic: isItalic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final preview = PreviewState.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedFont = appState.selectedFont;

    _scheduleVariantLoadIfNeeded(
      selectedFont,
      preview.fontWeight,
      preview.isItalic,
    );

    final previewStyle = _getPreviewStyle(
      font: selectedFont,
      fontSize: preview.fontSize,
      fontWeight: preview.fontWeight,
      isItalic: preview.isItalic,
      color: theme.colorScheme.onSurface,
      height: preview.leading,
      letterSpacing: preview.tracking * preview.fontSize,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // =====================================================================
        // 1. FIXED LIVE PREVIEW SECTION (Always visible at top, does not scroll)
        // =====================================================================
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Typography tester',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => appState.selectedTab = 1,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Change font'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RepaintBoundary(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'LIVE PREVIEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: preview.controller,
                              builder: (context, value, _) {
                                if (value.text.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return InkWell(
                                  onTap: () => preview.controller.clear(),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.close_rounded,
                                          size: 13,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Clear text',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            Text(
                              selectedFont.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSecondarySurface
                                    : const Color(0xFFECECEC),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                selectedFont.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 130,
                          child: TextField(
                            controller: preview.controller,
                            textAlign: preview.textAlign,
                            textAlignVertical: TextAlignVertical.top,
                            maxLines: null,
                            minLines: null,
                            expands: true,
                            cursorColor: theme.colorScheme.primary,
                            style: previewStyle,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Tap to type custom preview text...',
                              hintStyle: previewStyle.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // =====================================================================
        // VISUAL SEPARATION DIVIDER (Between fixed preview & scrollable controls)
        // =====================================================================
        Container(
          height: 1,
          decoration: BoxDecoration(
            color: theme.dividerColor,
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(
                  alpha: isDark ? 0.35 : 0.08,
                ),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),

        // =====================================================================
        // 2. SCROLLABLE CONTROLS SECTION (Independently scrollable with scrollbar)
        // =====================================================================
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 6,
            radius: const Radius.circular(3),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                kFloatingPillNavigationClearance + 28,
              ),
              children: [
                // Typography Controls Panel
                RepaintBoundary(
                  child: TypographyControlsCard(
                    fontSize: preview.fontSize,
                    fontWeight: preview.fontWeight,
                    textAlign: preview.textAlign,
                    isItalic: preview.isItalic,
                    leading: preview.leading,
                    tracking: preview.tracking,
                    availableWeights: selectedFont.weights,
                    onFontSizeChanged: (value) => preview.fontSize = value,
                    onFontWeightChanged: (weight) =>
                        preview.fontWeight = weight,
                    onTextAlignChanged: (align) => preview.textAlign = align,
                    onItalicChanged: (italic) => preview.isItalic = italic,
                    onLeadingChanged: (value) => preview.leading = value,
                    onTrackingChanged: (value) => preview.tracking = value,
                  ),
                ),
                const SizedBox(height: 16),

                // Reset Settings Button
                OutlinedButton.icon(
                  onPressed: preview.reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset preview settings'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                // Informational Note
                Text(
                  'Fonts are dynamically fetched when requested and cached in memory to eliminate duplicate downloads. '
                  'Newly discovered Google Fonts catalogue families not bundled in the google_fonts package are dynamically '
                  "registered at runtime via Flutter's FontLoader.",
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
