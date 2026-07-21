import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

enum MediaTypeSelectorAppearance { surface, glass }

class MediaTypeSelector extends StatelessWidget {
  const MediaTypeSelector({
    required this.value,
    required this.onChanged,
    this.appearance = MediaTypeSelectorAppearance.surface,
    super.key,
  });

  final AppMediaType value;
  final ValueChanged<AppMediaType> onChanged;
  final MediaTypeSelectorAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGlass = appearance == MediaTypeSelectorAppearance.glass;
    final selector = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass
            ? const Color(0x26000000)
            : colorScheme.surface.withAlpha(238),
        borderRadius: BorderRadius.circular(14),
        border: isGlass ? Border.all(color: const Color(0x26FFFFFF)) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SegmentedButton<AppMediaType>(
        segments: const [
          ButtonSegment(
            value: AppMediaType.anime,
            icon: Icon(Icons.live_tv_outlined),
            label: Text('Anime'),
          ),
          ButtonSegment(
            value: AppMediaType.manga,
            icon: Icon(Icons.menu_book_outlined),
            label: Text('Manga'),
          ),
        ],
        selected: {value},
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (isGlass) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xD9FFFFFF);
            }
            return states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (isGlass) {
              return states.contains(WidgetState.selected)
                  ? const Color(0x30FFFFFF)
                  : Colors.transparent;
            }
            return states.contains(WidgetState.selected)
                ? colorScheme.primaryContainer
                : Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (isGlass) {
              return BorderSide(
                color: states.contains(WidgetState.selected)
                    ? const Color(0x42FFFFFF)
                    : const Color(0x16FFFFFF),
              );
            }
            return BorderSide(color: colorScheme.outlineVariant);
          }),
        ),
        onSelectionChanged: (selection) {
          final selected = selection.single;
          if (selected != value) {
            onChanged(selected);
          }
        },
      ),
    );

    return Semantics(
      container: true,
      label: 'Media type',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: isGlass
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: selector,
                ),
              )
            : selector,
      ),
    );
  }
}
