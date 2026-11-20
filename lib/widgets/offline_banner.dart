import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// A compact info banner shown when the user is browsing bundled offline fonts
/// instead of the live Google Fonts API catalogue.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFEEEEEE),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Browsing bundled offline fonts. Connect with your API key to search the entire online catalogue.',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: onConnect,
              child: const Text('Connect API', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
