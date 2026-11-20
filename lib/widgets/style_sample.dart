import 'package:material_ui/material_ui.dart';

import 'font_text.dart';

class StyleSample extends StatelessWidget {
  const StyleSample({
    super.key,
    required this.font,
    required this.label,
    required this.size,
    required this.weight,
    this.italic = false,
  });

  final String font;
  final String label;
  final double size;
  final FontWeight weight;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              '$label\n${size.toInt()} px',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: FontText(
              fontFamily: font,
              text: 'The art of type.',
              style: TextStyle(
                fontSize: size,
                fontWeight: weight,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
