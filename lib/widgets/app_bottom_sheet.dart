import 'package:flutter/material.dart';

typedef AppBottomSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required AppBottomSheetBuilder builder,
  double initialChildSize = 0.72,
  double minChildSize = 0.32,
  double maxChildSize = 0.92,
  List<double>? snapSizes,
  bool useSafeArea = true,
}) {
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
