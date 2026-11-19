import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../services/font_service.dart';

/// Renders text using either Flutter's dynamic [FontLoader] (for newly discovered
/// or catalogue fonts with file URLs) or the `google_fonts` package (for bundled
/// fallback fonts).
///
/// If fetching fails, the preview gracefully falls back to the system font
/// and provides helpful error details with an optional retry action.
class FontText extends StatefulWidget {
  const FontText({
    super.key,
    required this.fontFamily,
    required this.text,
    this.style = const TextStyle(fontSize: 20),
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.showErrorNotice = true,
  });

  final String fontFamily;
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final bool showErrorNotice;

  @override
  State<FontText> createState() => _FontTextState();
}

class _FontTextState extends State<FontText> {
  int _retryKey = 0;
  Future<void>? _pending;
  String? _pendingKey;

  Future<void> _pendingFor(String family) {
    // Keyed on the family and the retry counter, so a real retry gets a new load
    // while plain rebuilds reuse the in-flight or failed future.
    final key = '$family|$_retryKey';
    if (_pendingKey != key) {
      _pendingKey = key;
      _pending = FontService.instance.previewFont(family);
    }
    return _pending!;
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.fontFamily;
    final theme = Theme.of(context);

    // 1. If loaded into Flutter engine via FontLoader
    if (FontService.instance.isFontLoaded(family)) {
      return Text(
        widget.text,
        style: widget.style.copyWith(fontFamily: family),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }

    final entry = FontService.instance.getEntry(family);
    final hasFileUrl = entry?.hasFileUrl ?? false;
    final isGoogleFonts = FontService.isGoogleFontsSupported(family);

    // 2. If registry entry has a file URL -> FutureBuilder on per-family preview future
    if (hasFileUrl) {
      return FutureBuilder<void>(
        key: ValueKey('fl-$family-$_retryKey'),
        future: _pendingFor(family),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildFallback(
              context,
              errorMessage:
                  'Font "$family" could not be loaded dynamically. Showing system font.',
              canRetry: true,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Text(
              widget.text,
              style: widget.style.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
            );
          }

          return Text(
            widget.text,
            style: widget.style.copyWith(fontFamily: family),
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
          );
        },
      );
    }

    // 3. Otherwise, if supported by google_fonts package -> google_fonts FutureBuilder path
    if (isGoogleFonts) {
      try {
        final googleStyle =
            GoogleFonts.getFont(family, textStyle: widget.style);
        return FutureBuilder<void>(
          key: ValueKey('gf-$family-$_retryKey'),
          future: _pendingFor(family),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildFallback(
                context,
                errorMessage:
                    'Google Font "$family" could not be loaded. Showing system font.',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(
                widget.text,
                style: widget.style.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
                textAlign: widget.textAlign,
                maxLines: widget.maxLines,
              );
            }

            return Text(
              widget.text,
              style: googleStyle,
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
            );
          },
        );
      } catch (_) {
        // Fall through to fallback
      }
    }

    // 4. Fallback when font is missing / cannot be loaded
    return _buildFallback(
      context,
      errorMessage: 'Font "$family" is not available. Showing system font.',
    );
  }

  Widget _buildFallback(
    BuildContext context, {
    required String errorMessage,
    bool canRetry = false,
  }) {
    if (!widget.showErrorNotice) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (canRetry) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _retryKey++),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
