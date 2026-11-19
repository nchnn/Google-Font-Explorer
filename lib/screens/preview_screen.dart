import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../models/font_model.dart';
import '../services/font_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_pill_navigation.dart';
import '../widgets/stage_telemetry_card.dart';

/// Screen for testing typography settings with a fixed Live Preview header
/// and an independently scrollable customization controls area.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  TextStyle _getPreviewStyle({
    required FontModel font,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double height,
    required double letterSpacing,
  }) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
    if (FontService.isGoogleFontsSupported(font.name)) {
      try {
        return GoogleFonts.getFont(font.name, textStyle: base);
      } catch (_) {
        return base.copyWith(fontFamily: font.name);
      }
    }
    return base.copyWith(fontFamily: font.name);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final preview = PreviewState.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedFont = appState.selectedFont;

    final previewStyle = _getPreviewStyle(
      font: selectedFont,
      fontSize: preview.fontSize,
      fontWeight: preview.fontWeight,
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
              Card(
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
                          if (preview.controller.text.isNotEmpty)
                            InkWell(
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
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Clear text',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFECECEC),
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52, maxHeight: 130),
                        child: Center(
                          child: SingleChildScrollView(
                            child: TextField(
                              controller: preview.controller,
                              textAlign: preview.textAlign,
                              maxLines: null,
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
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                color: theme.shadowColor.withValues(alpha: isDark ? 0.35 : 0.08),
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
                StageTelemetryCard(
                  fontSize: preview.fontSize,
                  fontWeight: preview.fontWeight,
                  textAlign: preview.textAlign,
                  leading: preview.leading,
                  tracking: preview.tracking,
                  availableWeights: selectedFont.weights,
                  onFontSizeChanged: (value) => preview.fontSize = value,
                  onFontWeightChanged: (weight) => preview.fontWeight = weight,
                  onTextAlignChanged: (align) => preview.textAlign = align,
                  onLeadingChanged: (value) => preview.leading = value,
                  onTrackingChanged: (value) => preview.tracking = value,
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
