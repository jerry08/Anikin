import 'dart:async';

import 'package:anikin/core/app_theme.dart';
import 'package:anikin/services/preferences_service.dart';
import 'package:anikin/widgets/app_content_constraint.dart';
import 'package:anikin/widgets/app_dialogs.dart';
import 'package:anikin/widgets/app_sheet_action_bar.dart';
import 'package:anikin/widgets/media_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes share the Poppins type scale', () {
    for (final theme in [
      AppTheme.light(ThemeColorPalette.anikin),
      AppTheme.dark(ThemeColorPalette.anikin),
    ]) {
      final styles = <TextStyle?>[
        theme.textTheme.displayLarge,
        theme.textTheme.displayMedium,
        theme.textTheme.displaySmall,
        theme.textTheme.headlineLarge,
        theme.textTheme.headlineMedium,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
        theme.textTheme.titleSmall,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
        theme.textTheme.labelLarge,
        theme.textTheme.labelMedium,
        theme.textTheme.labelSmall,
      ];

      expect(styles.map((style) => style?.fontFamily).toSet(), {
        AppTypography.fontFamily,
      });
      expect(theme.textTheme.headlineSmall?.fontSize, 28);
      expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w700);
      expect(theme.textTheme.titleLarge?.fontSize, 20);
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.bodyMedium?.fontSize, 14);
      expect(theme.textTheme.bodyMedium?.height, 1.45);
      expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w600);
    }
  });

  test('light and dark themes share component geometry', () {
    for (final theme in [
      AppTheme.light(ThemeColorPalette.anikin),
      AppTheme.dark(ThemeColorPalette.anikin),
    ]) {
      final states = <WidgetState>{};
      final buttonStyles = [
        theme.textButtonTheme.style,
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.elevatedButtonTheme.style,
      ];

      for (final style in buttonStyles) {
        expect(
          style?.minimumSize?.resolve(states),
          const Size(64, AppLayout.minimumTouchTarget),
        );
        expect(style?.shape?.resolve(states), isA<StadiumBorder>());
      }

      expect(theme.dialogTheme.shape, AppShapes.dialog);
      expect(
        theme.dialogTheme.constraints,
        const BoxConstraints(
          minWidth: AppLayout.dialogMinWidth,
          maxWidth: AppLayout.dialogMaxWidth,
        ),
      );
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.bottomSheetTheme.shape, AppShapes.sheet);
      expect(theme.navigationBarTheme.backgroundColor, isNotNull);
      expect(theme.navigationRailTheme.backgroundColor, isNotNull);
    }
  });

  testWidgets('media type selector stays usable with large text', (
    tester,
  ) async {
    AppMediaType? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(ThemeColorPalette.anikin),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: MediaTypeSelector(
              value: AppMediaType.anime,
              appearance: MediaTypeSelectorAppearance.glass,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(MediaTypeSelector)).height,
      greaterThanOrEqualTo(46),
    );
    final outline = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('media-type-selector-outline')),
    );
    final outlineDecoration = outline.decoration as BoxDecoration;
    final segmentedButton = tester.widget<SegmentedButton<AppMediaType>>(
      find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<AppMediaType>,
      ),
    );
    expect(
      segmentedButton.style?.tapTargetSize,
      MaterialTapTargetSize.shrinkWrap,
    );
    expect(segmentedButton.style?.visualDensity, VisualDensity.standard);
    final selectedShape =
        segmentedButton.style?.shape?.resolve({WidgetState.selected})
            as RoundedRectangleBorder?;
    expect(selectedShape?.borderRadius, outlineDecoration.borderRadius);

    await tester.tap(find.text('Manga'));
    await tester.pumpAndSettle();

    expect(selected, AppMediaType.manga);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmation dialog actions match and mark destructive action', (
    tester,
  ) async {
    final theme = AppTheme.light(ThemeColorPalette.anikin);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => unawaited(
                showAppConfirmDialog(
                  context,
                  title: 'Remove item?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Remove',
                  destructive: true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancel = find.widgetWithText(TextButton, 'Cancel');
    final remove = find.widgetWithText(TextButton, 'Remove');
    expect(cancel, findsOneWidget);
    expect(remove, findsOneWidget);
    expect(
      tester.getSize(cancel).height,
      greaterThanOrEqualTo(AppLayout.minimumTouchTarget),
    );
    expect(tester.getSize(remove).height, tester.getSize(cancel).height);

    final destructiveButton = tester.widget<TextButton>(remove);
    expect(
      destructiveButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      theme.colorScheme.error,
    );
  });

  testWidgets('sheet actions reflow at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(ThemeColorPalette.anikin),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppSheetActionBar(
              children: [
                TextButton(onPressed: () {}, child: const Text('Reset')),
                TextButton(onPressed: () {}, child: const Text('Cancel')),
                FilledButton(onPressed: () {}, child: const Text('Apply')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('content constraint caps wide layouts', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const childKey = ValueKey('constrained-child');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppContentConstraint(
            maxWidth: AppLayout.maxReadableWidth,
            child: ColoredBox(key: childKey, color: Colors.red),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(childKey)).width,
      AppLayout.maxReadableWidth,
    );
  });
}
