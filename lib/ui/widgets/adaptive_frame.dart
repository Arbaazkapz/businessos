import 'package:flutter/material.dart';

/// Wraps the whole app (via MaterialApp.builder) so the design stays the same
/// on every device:
///  * text size follows the phone's setting but is kept in a range the layouts
///    were designed for (0.9x - 1.15x), so big "font size" settings or
///    "display size" changes cannot break cards and buttons;
///  * on wide screens (tablets, foldables, landscape) the app keeps its phone
///    layout in a centred column instead of stretching every card edge to edge.
class AdaptiveFrame extends StatelessWidget {
  const AdaptiveFrame({super.key, required this.child});

  final Widget child;

  static const double maxContentWidth = 600;
  static const double minTextScale = 0.9;
  static const double maxTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scaler = mq.textScaler.clamp(
      minScaleFactor: minTextScale,
      maxScaleFactor: maxTextScale,
    );

    if (mq.size.width <= maxContentWidth) {
      return MediaQuery(
        data: mq.copyWith(textScaler: scaler),
        child: child,
      );
    }

    // Wide screen: centred phone-width column.
    final outer = Theme.of(context).colorScheme.surfaceContainer;
    final inner = MediaQuery(
      data: mq.copyWith(
        textScaler: scaler,
        size: Size(maxContentWidth, mq.size.height),
        padding: mq.padding.copyWith(left: 0, right: 0),
        viewPadding: mq.viewPadding.copyWith(left: 0, right: 0),
      ),
      child: child,
    );
    return ColoredBox(
      color: outer,
      child: Center(
        child: SizedBox(
          width: maxContentWidth,
          height: mq.size.height,
          child: ClipRect(child: inner),
        ),
      ),
    );
  }
}
