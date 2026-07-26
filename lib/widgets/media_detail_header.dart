import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';

const double kMediaDetailHeaderHeight = 400;
const double kMediaDetailCompactHeaderHeight = 304;

bool mediaDetailUsesSideNavigation(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= AppLayout.wideBreakpoint ||
      (size.width >= 600 && size.width > size.height);
}

double mediaDetailHeaderHeight(BuildContext context) {
  final base = mediaDetailUsesSideNavigation(context)
      ? kMediaDetailCompactHeaderHeight
      : kMediaDetailHeaderHeight;
  final textScale = MediaQuery.textScalerOf(context).scale(1);
  return base + ((textScale - 1).clamp(0, 1) * 52);
}

class MediaKenBurnsBanner extends StatefulWidget {
  const MediaKenBurnsBanner({
    required this.imageUrl,
    this.headers,
    this.blurred = false,
    this.scrollController,
    this.expandedHeight = kMediaDetailHeaderHeight,
    super.key,
  });

  final String imageUrl;
  final Map<String, String>? headers;
  final bool blurred;
  final ScrollController? scrollController;
  final double expandedHeight;

  @override
  State<MediaKenBurnsBanner> createState() => _MediaKenBurnsBannerState();
}

class _MediaKenBurnsBannerState extends State<MediaKenBurnsBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _isTest = bool.fromEnvironment('FLUTTER_TEST');

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<AlignmentGeometry> _alignment;
  bool _reduceMotion = false;
  bool _appIsActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.scrollController?.addListener(_syncAnimation);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 1, end: 1.14).animate(curve);
    _alignment = AlignmentTween(
      begin: const Alignment(-0.25, -0.35),
      end: const Alignment(0.3, 0.3),
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || _isTest;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant MediaKenBurnsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_syncAnimation);
      widget.scrollController?.addListener(_syncAnimation);
    }
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    final scrollController = widget.scrollController;
    final headerIsVisible =
        scrollController == null ||
        !scrollController.hasClients ||
        scrollController.offset < widget.expandedHeight - kToolbarHeight - 24;
    final shouldAnimate = !_reduceMotion && _appIsActive && headerIsVisible;
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.scrollController?.removeListener(_syncAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget image = ExcludeSemantics(
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        httpHeaders: widget.headers?.isEmpty ?? true ? null : widget.headers,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (context, _, _) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.landscape_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 44,
          ),
        ),
      ),
    );
    if (widget.blurred) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: image,
      );
    }
    if (_reduceMotion) {
      return ClipRect(child: image);
    }
    return ClipRect(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            alignment: _alignment.value,
            child: child,
          ),
          child: image,
        ),
      ),
    );
  }
}

class MediaCollapsedTitle extends StatelessWidget {
  const MediaCollapsedTitle({
    required this.controller,
    required this.text,
    this.expandedHeight = kMediaDetailHeaderHeight,
    super.key,
  });

  final ScrollController controller;
  final String text;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final visible =
            controller.hasClients &&
            controller.offset > expandedHeight - kToolbarHeight - 90;
        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}

class MediaDetailHeader extends StatelessWidget {
  const MediaDetailHeader({
    required this.title,
    this.statusText,
    this.bannerUrl,
    this.coverUrl,
    this.imageHeaders,
    this.listButtonLabel,
    this.listButtonActive = false,
    this.listButtonBusy = false,
    this.onListButtonPressed,
    this.onBannerLongPress,
    this.onCoverLongPress,
    this.onTitleLongPress,
    this.scrollController,
    this.expandedHeight = kMediaDetailHeaderHeight,
    this.posterHeroTag,
    super.key,
  });

  final String title;
  final String? statusText;
  final String? bannerUrl;
  final String? coverUrl;
  final Map<String, String>? imageHeaders;
  final String? listButtonLabel;
  final bool listButtonActive;
  final bool listButtonBusy;
  final VoidCallback? onListButtonPressed;
  final VoidCallback? onBannerLongPress;
  final VoidCallback? onCoverLongPress;
  final VoidCallback? onTitleLongPress;
  final ScrollController? scrollController;
  final double expandedHeight;
  final Object? posterHeroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = theme.scaffoldBackgroundColor;
    final bannerImage = bannerUrl ?? coverUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bannerImage != null)
          GestureDetector(
            onLongPress: onBannerLongPress,
            child: MediaKenBurnsBanner(
              imageUrl: bannerImage,
              headers: imageHeaders,
              blurred: bannerUrl == null,
              scrollController: scrollController,
              expandedHeight: expandedHeight,
            ),
          )
        else
          ColoredBox(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.landscape_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 52,
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.45, 1],
              colors: [
                background.withValues(alpha: 0),
                background.withValues(alpha: 0.30),
                background,
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  background.withValues(alpha: 0.66),
                  background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 350;
              final posterWidth = compact ? 96.0 : 108.0;
              final posterHeight = compact ? 142.0 : 160.0;
              return ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxReadableWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 20 : 24,
                        0,
                        compact ? 20 : 24,
                        compact ? 10 : 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _PosterCard(
                            url: coverUrl,
                            headers: imageHeaders,
                            onLongPress: onCoverLongPress,
                            width: posterWidth,
                            height: posterHeight,
                            heroTag: posterHeroTag,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: onTitleLongPress,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: compact ? 3 : 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                        ),
                                  ),
                                  if (statusText case final status?) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      status,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                  if (listButtonLabel case final label?) ...[
                                    SizedBox(height: compact ? 8 : 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: 1,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: compact ? 176 : 184,
                                        ),
                                        child: OutlinedButton.icon(
                                          onPressed: listButtonBusy
                                              ? null
                                              : onListButtonPressed,
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: Size(
                                              0,
                                              compact ? 40 : 42,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            side: BorderSide(
                                              color:
                                                  (listButtonActive
                                                          ? colorScheme.primary
                                                          : colorScheme
                                                                .onSurfaceVariant)
                                                      .withValues(alpha: 0.72),
                                            ),
                                            foregroundColor: listButtonActive
                                                ? colorScheme.primary
                                                : colorScheme.onSurface,
                                            backgroundColor: background
                                                .withValues(alpha: 0.52),
                                            textStyle: theme
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          icon: listButtonBusy
                                              ? const SizedBox.square(
                                                  dimension: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  listButtonActive
                                                      ? Icons.check_rounded
                                                      : Icons.add_rounded,
                                                  size: 19,
                                                ),
                                          label: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.width,
    required this.height,
    this.url,
    this.headers,
    this.onLongPress,
    this.heroTag,
  });

  final String? url;
  final Map<String, String>? headers;
  final VoidCallback? onLongPress;
  final double width;
  final double height;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget poster = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          height: height,
          child: url == null
              ? ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.movie_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : ExcludeSemantics(
                  child: CachedNetworkImage(
                    imageUrl: url!,
                    httpHeaders: headers?.isEmpty ?? true ? null : headers,
                    fit: BoxFit.cover,
                    placeholder: (context, _) =>
                        ColoredBox(color: colorScheme.surfaceContainerHighest),
                    errorWidget: (context, _, _) => ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
    if (heroTag != null) {
      poster = Hero(
        tag: heroTag!,
        child: Material(type: MaterialType.transparency, child: poster),
      );
    }
    return GestureDetector(
      onLongPress: url == null ? null : onLongPress,
      child: poster,
    );
  }
}

class MediaDetailTotalRow extends StatelessWidget {
  const MediaDetailTotalRow({
    required this.text,
    this.actions = const [],
    this.primaryActionLabel,
    this.primaryActionIcon = Icons.play_arrow_rounded,
    this.onPrimaryAction,
    this.primaryActionBusy = false,
    super.key,
  });

  final String text;
  final List<Widget> actions;
  final String? primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final bool primaryActionBusy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxReadableWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
              if (primaryActionLabel case final label?) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: primaryActionBusy ? null : onPrimaryAction,
                    icon: primaryActionBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(primaryActionIcon),
                    label: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MediaDetailActionIcon extends StatelessWidget {
  const MediaDetailActionIcon({
    required this.tooltip,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return IconButton(
      tooltip: tooltip,
      onPressed: busy ? null : onPressed,
      icon: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: busy
            ? const SizedBox.square(
                key: ValueKey('busy'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                active ? activeIcon : icon,
                key: ValueKey(active),
                color: active ? Theme.of(context).colorScheme.primary : null,
              ),
      ),
    );
  }
}

class MediaDetailTab {
  const MediaDetailTab({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeLabel,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final String? badgeLabel;
}

class MediaDetailScaffold extends StatelessWidget {
  const MediaDetailScaffold({
    required this.body,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.backgroundColor,
    super.key,
  });

  final Widget body;
  final List<MediaDetailTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final sideNavigation = mediaDetailUsesSideNavigation(context);
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          if (sideNavigation) ...[
            MediaDetailSideNav(
              tabs: tabs,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ],
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: sideNavigation
          ? null
          : MediaDetailNavBar(
              tabs: tabs,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
    );
  }
}

class MediaDetailNavBar extends StatelessWidget {
  const MediaDetailNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<MediaDetailTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _MediaDetailNavTab(
                    tab: tabs[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaDetailSideNav extends StatelessWidget {
  const MediaDetailSideNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<MediaDetailTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < tabs.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: _MediaDetailSideTab(
                    tab: tabs[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaDetailNavTab extends StatelessWidget {
  const _MediaDetailNavTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final MediaDetailTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: tab.label,
      value: tab.badgeLabel ?? tab.badge,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              width: selected ? 24 : 0,
              height: 4,
              margin: const EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              child: selected
                  ? _SelectedTabLabel(key: const ValueKey('label'), tab: tab)
                  : _IconWithBadge(
                      key: const ValueKey('icon'),
                      icon: tab.icon,
                      badge: tab.badge,
                      color: colorScheme.onSurfaceVariant,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaDetailSideTab extends StatelessWidget {
  const _MediaDetailSideTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final MediaDetailTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: tab.label,
      value: tab.badgeLabel ?? tab.badge,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          width: 76,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconWithBadge(
                icon: tab.icon,
                badge: tab.badge,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 5),
              Text(
                tab.label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedTabLabel extends StatelessWidget {
  const _SelectedTabLabel({required this.tab, super.key});

  final MediaDetailTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tab.label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        if (tab.badge case final badge?) ...[
          const SizedBox(width: 6),
          _MediaBadge(text: badge),
        ],
      ],
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.color,
    this.badge,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (badge case final text?)
          Positioned(
            top: -8,
            right: -13,
            child: _MediaBadge(text: text, compact: true),
          ),
      ],
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.text, this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 18 : 22),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 0 : 1,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 9 : null,
        ),
      ),
    );
  }
}

class MediaDetailContentConstraint extends StatelessWidget {
  const MediaDetailContentConstraint({
    required this.child,
    this.maxWidth = AppLayout.maxReadableWidth,
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

class MediaDetailSliverConstraint extends StatelessWidget {
  const MediaDetailSliverConstraint({
    required this.sliver,
    this.maxWidth = AppLayout.maxContentWidth,
    super.key,
  });

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = ((constraints.crossAxisExtent - maxWidth) / 2)
            .clamp(0, double.infinity)
            .toDouble();
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: sliver,
        );
      },
    );
  }
}

class MediaInfoRowData {
  const MediaInfoRowData(
    this.label,
    this.value, {
    this.highlight = false,
    this.onTap,
    this.semanticHint,
  });

  final String label;
  final String value;
  final bool highlight;
  final VoidCallback? onTap;
  final String? semanticHint;
}

class MediaInfoTable extends StatelessWidget {
  const MediaInfoTable({
    required this.rows,
    this.nameBlocks = const [],
    super.key,
  });

  final List<MediaInfoRowData> rows;
  final List<(String, String)> nameBlocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface.withValues(alpha: 0.62),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 440 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.45;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                _MediaInfoRow(
                  row: row,
                  stacked: stacked,
                  labelStyle: labelStyle,
                  valueStyle: row.highlight
                      ? valueStyle?.copyWith(color: colorScheme.primary)
                      : valueStyle,
                ),
              for (final (label, value) in nameBlocks) ...[
                const SizedBox(height: 14),
                Text(label, style: labelStyle),
                const SizedBox(height: 2),
                SelectionArea(child: Text(value, style: valueStyle)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MediaInfoRow extends StatelessWidget {
  const _MediaInfoRow({
    required this.row,
    required this.stacked,
    required this.labelStyle,
    required this.valueStyle,
  });

  final MediaInfoRowData row;
  final bool stacked;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final value = Row(
      mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: stacked
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            row.value,
            textAlign: stacked ? TextAlign.start : TextAlign.end,
            style: valueStyle,
          ),
        ),
        if (row.onTap != null) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label, style: labelStyle),
                const SizedBox(height: 2),
                value,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label, style: labelStyle),
                const SizedBox(width: 16),
                Expanded(child: value),
              ],
            ),
    );
    if (row.onTap == null) {
      return SelectionArea(child: content);
    }
    return Semantics(
      button: true,
      label: '${row.label}, ${row.value}',
      hint: row.semanticHint,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: row.onTap,
        child: content,
      ),
    );
  }
}

class MediaDetailSectionTitle extends StatelessWidget {
  const MediaDetailSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class MediaSourceSelectorTile extends StatelessWidget {
  const MediaSourceSelectorTile({
    required this.sourceName,
    this.onTap,
    this.matchedTitle,
    this.onWrongTitle,
    this.loading = false,
    this.errorText,
    this.onRetry,
    super.key,
  });

  final String sourceName;
  final VoidCallback? onTap;
  final String? matchedTitle;
  final VoidCallback? onWrongTitle;
  final bool loading;
  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.dns_outlined, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Source',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (matchedTitle case final title?)
                          Text(
                            'Matched as $title',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (loading)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    Text(
                      'Change',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (errorText case final error?)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        if (onWrongTitle != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: loading ? null : onWrongTitle,
              icon: const Icon(Icons.manage_search, size: 19),
              label: Text(
                matchedTitle == null ? 'Search title manually' : 'Change match',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}
