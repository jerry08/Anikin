import 'package:flutter/material.dart';

Future<void> showErrorDialog(
  BuildContext context,
  Object error, {
  String title = 'Something went wrong',
}) {
  return showAppMessageDialog(
    context,
    title: title,
    message: error.toString(),
    icon: Icons.error_outline,
    iconColor: Theme.of(context).colorScheme.error,
  );
}

Future<void> showAppMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline,
  Color? iconColor,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(icon, color: iconColor ?? colorScheme.primary),
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 320),
          child: SingleChildScrollView(child: SelectableText(message)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
