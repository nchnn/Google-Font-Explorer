import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Extra space that scrollable screens should reserve at the bottom so the
/// floating navigation pill never covers their last cards or controls.
const double kFloatingPillNavigationClearance = 96;

/// A single destination shown inside [FloatingPillNavigation].
class FloatingPillDestination {
  const FloatingPillDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Icon shown while the destination is not selected.
  final IconData icon;

  /// Icon shown while the destination is selected.
  final IconData selectedIcon;

  /// Short label displayed below the icon.
  final String label;
}

/// A compact, capsule-shaped bottom navigation bar with a single active
/// indicator that slides horizontally between destinations.
///
/// The widget intentionally sizes itself to its content instead of filling the
/// available width, keeping the navigation short and floating.
class FloatingPillNavigation extends StatelessWidget {
  const FloatingPillNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.animationDuration = const Duration(milliseconds: 300),
    this.backgroundColor,
    this.activeIndicatorColor,
    this.activeForegroundColor,
    this.inactiveForegroundColor,
    this.itemWidth = 76,
    this.height = 60,
  }) : assert(destinations.length > 0, 'At least one destination is required.'),
       assert(
         itemWidth >= 48,
         'Destinations must be at least 48 logical pixels wide.',
       ),
       assert(
         height >= 48,
         'Touch targets must be at least 48 logical pixels high.',
       );

  /// Key placed on the visual active indicator, useful for tests and tooling.
  static const Key activeIndicatorKey = Key('floating-pill-active-indicator');

  /// Index of the destination that is currently displayed.
  final int selectedIndex;

  /// Called with the destination index when it is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// The destinations rendered from left to right.
  final List<FloatingPillDestination> destinations;

  /// Duration of the sliding indicator animation.
  final Duration animationDuration;

  /// Optional override for the pill background.
  final Color? backgroundColor;

  /// Optional override for the sliding indicator colour.
  final Color? activeIndicatorColor;

  /// Optional override for the selected icon and label colour.
  final Color? activeForegroundColor;

  /// Optional override for unselected icon and label colours.
  final Color? inactiveForegroundColor;

  /// Width reserved for each destination. Must be at least 48 logical pixels.
  final double itemWidth;

  /// Overall pill height. Must be at least 48 logical pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background =
        backgroundColor ?? (isDark ? AppColors.darkSurface : AppColors.surface);
    final indicatorColour =
        activeIndicatorColor ??
        (isDark ? AppColors.darkSecondarySurface : const Color(0xFFE9E9E9));
    final activeColour =
        activeForegroundColor ??
        (isDark ? AppColors.darkPrimaryText : AppColors.charcoal);
    final inactiveColour =
        inactiveForegroundColor ??
        (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText);
    final borderColour = isDark ? AppColors.darkBorder : AppColors.border;

    // Respect the platform's reduce-motion accessibility setting.
    final animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effectiveDuration = animationsDisabled
        ? Duration.zero
        : animationDuration;

    final activeIndex = selectedIndex.clamp(0, destinations.length - 1);
    final activeAlignment = destinations.length == 1
        ? Alignment.center
        : Alignment(-1 + (2 * activeIndex) / (destinations.length - 1), 0);

    final innerWidth = itemWidth * destinations.length;
    final innerHeight = height - 8; // 4 logical pixels of padding on each side.

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: borderColour),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.10),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        // A transparency-only Material scopes ink feedback to the pill. It
        // paints no background of its own, so the capsule's rounded colour and
        // shadow above remain the only visible navigation surface.
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: innerWidth,
              height: innerHeight,
              child: Stack(
                children: [
                  // The single sliding active indicator. Only this inner element
                  // moves; the navigation container itself stays stationary.
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: activeAlignment,
                      duration: effectiveDuration,
                      curve: Curves.easeInOutCubic,
                      child: FractionallySizedBox(
                        widthFactor: 1 / destinations.length,
                        heightFactor: 1,
                        child: DecoratedBox(
                          key: activeIndicatorKey,
                          decoration: BoxDecoration(
                            color: indicatorColour,
                            borderRadius: BorderRadius.circular(
                              innerHeight / 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < destinations.length; index++)
                        _PillDestinationButton(
                          destination: destinations[index],
                          selected: index == activeIndex,
                          width: itemWidth,
                          activeColour: activeColour,
                          inactiveColour: inactiveColour,
                          animationDuration: effectiveDuration,
                          onTap: () => onDestinationSelected(index),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillDestinationButton extends StatelessWidget {
  const _PillDestinationButton({
    required this.destination,
    required this.selected,
    required this.width,
    required this.activeColour,
    required this.inactiveColour,
    required this.animationDuration,
    required this.onTap,
  });

  final FloatingPillDestination destination;
  final bool selected;
  final double width;
  final Color activeColour;
  final Color inactiveColour;
  final Duration animationDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? activeColour : inactiveColour;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: foreground.withValues(alpha: 0.08),
        highlightColor: foreground.withValues(alpha: 0.05),
        hoverColor: foreground.withValues(alpha: 0.05),
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.25,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: foreground,
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: animationDuration,
                  curve: Curves.easeInOutCubic,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    letterSpacing: 0.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: foreground,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
