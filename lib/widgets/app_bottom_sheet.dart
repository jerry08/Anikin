import 'package:flutter/material.dart';

import '../core/app_theme.dart';

typedef AppBottomSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

const double _desktopPanelWidth = 480;
const double _desktopPanelMaxWidthFraction = 0.42;

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required AppBottomSheetBuilder builder,
  double initialChildSize = 0.72,
  double minChildSize = 0.32,
  double maxChildSize = 0.92,
  List<double>? snapSizes,
  bool useSafeArea = true,
}) {
  if (MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint) {
    return showDialog<T>(
      context: context,
      useSafeArea: useSafeArea,
      builder: (context) => _DesktopPanelDialog(builder: builder),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: useSafeArea,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: true,
      snapSizes: snapSizes ?? [initialChildSize, maxChildSize],
      builder: builder,
    ),
  );
}

class _DesktopPanelDialog extends StatefulWidget {
  const _DesktopPanelDialog({required this.builder});

  final AppBottomSheetBuilder builder;

  @override
  State<_DesktopPanelDialog> createState() => _DesktopPanelDialogState();
}

class _DesktopPanelDialogState extends State<_DesktopPanelDialog> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panelWidth = (_desktopPanelWidth)
        .clamp(360.0, size.width * _desktopPanelMaxWidthFraction)
        .toDouble();

    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: panelWidth,
          maxHeight: size.height - 48,
        ),
        child: PrimaryScrollController(
          controller: _scrollController,
          child: widget.builder(context, _scrollController),
        ),
      ),
    );
  }
}
