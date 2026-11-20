import 'package:material_ui/material_ui.dart';

import '../models/font_model.dart';
import '../theme/app_colors.dart';
import 'font_text.dart';

/// A compact horizontal-scroll tile used in the Home screen font shelf.
///
/// Shows a large "Aa" glyph in the target typeface plus the font name below.
/// Tapping selects the font; [isSelected] draws an accent ring.
class FontShelfTile extends StatelessWidget {
  const FontShelfTile({
    super.key,
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  final FontModel font;
  final bool isSelected;
  final VoidCallback onTap;

  static const double tileWidth = 148;
  static const double tileHeight = 130;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final ambientShadow = BoxShadow(
      color: isDark ? AppColors.shadowAmbientDark : AppColors.shadowAmbientLight,
      blurRadius: 12,
      offset: const Offset(0, 2),
    );
    final keyShadow = BoxShadow(
      color: isDark ? AppColors.shadowKeyDark : AppColors.shadowKeyLight,
      blurRadius: 6,
      offset: const Offset(0, 4),
    );

    final borderColor = isSelected
        ? theme.colorScheme.primary
        : (isDark ? AppColors.darkBorder : AppColors.border);
    final borderWidth = isSelected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: tileWidth,
        height: tileHeight,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [ambientShadow, keyShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: FontText(
                          fontFamily: font.name,
                          text: 'Aa',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface,
                            height: 1.0,
                          ),
                          showErrorNotice: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      font.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      font.category,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
