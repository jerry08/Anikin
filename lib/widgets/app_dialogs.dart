import 'package:flutter/material.dart';

class AppDialogAction extends StatelessWidget {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: destructive
          ? TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            )
          : null,
      child: Text(label),
    );
  }
}

Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(
              icon,
              color: destructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        AppDialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppDialogAction(
          label: confirmLabel,
          destructive: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

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
          AppDialogAction(
            label: 'OK',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}
