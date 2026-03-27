import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebRatioFrame extends StatelessWidget {
  const WebRatioFrame({
    super.key,
    required this.child,
    this.widthRatio = 1.5,
    this.heightRatio = 2,
  });

  final Widget child;
  final double widthRatio;
  final double heightRatio;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final targetWidth = maxHeight * (widthRatio / heightRatio);

        final sideBackdrop = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.primary.withValues(alpha: 0.18),
              colorScheme.secondary.withValues(alpha: 0.14),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        );

        if (maxWidth <= targetWidth) {
          return Container(
            decoration: sideBackdrop,
            child: child,
          );
        }

        return Container(
          decoration: sideBackdrop,
          child: Center(
            child: SizedBox(
              width: targetWidth,
              height: maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
