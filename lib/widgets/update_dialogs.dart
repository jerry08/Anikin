import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import 'app_dialogs.dart';

Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateCheckResult result,
) {
  final release = result.release;
  final notes = release.body.isEmpty ? null : _trimReleaseNotes(release.body);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.system_update_alt),
        title: const Text('Update available'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${release.title} is available. You are on '
                  '${result.currentVersion}.',
                ),
                if (notes != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(notes),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final uri = Uri.tryParse(release.url);
              if (uri == null ||
                  !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  await showErrorDialog(
                    context,
                    'Unable to open ${release.url}',
                    title: 'Unable to open release',
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open release'),
          ),
        ],
      );
    },
  );
}

Future<void> showNoUpdateDialog(
  BuildContext context,
  UpdateCheckResult result,
) {
  return showAppMessageDialog(
    context,
    title: 'You are up to date',
    message: 'Anikin ${result.currentVersion} is the latest release.',
    icon: Icons.verified_outlined,
  );
}

String _trimReleaseNotes(String notes) {
  const maxLength = 900;
  if (notes.length <= maxLength) {
    return notes;
  }
  return '${notes.substring(0, maxLength).trimRight()}\n...';
}
