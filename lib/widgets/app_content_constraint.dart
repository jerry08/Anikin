import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class AppContentConstraint extends StatelessWidget {
  const AppContentConstraint({
    required this.child,
    this.maxWidth = AppLayout.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
