import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../utils/font_weight_utils.dart';

/// A theme-aware typography customization control panel.
///
/// Provides intuitive controls for font size, weight, text alignment,
/// line spacing (leading), and letter spacing (tracking/kerning) with
/// real-time feedback and clear, accessible terminology.
class StageTelemetryCard extends StatelessWidget {
  const StageTelemetryCard({
    super.key,
    required this.fontSize,
    required this.fontWeight,
    required this.textAlign,
    required this.leading,
    required this.tracking,
    required this.availableWeights,
    required this.onFontSizeChanged,
    required this.onFontWeightChanged,
    required this.onTextAlignChanged,
    required this.onLeadingChanged,
    required this.onTrackingChanged,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final double leading;
  final double tracking;
  final List<FontWeight> availableWeights;

  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<FontWeight> onFontWeightChanged;
  final ValueChanged<TextAlign> onTextAlignChanged;
  final ValueChanged<double> onLeadingChanged;
  final ValueChanged<double> onTrackingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Theme-driven monochromatic color tokens
    final bgCard = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderCard = isDark ? AppColors.darkBorder : AppColors.border;
    final bgTray =
        isDark ? AppColors.darkSecondarySurface : const Color(0xFFF3F3F3);
    final borderTray =
        isDark ? const Color(0xFF343434) : const Color(0xFFE5E5E5);
    final pillActive = isDark ? const Color(0xFF383838) : Colors.white;
    final pillActiveBorder =
        isDark ? const Color(0xFF4E4E4E) : const Color(0xFFD4D4D4);
    final labelColor = theme.colorScheme.onSurface;
    final mutedText = theme.colorScheme.onSurfaceVariant;
    final sliderThumb =
        isDark ? AppColors.darkPrimaryAccent : AppColors.charcoal;
    final sliderActive =
        isDark ? AppColors.darkPrimaryAccent : AppColors.charcoal;
    final sliderInactive =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);
    final readoutBg =
        isDark ? AppColors.darkSecondarySurface : const Color(0xFFF0F0F0);
    final readoutBorder =
        isDark ? AppColors.darkBorder : const Color(0xFFDFDFDF);

    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCard),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -------------------------------------------------------------------
          // HEADER: Typography controls + Real-time Preview Badge
          // -------------------------------------------------------------------
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Typography controls',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF292929)
                      : const Color(0xFFECECEC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3E3E3E)
                        : const Color(0xFFDDDDDD),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : AppColors.charcoal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'REAL-TIME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkPrimaryText
                            : AppColors.primaryText,
                        fontFamily: 'monospace',
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // SECTION 1: Font size (Scale)
          // -------------------------------------------------------------------
          _buildScaleSection(
            labelColor: labelColor,
            mutedText: mutedText,
            readoutBg: readoutBg,
            readoutBorder: readoutBorder,
            sliderThumb: sliderThumb,
            sliderActive: sliderActive,
            sliderInactive: sliderInactive,
          ),
          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // SECTION 2: Font weight (Weight Vector)
          // -------------------------------------------------------------------
          _buildFontWeightSection(
            labelColor: labelColor,
            mutedText: mutedText,
            bgTray: bgTray,
            borderTray: borderTray,
            pillActive: pillActive,
            pillActiveBorder: pillActiveBorder,
            isDark: isDark,
          ),
          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // SECTION 3: Text alignment
          // -------------------------------------------------------------------
          _buildAlignmentSection(
            labelColor: labelColor,
            mutedText: mutedText,
            bgTray: bgTray,
            borderTray: borderTray,
            pillActive: pillActive,
            pillActiveBorder: pillActiveBorder,
            isDark: isDark,
          ),
          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // SECTION 4: Line spacing (Leading)
          // -------------------------------------------------------------------
          _buildLeadingSection(
            labelColor: labelColor,
            mutedText: mutedText,
            sliderThumb: sliderThumb,
            sliderActive: sliderActive,
            sliderInactive: sliderInactive,
          ),
          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // SECTION 5: Letter spacing (Tracking / Kerning Offset)
          // -------------------------------------------------------------------
          _buildTrackingSection(
            labelColor: labelColor,
            mutedText: mutedText,
            sliderThumb: sliderThumb,
            sliderActive: sliderActive,
            sliderInactive: sliderInactive,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION BUILDERS
  // ===========================================================================

  Widget _buildScaleSection({
    required Color labelColor,
    required Color mutedText,
    required Color readoutBg,
    required Color readoutBorder,
    required Color sliderThumb,
    required Color sliderActive,
    required Color sliderInactive,
  }) {
    final currentScale = fontSize.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label & Numeric readout box
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Font size',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                Text(
                  'Scale (pt / px)',
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedText,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: readoutBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: readoutBorder),
              ),
              child: Text.rich(
                TextSpan(
                  text: '$currentScale ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    fontFamily: 'monospace',
                  ),
                  children: [
                    TextSpan(
                      text: 'px',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: mutedText,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Continuous Slider with checkpoints (divisions: 60)
        _buildCustomSlider(
          value: fontSize.clamp(12.0, 72.0),
          min: 12.0,
          max: 72.0,
          divisions: 60,
          thumbColor: sliderThumb,
          activeColor: sliderActive,
          inactiveColor: sliderInactive,
          onChanged: onFontSizeChanged,
        ),
      ],
    );
  }

  Widget _buildFontWeightSection({
    required Color labelColor,
    required Color mutedText,
    required Color bgTray,
    required Color borderTray,
    required Color pillActive,
    required Color pillActiveBorder,
    required bool isDark,
  }) {
    final weightName = formatWeightName(fontWeight);
    final weightValue = fontWeight.value;
    final weights = availableWeights.isEmpty
        ? const [FontWeight.w400]
        : availableWeights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label & Vector Readout
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Font weight',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                Text(
                  'Weight Vector',
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedText,
                  ),
                ),
              ],
            ),
            Text(
              '$weightName ($weightValue)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Segmented Buttons based on available API weights
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bgTray,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderTray),
          ),
          child: weights.length <= 6
              ? Row(
                  children: weights.map((weight) {
                    final isSelected = fontWeight == weight;
                    return Expanded(
                      child: _buildWeightPill(
                        weight: weight,
                        isSelected: isSelected,
                        pillActive: pillActive,
                        pillActiveBorder: pillActiveBorder,
                        isDark: isDark,
                        labelColor: labelColor,
                        mutedText: mutedText,
                      ),
                    );
                  }).toList(),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: weights.map((weight) {
                      final isSelected = fontWeight == weight;
                      return SizedBox(
                        width: 54,
                        child: _buildWeightPill(
                          weight: weight,
                          isSelected: isSelected,
                          pillActive: pillActive,
                          pillActiveBorder: pillActiveBorder,
                          isDark: isDark,
                          labelColor: labelColor,
                          mutedText: mutedText,
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildWeightPill({
    required FontWeight weight,
    required bool isSelected,
    required Color pillActive,
    required Color pillActiveBorder,
    required bool isDark,
    required Color labelColor,
    required Color mutedText,
  }) {
    return GestureDetector(
      onTap: () => onFontWeightChanged(weight),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? pillActive : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: isSelected ? Border.all(color: pillActiveBorder) : null,
          boxShadow: isSelected && !isDark
              ? const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          '${weight.value}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? labelColor : mutedText,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildAlignmentSection({
    required Color labelColor,
    required Color mutedText,
    required Color bgTray,
    required Color borderTray,
    required Color pillActive,
    required Color pillActiveBorder,
    required bool isDark,
  }) {
    final alignmentOptions = [
      (TextAlign.left, Icons.format_align_left_rounded, 'Align left'),
      (TextAlign.center, Icons.format_align_center_rounded, 'Align center'),
      (TextAlign.right, Icons.format_align_right_rounded, 'Align right'),
      (TextAlign.justify, Icons.format_align_justify_rounded, 'Justify'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Text alignment',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            Text(
              'Alignment',
              style: TextStyle(
                fontSize: 11,
                color: mutedText,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bgTray,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderTray),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: alignmentOptions.map((option) {
              final (alignValue, iconData, tooltip) = option;
              final isSelected = textAlign == alignValue;

              return Tooltip(
                message: tooltip,
                child: GestureDetector(
                  onTap: () => onTextAlignChanged(alignValue),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? pillActive : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: isSelected
                          ? Border.all(color: pillActiveBorder)
                          : null,
                      boxShadow: isSelected && !isDark
                          ? const [
                              BoxShadow(
                                color: Color(0x18000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      iconData,
                      size: 16,
                      color: isSelected ? labelColor : mutedText,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadingSection({
    required Color labelColor,
    required Color mutedText,
    required Color sliderThumb,
    required Color sliderActive,
    required Color sliderInactive,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label & Readout
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Line spacing',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                Text(
                  'Line height / Leading',
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedText,
                  ),
                ),
              ],
            ),
            Text(
              leading.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: labelColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Slider (1.0 to 2.0) with checkpoints
        _buildCustomSlider(
          value: leading.clamp(1.0, 2.0),
          min: 1.0,
          max: 2.0,
          divisions: 20,
          thumbColor: sliderThumb,
          activeColor: sliderActive,
          inactiveColor: sliderInactive,
          onChanged: onLeadingChanged,
        ),
        const SizedBox(height: 2),

        // Range Labels: Tight 1.0 vs Loose 2.0
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tight (1.0)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: mutedText,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'Loose (2.0)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: mutedText,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrackingSection({
    required Color labelColor,
    required Color mutedText,
    required Color sliderThumb,
    required Color sliderActive,
    required Color sliderInactive,
  }) {
    final prefix = tracking >= 0 ? '+' : '';
    final readoutText = '$prefix${tracking.toStringAsFixed(2)} em';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label & Readout
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Letter spacing',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                Text(
                  'Tracking / Kerning',
                  style: TextStyle(
                    fontSize: 11,
                    color: mutedText,
                  ),
                ),
              ],
            ),
            Text(
              readoutText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: labelColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Slider (-0.05 to +0.25) with checkpoints
        _buildCustomSlider(
          value: tracking.clamp(-0.05, 0.25),
          min: -0.05,
          max: 0.25,
          divisions: 30,
          thumbColor: sliderThumb,
          activeColor: sliderActive,
          inactiveColor: sliderInactive,
          onChanged: onTrackingChanged,
        ),
        const SizedBox(height: 2),

        // Range Labels: -0.05em, Normal, +0.25em
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '-0.05em (Tight)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: mutedText,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'Normal',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: mutedText,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '+0.25em (Wide)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: mutedText,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // CUSTOM SLIDER THEME HELPER
  // ===========================================================================

  Widget _buildCustomSlider({
    required double value,
    required double min,
    required double max,
    int? divisions,
    required Color thumbColor,
    required Color activeColor,
    required Color inactiveColor,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3.5,
        activeTrackColor: activeColor,
        inactiveTrackColor: inactiveColor,
        thumbColor: thumbColor,
        overlayColor: thumbColor.withValues(alpha: 0.12),
        tickMarkShape: const RoundSliderTickMarkShape(
          tickMarkRadius: 1.5,
        ),
        activeTickMarkColor: activeColor.withValues(alpha: 0.35),
        inactiveTickMarkColor: inactiveColor.withValues(alpha: 0.55),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6.5,
          pressedElevation: 3,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

/// Compatibility typedef
typedef TypographyControlsCard = StageTelemetryCard;
