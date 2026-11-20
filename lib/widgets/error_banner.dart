import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// A banner card that displays an error message when the Google Fonts API
/// catalogue cannot be loaded, with retry and offline-fallback actions.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.errorMessage,
    required this.isMissingApiKey,
    required this.onRetry,
    required this.onUseOffline,
  });

  final String? errorMessage;
  final bool isMissingApiKey;
  final VoidCallback onRetry;
  final VoidCallback onUseOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkSurface : const Color(0xFFF9F9F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMissingApiKey
                      ? Icons.key_outlined
                      : Icons.cloud_off_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMissingApiKey
                        ? 'Google Fonts API key required for live catalogue'
                        : 'Could not connect to Google Fonts API',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Network error.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry connection'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.darkPrimaryAccent
                        : AppColors.charcoal,
                    foregroundColor: isDark
                        ? AppColors.darkBackground
                        : Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onUseOffline,
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Use offline catalogue'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
