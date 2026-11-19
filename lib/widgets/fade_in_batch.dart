import 'package:material_ui/material_ui.dart';

/// Fades a card into view when it belongs to a newly appended list batch.
///
/// The Explore screen reveals the catalogue a batch at a time. Existing cards
/// must not replay their entrance animation when the list rebuilds, so the
/// screen hands every card [fadeFrom] — the index where the most recently
/// appended batch starts. The boundary is captured when the card is created,
/// not re-evaluated on rebuild: a card that started fading keeps its
/// `FadeTransition` even if a later batch moves [fadeFrom] past it. Cards
/// created before the boundary (and every card when the platform asks for
/// reduced motion) render their [child] untouched.
///
/// The animation runs once per [State], so an ordinary rebuild of an already
/// faded card leaves it fully opaque. Reduced motion is read in [build] rather
/// than here, because the ambient [MediaQuery] can change while the widget is
/// alive.
class FadeInBatch extends StatefulWidget {
  const FadeInBatch({
    super.key,
    required this.index,
    required this.fadeFrom,
    required this.child,
  });

  /// Position of this card in the revealed list.
  final int index;

  /// Index at which the most recently appended batch starts.
  ///
  /// Cards with `index >= fadeFrom` animate; earlier cards do not.
  final int fadeFrom;

  /// The card to fade in.
  final Widget child;

  /// How long a newly appended card takes to reach full opacity.
  static const Duration duration = Duration(milliseconds: 220);

  @override
  State<FadeInBatch> createState() => _FadeInBatchState();
}

class _FadeInBatchState extends State<FadeInBatch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _opacity;
  late final bool _animates;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: FadeInBatch.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _animates = widget.index >= widget.fadeFrom;
    if (_animates) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    // The curve listens to the controller, so it is torn down first.
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      !_animates || MediaQuery.disableAnimationsOf(context)
          ? widget.child
          : FadeTransition(opacity: _opacity, child: widget.child);
}
