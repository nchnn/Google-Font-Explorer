import 'package:material_ui/material_ui.dart';

import '../services/font_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/font_weight_utils.dart';
import '../widgets/floating_pill_navigation.dart';
import '../widgets/control_card.dart';
import '../widgets/font_text.dart';

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

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final preview = PreviewState.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedFont = appState.selectedFont;

    final previewText = preview.controller.text.trim().isEmpty
        ? 'The quick brown fox jumps over the lazy dog.'
        : preview.controller.text;

    final isBuiltIn = FontService.isGoogleFontsSupported(selectedFont.name);

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
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: FontText(
                                key: ValueKey(
                                  '${selectedFont.name}-${preview.fontSize.toInt()}-${preview.fontWeight}-${preview.textAlign}-$previewText',
                                ),
                                fontFamily: selectedFont.name,
                                text: previewText,
                                textAlign: preview.textAlign,
                                style: TextStyle(
                                  fontSize: preview.fontSize,
                                  fontWeight: preview.fontWeight,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.25,
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
                // Custom Text Input Card
                ControlCard(
                  title: 'YOUR TEXT',
                  trailing: '${previewText.length} characters',
                  child: TextField(
                    controller: preview.controller,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Type something to preview...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Font Size Slider
                ControlCard(
                  title: 'Font size',
                  trailing: '${preview.fontSize.toInt()} px',
                  child: Slider(
                    value: preview.fontSize,
                    min: 12,
                    max: 64,
                    divisions: 52,
                    onChanged: (value) => preview.fontSize = value,
                  ),
                ),
                const SizedBox(height: 12),

                // Font Weight Selection Chips
                ControlCard(
                  title: 'Font weight',
                  trailing: formatWeightName(preview.fontWeight),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (selectedFont.weights.isEmpty
                            ? const [FontWeight.w400]
                            : selectedFont.weights)
                        .map((weight) {
                      final label = formatWeightChip(weight);
                      final isSelected = preview.fontWeight == weight;
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => preview.fontWeight = weight,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Text Alignment Controls
                ControlCard(
                  title: 'Text alignment',
                  child: SegmentedButton<TextAlign>(
                    segments: const [
                      ButtonSegment(
                        value: TextAlign.left,
                        icon: Icon(Icons.format_align_left),
                        label: Text('Left'),
                      ),
                      ButtonSegment(
                        value: TextAlign.center,
                        icon: Icon(Icons.format_align_center),
                        label: Text('Center'),
                      ),
                      ButtonSegment(
                        value: TextAlign.right,
                        icon: Icon(Icons.format_align_right),
                        label: Text('Right'),
                      ),
                    ],
                    selected: {preview.textAlign},
                    onSelectionChanged: (values) => preview.textAlign = values.first,
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
