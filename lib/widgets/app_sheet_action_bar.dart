import 'package:flutter/material.dart';

class AppSheetActionBar extends StatelessWidget {
  const AppSheetActionBar({
    required this.children,
    this.showDivider = true,
    this.minimum = const EdgeInsets.fromLTRB(12, 8, 12, 12),
    super.key,
  });

  final List<Widget> children;
  final bool showDivider;
  final EdgeInsets minimum;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) const Divider(height: 1),
        SafeArea(
          top: false,
          minimum: minimum,
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: children,
          ),
        ),
      ],
    );
  }
}
