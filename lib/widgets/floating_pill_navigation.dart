import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Extra space that scrollable screens should reserve at the bottom so the
/// floating navigation pill never covers their last cards or controls.
const double kFloatingPillNavigationClearance = 96;

/// Width of an inactive destination (icon only).
const double _kInactiveWidth = 52.0;

/// Width of the active destination (icon + label).
const double _kActiveWidth = 116.0;

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

  /// Short label shown beside the icon when the destination is active.
  final String label;
}

/// A compact, capsule-shaped bottom navigation bar whose active destination
/// expands into a pill showing icon + label while inactive destinations
/// collapse to icon-only. The active pill slides and snaps between positions
/// with a spring-like animation.
class FloatingPillNavigation extends StatefulWidget {
  const FloatingPillNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.animationDuration = const Duration(milliseconds: 350),
    this.backgroundColor,
    this.activeIndicatorColor,
    this.activeForegroundColor,
    this.inactiveForegroundColor,
    this.height = 56,
  }) : assert(destinations.length > 0, 'At least one destination is required.'),
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

  /// Overall pill height. Must be at least 48 logical pixels.
  final double height;

  /// Total inner width for a given destination count.
  static double innerWidth(int destinationCount) =>
      _kActiveWidth + _kInactiveWidth * (destinationCount - 1);

  @override
  State<FloatingPillNavigation> createState() => _FloatingPillNavigationState();
}

class _FloatingPillNavigationState extends State<FloatingPillNavigation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _previousIndex;
  late int _currentIndex;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex.clamp(
      0,
      widget.destinations.length - 1,
    );
    _previousIndex = _currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.value = 1.0; // start settled
  }

  @override
  void didUpdateWidget(FloatingPillNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.selectedIndex.clamp(
      0,
      widget.destinations.length - 1,
    );
    if (newIndex != _currentIndex) {
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;

      final animationsDisabled =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (animationsDisabled) {
        _controller.value = 1.0;
      } else {
        _controller.duration = widget.animationDuration;
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Compute the left offset of the indicator for a given active tab index.
  double _indicatorLeft(int activeIndex) {
    double left = 0;
    for (int i = 0; i < activeIndex; i++) {
      left += _kInactiveWidth;
    }
    return left;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = widget.backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.surface);
    final indicatorColour = widget.activeIndicatorColor ??
        (isDark ? AppColors.darkSecondarySurface : const Color(0xFFE9E9E9));
    final activeColour = widget.activeForegroundColor ??
        (isDark ? AppColors.darkPrimaryText : AppColors.charcoal);
    final inactiveColour = widget.inactiveForegroundColor ??
        (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText);
    final borderColour = isDark ? AppColors.darkBorder : AppColors.border;

    final innerHeight = widget.height - 8;
    final innerWidth = FloatingPillNavigation.innerWidth(
      widget.destinations.length,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(widget.height / 2),
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
        borderRadius: BorderRadius.circular(widget.height / 2),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: innerWidth,
              height: innerHeight,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final t = _animation.value;

                  // Interpolate indicator position.
                  final fromLeft = _indicatorLeft(_previousIndex);
                  final toLeft = _indicatorLeft(_currentIndex);
                  final indicatorLeft = lerpDouble(fromLeft, toLeft, t)!;
                  const indicatorWidth = _kActiveWidth;

                  return Stack(
                    children: [
                      // Sliding active indicator
                      Positioned(
                        left: indicatorLeft,
                        top: 0,
                        bottom: 0,
                        width: indicatorWidth,
                        child: DecoratedBox(
                          key: FloatingPillNavigation.activeIndicatorKey,
                          decoration: BoxDecoration(
                            color: indicatorColour,
                            borderRadius: BorderRadius.circular(
                              innerHeight / 2,
                            ),
                          ),
                        ),
                      ),
                      // Destination buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < widget.destinations.length; i++)
                            _PillDestinationButton(
                              destination: widget.destinations[i],
                              selected: i == _currentIndex,
                              activeColour: activeColour,
                              inactiveColour: inactiveColour,
                              progress: _buttonProgress(i, t),
                              onTap: () => widget.onDestinationSelected(i),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns 0..1 for how "active" button [index] is right now.
  /// 1 = fully expanded (icon + label), 0 = fully collapsed (icon only).
  double _buttonProgress(int index, double t) {
    if (index == _currentIndex && index == _previousIndex) return 1.0;
    if (index == _currentIndex) return t;
    if (index == _previousIndex) return 1.0 - t;
    return 0.0;
  }
}

class _PillDestinationButton extends StatelessWidget {
  const _PillDestinationButton({
    required this.destination,
    required this.selected,
    required this.activeColour,
    required this.inactiveColour,
    required this.progress,
    required this.onTap,
  });

  final FloatingPillDestination destination;
  final bool selected;
  final Color activeColour;
  final Color inactiveColour;

  /// 0 = fully inactive (icon only), 1 = fully active (icon + label).
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = Color.lerp(inactiveColour, activeColour, progress)!;
    final width = lerpDouble(_kInactiveWidth, _kActiveWidth, progress)!;
    final labelOpacity = progress.clamp(0.0, 1.0);

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: foreground,
                ),
                // Animated label: width + opacity transition
                ClipRect(
                  child: SizedBox(
                    width: lerpDouble(0, 60, labelOpacity),
                    child: Opacity(
                      opacity: labelOpacity,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.1,
                            letterSpacing: 0.2,
                            fontWeight: FontWeight.w600,
                            color: foreground,
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
      ),
    );
  }
}
