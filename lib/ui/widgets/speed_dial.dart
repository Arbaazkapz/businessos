import 'package:flutter/material.dart';

/// One action in the speed dial.
class SpeedDialItem {
  const SpeedDialItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Big rounded "+" button. Tapping it dims the screen and fans out labelled
/// pill buttons above it (Google Keep style); the "+" turns into a "x".
/// Put it in `Scaffold.floatingActionButton`.
class SpeedDialFab extends StatefulWidget {
  const SpeedDialFab({
    super.key,
    required this.items,
    this.tooltip = 'Quick tools',
  });

  /// items[0] is shown closest to the button.
  final List<SpeedDialItem> items;
  final String tooltip;

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _open = false;

  Future<void> _openDial() async {
    if (_open) return;
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _open = true);
    final picked = await showGeneralDialog<SpeedDialItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondary) => _SpeedDialLayer(
        anchor: anchor,
        items: widget.items,
        animation: animation,
      ),
    );
    if (mounted) setState(() => _open = false);
    // Run the action only after the dial has closed.
    picked?.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: _open ? 0 : 1,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: Material(
          key: _anchorKey,
          color: scheme.primary,
          elevation: 6,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openDial,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(
                Icons.add_rounded,
                size: 40,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedDialLayer extends StatelessWidget {
  const _SpeedDialLayer({
    required this.anchor,
    required this.items,
    required this.animation,
  });

  final Rect anchor;
  final List<SpeedDialItem> items;
  final Animation<double> animation;

  Widget _pill(BuildContext context, SpeedDialItem item, int distance) {
    final scheme = Theme.of(context).colorScheme;
    final end = (0.5 + 0.1 * distance).clamp(0.5, 1.0).toDouble();
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(0.1 * distance, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(curved),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: scheme.primary,
            elevation: 4,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(30),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.pop(context, item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: SizedBox(
                  height: 58,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: scheme.onPrimary, size: 26),
                      const SizedBox(width: 12),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    // Farthest item first (top), nearest to the button last (bottom).
    final ordered = <Widget>[
      for (var i = items.length - 1; i >= 0; i--) _pill(context, items[i], i),
    ];
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            right: size.width - anchor.right,
            bottom: size.height - anchor.top + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ordered,
            ),
          ),
          Positioned(
            left: anchor.left,
            top: anchor.top,
            width: anchor.width,
            height: anchor.height,
            child: Material(
              color: scheme.primaryContainer,
              elevation: 6,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: RotationTransition(
                  turns: Tween<double>(begin: -0.25, end: 0).animate(animation),
                  child: Icon(
                    Icons.close_rounded,
                    size: 38,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
