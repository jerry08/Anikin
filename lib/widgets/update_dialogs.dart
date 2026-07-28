import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import 'app_dialogs.dart';

Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateCheckResult result,
  UpdateService updateService,
) {
  final release = result.release;
  final notes = release.body.isEmpty ? null : _trimReleaseNotes(release.body);
  final canInstallDirectly = updateService.canInstallDirectly(release);
  var startingDownload = false;
  Object? downloadError;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            icon: const Icon(Icons.system_update_alt),
            title: const Text('Update available'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${release.title} is available. You are on '
                      '${result.currentVersion}.',
                    ),
                    if (canInstallDirectly) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'The APK will download in the background. Android will '
                        'ask you to approve the installation when it is ready.',
                      ),
                    ],
                    if (notes != null) ...[
                      const SizedBox(height: 16),
                      SelectableText(notes),
                    ],
                    if (startingDownload) ...[
                      const SizedBox(height: 18),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Starting Android download…'),
                    ],
                    if (downloadError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Could not start the update: $downloadError',
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              AppDialogAction(
                label: 'Later',
                onPressed: startingDownload
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
              ),
              if (canInstallDirectly)
                AppDialogAction(
                  label: downloadError == null
                      ? 'Download and install'
                      : 'Retry',
                  onPressed: startingDownload
                      ? null
                      : () async {
                          setDialogState(() {
                            startingDownload = true;
                            downloadError = null;
                          });
                          try {
                            await updateService.downloadAndInstall(release);
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Downloading Anikin ${release.version}. '
                                    'The installer will open when it is ready.',
                                  ),
                                ),
                              );
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                startingDownload = false;
                                downloadError = error;
                              });
                            }
                          }
                        },
                )
              else
                AppDialogAction(
                  label: 'Open release',
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    final uri = Uri.tryParse(release.url);
                    if (uri == null ||
                        !await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                      if (context.mounted) {
                        await showErrorDialog(
                          context,
                          'Unable to open ${release.url}',
                          title: 'Unable to open release',
                        );
                      }
                    }
                  },
                ),
            ],
          );
        },
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
