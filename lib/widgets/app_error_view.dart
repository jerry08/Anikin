import 'package:flutter/material.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _CenteredStateBody(
      children: [
        Icon(Icons.cloud_off_outlined, color: colorScheme.secondary, size: 42),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return _CenteredStateBody(
      children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _CenteredStateBody extends StatelessWidget {
  const _CenteredStateBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final body = Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        );

        if (!constraints.hasBoundedHeight) {
          return Center(child: body);
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: body),
          ),
        );
      },
    );
  }
}
