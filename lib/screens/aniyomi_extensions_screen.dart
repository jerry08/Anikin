import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/aniyomi_extension_service.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_error_view.dart';

class AniyomiExtensionsScreen extends StatefulWidget {
  const AniyomiExtensionsScreen({required this.extensionService, super.key});

  final AniyomiExtensionService extensionService;

  @override
  State<AniyomiExtensionsScreen> createState() =>
      _AniyomiExtensionsScreenState();
}

class _AniyomiExtensionsScreenState extends State<AniyomiExtensionsScreen> {
  List<String> _repos = const [];
  List<AniyomiExtensionInfo> _available = const [];
  List<AniyomiExtensionInfo> _installed = const [];
  _ExtensionFilter _filter = _ExtensionFilter.all;
  _ExtensionSortOrder _sortOrder = _ExtensionSortOrder.nameAsc;
  bool _loading = true;
  bool _refreshing = false;
  String? _busyPackage;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final supported = await widget.extensionService.isSupported();
      if (!mounted) return;
      if (!supported) {
        setState(() {
          _repos = const [];
          _available = const [];
          _installed = const [];
        });
        return;
      }
      final results = await Future.wait<Object>([
        widget.extensionService.getRepos(),
        widget.extensionService.getAvailableExtensions(),
        widget.extensionService.getInstalledExtensions(),
      ]);
      if (!mounted) return;
      setState(() {
        _repos = results[0] as List<String>;
        _available = results[1] as List<AniyomiExtensionInfo>;
        _installed = results[2] as List<AniyomiExtensionInfo>;
      });
      // Repos are configured but nothing is cached yet (e.g. first run after
      // install): fetch the index automatically instead of waiting for a
      // manual refresh.
      if (_repos.isNotEmpty && _available.isEmpty && !_refreshing) {
        await _refreshAvailable();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted && showLoading) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAvailable() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await widget.extensionService.refreshAvailableExtensions();
      await _load(showLoading: false);
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error, title: 'Refresh failed');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _addRepo() async {
    final repo = await showDialog<String>(
      context: context,
      builder: (context) => const _AddRepoDialog(),
    );
    if (!mounted || repo == null || repo.trim().isEmpty) return;
    try {
      await widget.extensionService.addRepo(repo);
      await _refreshAvailable();
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error, title: 'Repository failed');
      }
    }
  }

  Future<void> _removeRepo(String repo) async {
    try {
      await widget.extensionService.removeRepo(repo);
      await _load(showLoading: false);
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error, title: 'Repository failed');
      }
    }
  }

  Future<void> _runPackageAction(
    AniyomiExtensionInfo extension,
    Future<void> Function(String pkgName) action,
  ) async {
    setState(() => _busyPackage = extension.pkgName);
    try {
      await action(extension.pkgName);
      await _load(showLoading: false);
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error, title: 'Extension failed');
      }
    } finally {
      if (mounted) setState(() => _busyPackage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aniyomi extensions'),
          actions: [
            IconButton(
              tooltip: 'Filter and order',
              onPressed: _showFilterOrderDialog,
              icon: Badge(
                isLabelVisible:
                    _filter != _ExtensionFilter.all ||
                    _sortOrder != _ExtensionSortOrder.nameAsc,
                smallSize: 8,
                child: const Icon(Icons.tune_outlined),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshing ? null : _refreshAvailable,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.live_tv_outlined), text: 'Anime'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Manga'),
              Tab(icon: Icon(Icons.hub_outlined), text: 'Repos'),
            ],
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _refreshing
                          ? const LinearProgressIndicator(minHeight: 3)
                          : const SizedBox(height: 3),
                    ),
                    if (_filter != _ExtensionFilter.all)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _ActiveFilterChip(
                            label: _filter.label,
                            onClear: () =>
                                setState(() => _filter = _ExtensionFilter.all),
                          ),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _MediaExtensionsTab(
                            mediaType: _ExtensionMediaType.anime,
                            available: _visibleExtensions(
                              _available.where((item) => !item.isInstalled),
                              _ExtensionMediaType.anime,
                            ),
                            installed: _visibleExtensions(
                              _installed,
                              _ExtensionMediaType.anime,
                            ),
                            busyPackage: _busyPackage,
                            filter: _filter,
                            onRefresh: _refreshAvailable,
                            onOpen: _openExtension,
                            onMore: _showExtensionActions,
                            onInstall: (extension) => _runPackageAction(
                              extension,
                              widget.extensionService.installExtension,
                            ),
                            onUpdate: (extension) => _runPackageAction(
                              extension,
                              widget.extensionService.updateExtension,
                            ),
                          ),
                          _MediaExtensionsTab(
                            mediaType: _ExtensionMediaType.manga,
                            available: _visibleExtensions(
                              _available.where((item) => !item.isInstalled),
                              _ExtensionMediaType.manga,
                            ),
                            installed: _visibleExtensions(
                              _installed,
                              _ExtensionMediaType.manga,
                            ),
                            busyPackage: _busyPackage,
                            filter: _filter,
                            onRefresh: _refreshAvailable,
                            onOpen: _openExtension,
                            onMore: _showExtensionActions,
                            onInstall: (extension) => _runPackageAction(
                              extension,
                              widget.extensionService.installExtension,
                            ),
                            onUpdate: (extension) => _runPackageAction(
                              extension,
                              widget.extensionService.updateExtension,
                            ),
                          ),
                          _ReposTab(
                            repos: _visibleRepos(_repos),
                            onRefresh: _refreshAvailable,
                            onAdd: _addRepo,
                            onRemove: _removeRepo,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<AniyomiExtensionInfo> _visibleExtensions(
    Iterable<AniyomiExtensionInfo> extensions,
    _ExtensionMediaType mediaType,
  ) {
    final visible = extensions
        .where(mediaType.matches)
        .where(_filter.matches)
        .toList();
    visible.sort(_sortOrder.compare);
    return visible;
  }

  List<String> _visibleRepos(List<String> repos) {
    final visible = repos.toList();
    visible.sort(
      (a, b) => switch (_sortOrder) {
        _ExtensionSortOrder.nameDesc => b.compareTo(a),
        _ => a.compareTo(b),
      },
    );
    return visible;
  }

  Future<void> _showFilterOrderDialog() async {
    final result = await showDialog<(_ExtensionFilter, _ExtensionSortOrder)>(
      context: context,
      builder: (context) => _FilterOrderDialog(
        initialFilter: _filter,
        initialSortOrder: _sortOrder,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filter = result.$1;
      _sortOrder = result.$2;
    });
  }

  void _openExtension(AniyomiExtensionInfo extension) {
    if (!extension.isInstalled) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExtensionDetailsScreen(extension: extension),
      ),
    );
  }

  Future<void> _showExtensionActions(AniyomiExtensionInfo extension) async {
    final action = await showDialog<_ExtensionAction>(
      context: context,
      builder: (context) => _ExtensionActionsDialog(extension: extension),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _ExtensionAction.open:
        _openExtension(extension);
      case _ExtensionAction.install:
        await _runPackageAction(
          extension,
          widget.extensionService.installExtension,
        );
      case _ExtensionAction.update:
        await _runPackageAction(
          extension,
          widget.extensionService.updateExtension,
        );
      case _ExtensionAction.uninstall:
        await _runPackageAction(
          extension,
          widget.extensionService.uninstallExtension,
        );
    }
  }
}

enum _ExtensionMediaType { anime, manga }

extension on _ExtensionMediaType {
  String get label => switch (this) {
    _ExtensionMediaType.anime => 'Anime',
    _ExtensionMediaType.manga => 'Manga',
  };

  IconData get icon => switch (this) {
    _ExtensionMediaType.anime => Icons.live_tv_outlined,
    _ExtensionMediaType.manga => Icons.menu_book_outlined,
  };

  bool matches(AniyomiExtensionInfo extension) => switch (this) {
    _ExtensionMediaType.anime => extension.isAnime,
    _ExtensionMediaType.manga => extension.isManga,
  };
}

class _MediaExtensionsTab extends StatelessWidget {
  const _MediaExtensionsTab({
    required this.mediaType,
    required this.available,
    required this.installed,
    required this.busyPackage,
    required this.filter,
    required this.onRefresh,
    required this.onOpen,
    required this.onMore,
    required this.onInstall,
    required this.onUpdate,
  });

  final _ExtensionMediaType mediaType;
  final List<AniyomiExtensionInfo> available;
  final List<AniyomiExtensionInfo> installed;
  final String? busyPackage;
  final _ExtensionFilter filter;
  final Future<void> Function() onRefresh;
  final ValueChanged<AniyomiExtensionInfo> onOpen;
  final ValueChanged<AniyomiExtensionInfo> onMore;
  final ValueChanged<AniyomiExtensionInfo> onInstall;
  final ValueChanged<AniyomiExtensionInfo> onUpdate;

  @override
  Widget build(BuildContext context) {
    final hasAny = available.isNotEmpty || installed.isNotEmpty;
    return _TabList(
      onRefresh: onRefresh,
      children: [
        if (!hasAny)
          CompactEmptyState(
            icon: mediaType.icon,
            title: filter == _ExtensionFilter.all
                ? 'No ${mediaType.label.toLowerCase()} extensions'
                : 'No ${mediaType.label.toLowerCase()} extensions match this filter',
          )
        else ...[
          if (installed.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Installed',
              icon: Icons.extension_outlined,
            ),
            for (final extension in installed)
              _ExtensionTile(
                extension: extension,
                busy: busyPackage == extension.pkgName,
                primaryActionIcon: extension.hasUpdate
                    ? Icons.system_update_alt
                    : null,
                primaryActionTooltip: extension.hasUpdate ? 'Update' : null,
                onTap: () => onOpen(extension),
                onPrimaryAction: extension.hasUpdate
                    ? () => onUpdate(extension)
                    : null,
                onMore: () => onMore(extension),
              ),
          ],
          if (available.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Available',
              icon: Icons.download_outlined,
            ),
            for (final extension in available)
              _ExtensionTile(
                extension: extension,
                busy: busyPackage == extension.pkgName,
                primaryActionIcon: Icons.download_outlined,
                primaryActionTooltip: 'Install',
                onTap: null,
                onPrimaryAction: () => onInstall(extension),
                onMore: () => onMore(extension),
              ),
          ],
        ],
      ],
    );
  }
}

class _ReposTab extends StatelessWidget {
  const _ReposTab({
    required this.repos,
    required this.onRefresh,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> repos;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onAdd;
  final Future<void> Function(String repo) onRemove;

  @override
  Widget build(BuildContext context) {
    return _TabList(
      onRefresh: onRefresh,
      children: [
        const _SectionHeader(title: 'Repositories', icon: Icons.hub_outlined),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton.icon(
            onPressed: () => unawaited(onAdd()),
            icon: const Icon(Icons.add_link),
            label: const Text('Add repository'),
          ),
        ),
        if (repos.isEmpty)
          const CompactEmptyState(
            icon: Icons.link_off,
            title: 'No repositories',
          )
        else
          for (final repo in repos)
            _RepositoryTile(
              repo: repo,
              onRemove: () => unawaited(onRemove(repo)),
            ),
      ],
    );
  }
}

class _FilterOrderDialog extends StatefulWidget {
  const _FilterOrderDialog({
    required this.initialFilter,
    required this.initialSortOrder,
  });

  final _ExtensionFilter initialFilter;
  final _ExtensionSortOrder initialSortOrder;

  @override
  State<_FilterOrderDialog> createState() => _FilterOrderDialogState();
}

class _FilterOrderDialogState extends State<_FilterOrderDialog> {
  late _ExtensionFilter _filter;
  late _ExtensionSortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _sortOrder = widget.initialSortOrder;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter and order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in _ExtensionFilter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Order', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final order in _ExtensionSortOrder.values)
                  ChoiceChip(
                    label: Text(order.label),
                    selected: _sortOrder == order,
                    onSelected: (_) => setState(() => _sortOrder = order),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: 'Apply',
          onPressed: () => Navigator.of(context).pop((_filter, _sortOrder)),
        ),
      ],
    );
  }
}

enum _ExtensionAction { open, install, update, uninstall }

class _ExtensionActionsDialog extends StatelessWidget {
  const _ExtensionActionsDialog({required this.extension});

  final AniyomiExtensionInfo extension;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(extension.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(extension.pkgName, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (extension.displaySubtitle.isNotEmpty)
            Text(extension.displaySubtitle),
          const SizedBox(height: 12),
          const Divider(height: 1),
          if (extension.isInstalled)
            _ExtensionDialogActionTile(
              icon: Icons.settings_outlined,
              label: 'Details',
              onTap: () => Navigator.of(context).pop(_ExtensionAction.open),
            ),
          if (!extension.isInstalled)
            _ExtensionDialogActionTile(
              icon: Icons.download_outlined,
              label: 'Install',
              onTap: () => Navigator.of(context).pop(_ExtensionAction.install),
            )
          else if (extension.hasUpdate)
            _ExtensionDialogActionTile(
              icon: Icons.system_update_alt,
              label: 'Update',
              onTap: () => Navigator.of(context).pop(_ExtensionAction.update),
            ),
          if (extension.isInstalled)
            _ExtensionDialogActionTile(
              icon: Icons.delete_outline,
              label: 'Uninstall',
              destructive: true,
              onTap: () =>
                  Navigator.of(context).pop(_ExtensionAction.uninstall),
            ),
        ],
      ),
      actions: [
        AppDialogAction(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ExtensionDialogActionTile extends StatelessWidget {
  const _ExtensionDialogActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

class _ExtensionDetailsScreen extends StatelessWidget {
  const _ExtensionDetailsScreen({required this.extension});

  final AniyomiExtensionInfo extension;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(extension.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _ExtensionIcon(extension: extension, busy: false),
                    const SizedBox(width: 14),
                    Expanded(child: _ExtensionSummary(extension: extension)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (extension.loadError != null &&
                extension.loadError!.isNotEmpty) ...[
              _ExtensionLoadError(message: extension.loadError!),
              const SizedBox(height: 14),
            ],
            const _SectionHeader(title: 'Sources', icon: Icons.source_outlined),
            if (extension.sources.isEmpty)
              CompactEmptyState(
                icon: Icons.source_outlined,
                title: 'No sources exposed by this extension',
              )
            else
              for (final source in extension.sources)
                _SourceTile(source: source),
          ],
        ),
      ),
    );
  }
}

class _ExtensionLoadError extends StatelessWidget {
  const _ExtensionLoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extension could not be loaded',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final AniyomiExtensionSourceInfo source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: _IconBadge(
            icon: source.isManga
                ? Icons.menu_book_outlined
                : Icons.live_tv_outlined,
            color: colorScheme.primary,
          ),
          title: Text(source.name),
          subtitle: Text(source.language.toUpperCase()),
          trailing: source.baseUrl == null || source.baseUrl!.isEmpty
              ? null
              : Text(
                  Uri.tryParse(source.baseUrl!)?.host ?? source.baseUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}

enum _ExtensionFilter {
  all('All'),
  sfw('SFW only'),
  nsfw('NSFW only'),
  updates('Updates');

  const _ExtensionFilter(this.label);

  final String label;

  bool matches(AniyomiExtensionInfo extension) => switch (this) {
    _ExtensionFilter.all => true,
    _ExtensionFilter.sfw => !extension.isNsfw,
    _ExtensionFilter.nsfw => extension.isNsfw,
    _ExtensionFilter.updates => extension.hasUpdate,
  };
}

enum _ExtensionSortOrder {
  nameAsc('Name A-Z'),
  nameDesc('Name Z-A'),
  language('Language'),
  newest('Newest'),
  sourceCount('Most sources');

  const _ExtensionSortOrder(this.label);

  final String label;

  int compare(AniyomiExtensionInfo a, AniyomiExtensionInfo b) {
    return switch (this) {
      _ExtensionSortOrder.nameAsc => _compareText(a.name, b.name),
      _ExtensionSortOrder.nameDesc => _compareText(b.name, a.name),
      _ExtensionSortOrder.language => _compareText(
        a.lang ?? '',
        b.lang ?? '',
      ).nonZeroOr(_compareText(a.name, b.name)),
      _ExtensionSortOrder.newest =>
        b.versionCode
            .compareTo(a.versionCode)
            .nonZeroOr(_compareText(a.name, b.name)),
      _ExtensionSortOrder.sourceCount =>
        b.sources.length
            .compareTo(a.sources.length)
            .nonZeroOr(_compareText(a.name, b.name)),
    };
  }

  static int _compareText(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}

extension on int {
  int nonZeroOr(int fallback) => this == 0 ? fallback : this;
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.filter_alt_outlined, size: 18),
      label: Text(label),
      onDeleted: onClear,
      deleteIcon: const Icon(Icons.close, size: 18),
    );
  }
}

class _TabList extends StatelessWidget {
  const _TabList({required this.onRefresh, required this.children});

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: children,
      ),
    );
  }
}

class _AddRepoDialog extends StatefulWidget {
  const _AddRepoDialog();

  @override
  State<_AddRepoDialog> createState() => _AddRepoDialogState();
}

class _AddRepoDialogState extends State<_AddRepoDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'https://');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add repository'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          hintText: 'https://.../index.min.json',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          label: 'Add',
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}

class _RepositoryTile extends StatelessWidget {
  const _RepositoryTile({required this.repo, required this.onRemove});

  final String repo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: _IconBadge(icon: Icons.link, color: colorScheme.primary),
          title: Text(repo, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: 'Remove repository',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.extension,
    required this.busy,
    this.primaryActionIcon,
    this.primaryActionTooltip,
    this.onTap,
    this.onPrimaryAction,
    this.onMore,
  });

  final AniyomiExtensionInfo extension;
  final bool busy;
  final IconData? primaryActionIcon;
  final String? primaryActionTooltip;
  final VoidCallback? onTap;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                _ExtensionIcon(extension: extension, busy: busy),
                const SizedBox(width: 12),
                Expanded(child: _ExtensionSummary(extension: extension)),
                const SizedBox(width: 8),
                _ExtensionActions(
                  busy: busy,
                  primaryActionIcon: primaryActionIcon,
                  primaryActionTooltip: primaryActionTooltip,
                  onPrimaryAction: onPrimaryAction,
                  onMore: onMore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtensionIcon extends StatelessWidget {
  const _ExtensionIcon({required this.extension, required this.busy});

  final AniyomiExtensionInfo extension;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final iconUrl = extension.iconUrl;
    return SizedBox.square(
      dimension: 46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (iconUrl != null && iconUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: iconUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const _ExtensionIconFallback(),
                errorWidget: (context, url, error) =>
                    const _ExtensionIconFallback(),
              ),
            )
          else
            const _ExtensionIconFallback(),
          if (busy)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtensionIconFallback extends StatelessWidget {
  const _ExtensionIconFallback();

  @override
  Widget build(BuildContext context) {
    return _IconBadge(
      icon: Icons.extension_outlined,
      color: Theme.of(context).colorScheme.primary,
      size: 46,
    );
  }
}

class _ExtensionSummary extends StatelessWidget {
  const _ExtensionSummary({required this.extension});

  final AniyomiExtensionInfo extension;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sourceCount = extension.sources.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          extension.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            if (extension.lang != null && extension.lang!.isNotEmpty)
              _MetaPill(text: extension.lang!.toUpperCase()),
            if (extension.versionName.isNotEmpty)
              _MetaPill(text: extension.versionName),
            if (sourceCount > 0)
              _MetaPill(
                text: '$sourceCount source${sourceCount == 1 ? '' : 's'}',
              ),
            if (extension.hasUpdate)
              _MetaPill(
                text: 'Update',
                foreground: colorScheme.onPrimaryContainer,
                background: colorScheme.primaryContainer,
              ),
            if (extension.installLocationLabel != null)
              _MetaPill(
                text: extension.installLocationLabel!,
                foreground: colorScheme.onTertiaryContainer,
                background: colorScheme.tertiaryContainer,
              ),
            if (extension.isInstalled && !extension.isLoaded)
              _MetaPill(
                text: 'Load failed',
                foreground: colorScheme.onErrorContainer,
                background: colorScheme.errorContainer,
              ),
            if (extension.isNsfw)
              _MetaPill(
                text: 'NSFW',
                foreground: colorScheme.onErrorContainer,
                background: colorScheme.errorContainer,
              ),
          ],
        ),
        if (extension.pkgName.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            extension.pkgName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text, this.foreground, this.background});

  final String text;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = foreground ?? colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ExtensionActions extends StatelessWidget {
  const _ExtensionActions({
    required this.busy,
    this.primaryActionIcon,
    this.primaryActionTooltip,
    this.onPrimaryAction,
    this.onMore,
  });

  final bool busy;
  final IconData? primaryActionIcon;
  final String? primaryActionTooltip;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPrimaryAction != null && primaryActionIcon != null)
          IconButton.filledTonal(
            tooltip: primaryActionTooltip,
            onPressed: busy ? null : onPrimaryAction,
            icon: Icon(primaryActionIcon),
          ),
        IconButton(
          tooltip: 'More',
          onPressed: busy ? null : onMore,
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, color: color, size: size * 0.48),
      ),
    );
  }
}
