import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The search field that lives in the pinned header.
///
/// Only the query input is pinned; the sort control and category chips below
/// it scroll with the cards so they cannot crowd the fixed bar.
class ExploreSearchBar extends StatefulWidget {
  const ExploreSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  @override
  State<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends State<ExploreSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const cornerRadius = 12.0;

    // Modern layered dark theme colors
    final fillColor = isDark
        ? (_isFocused ? const Color(0xFF1E212B) : const Color(0xFF161820))
        : (_isFocused ? Colors.white : const Color(0xFFF1F2F6));

    final baseBorderColor = isDark
        ? Colors.white.withValues(alpha: _isFocused ? 0.35 : 0.09)
        : Colors.black.withValues(alpha: _isFocused ? 0.40 : 0.10);

    final accentColor = isDark
        ? const Color(0xFF3B82F6)
        : const Color(0xFF2563EB);
    final borderColor = _isFocused ? accentColor : baseBorderColor;

    final isApple =
        theme.platform == TargetPlatform.macOS ||
        theme.platform == TargetPlatform.iOS;
    final shortcutLabel = isApple ? '⌘K' : 'Ctrl+K';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _focusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _focusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_focusNode.hasFocus) {
            widget.onClear();
            _focusNode.unfocus();
          }
        },
      },
      child: Semantics(
        label: 'Search font family or category',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(cornerRadius),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              else if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                AnimatedRotation(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  turns: _isFocused ? 0.02 : 0.0,
                  child: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _isFocused
                        ? accentColor
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search font family or category...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // Animated clear button & keyboard shortcut cue
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: widget.showClear
                      ? IconButton(
                          key: const ValueKey('clear-btn'),
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: theme.colorScheme.onSurfaceVariant,
                          splashRadius: 16,
                          tooltip: 'Clear search',
                          onPressed: widget.onClear,
                        )
                      : (!_isFocused
                            ? Container(
                                key: const ValueKey('kbd-tag'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  shortcutLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              )
                            : const SizedBox(key: ValueKey('empty'), width: 4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
