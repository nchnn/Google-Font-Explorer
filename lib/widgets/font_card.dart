import 'package:material_ui/material_ui.dart';

import '../models/font_model.dart';
import '../theme/app_colors.dart';
import 'font_text.dart';

/// Card displaying a font family, its category, variant details,
/// and a live typography sample.
class FontCard extends StatelessWidget {
  const FontCard({
    super.key,
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  final FontModel font;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      font.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20)
                  else
                    Icon(
                      Icons.circle_outlined,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFEBEBEB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      font.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      font.variantsLabel,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FontText(
                fontFamily: font.name,
                text: 'Typography that speaks.',
                style: TextStyle(
                  fontSize: 22,
                  // List previews always show the regular weight; requesting
                  // anything heavier would download an extra variant per card.
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                showErrorNotice: false,
              ),
              const SizedBox(height: 8),
              Text(
                font.description,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
