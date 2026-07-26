import 'dart:convert';
import 'dart:io';

import 'package:anikin/core/platform_capabilities.dart';
import 'package:anikin/data/app_database.dart';
import 'package:anikin/models/anilist_media.dart';
import 'package:anikin/models/anilist_media_details.dart';
import 'package:anikin/models/anilist_person_details.dart';
import 'package:anikin/models/juro_models.dart';
import 'package:anikin/services/anilist_service.dart';
import 'package:anikin/services/backup_service.dart';
import 'package:anikin/services/community_timestamp_service.dart';
import 'package:anikin/services/juro_service.dart';
import 'package:anikin/services/lnreader_plugin_service.dart';
import 'package:anikin/services/local_notification_service.dart';
import 'package:anikin/services/notification_refresh_service.dart';
import 'package:anikin/services/notification_subscription_service.dart';
import 'package:anikin/services/novel_library_service.dart';
import 'package:anikin/services/preferences_service.dart';
import 'package:anikin/services/search_history_service.dart';
import 'package:anikin/services/source_health_service.dart';
import 'package:anikin/widgets/rich_media_details.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'search history is case-insensitive and ordered by recent use',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final history = SearchHistoryService(database);

      await history.record('anime', 'Frieren');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await history.record('anime', 'Dandadan');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await history.record('anime', 'frieren');

      expect(await history.recent('anime'), ['frieren', 'Dandadan']);
    },
  );

  test('source health ranks a recent success over a failure', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final health = SourceHealthService(database);
    const slowFailure = SourceProvider(key: 'failed', name: 'Failed');
    const success = SourceProvider(key: 'healthy', name: 'Healthy');

    await health.recordFailure(
      slowFailure.key,
      StateError('offline'),
      const Duration(seconds: 2),
    );
    await health.recordSuccess(success.key, const Duration(milliseconds: 200));

    expect(
      (await health.rank([slowFailure, success])).map((item) => item.key),
      ['healthy', 'failed'],
    );
  });

  test('community timestamps validate and label AniSkip intervals', () async {
    final service = CommunityTimestampService(
      client: MockClient((request) async {
        expect(request.url.host, 'api.aniskip.com');
        expect(request.url.queryParameters['episodeLength'], '1440');
        return http.Response(
          jsonEncode({
            'found': true,
            'results': [
              {
                'skipId': 'opening',
                'skipType': 'op',
                'interval': {'startTime': 12.5, 'endTime': 102.25},
              },
              {
                'skipId': 'invalid',
                'skipType': 'ed',
                'interval': {'startTime': 1300, 'endTime': 2000},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(service.dispose);

    final intervals = await service.getSkipIntervals(
      malId: 52991,
      episodeNumber: 1,
      episodeDuration: const Duration(minutes: 24),
    );

    expect(intervals, hasLength(1));
    expect(intervals.single.label, 'Skip opening');
    expect(intervals.single.start, const Duration(milliseconds: 12500));
    expect(intervals.single.contains(const Duration(seconds: 30)), isTrue);
  });

  test(
    'TXT novel imports chapters, saves progress, and removes owned files',
    () async {
      final root = await Directory.systemTemp.createTemp('anikin-novel-test-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final library = NovelLibraryService(
        database,
        rootDirectoryProvider: () async => root,
      );
      final sourceFile = File(
        '${root.path}${Platform.pathSeparator}Test_Book.txt',
      );
      await sourceFile.writeAsString(
        'Chapter 1\nThis is the opening chapter with enough readable text.\n'
        'It continues for another sentence.\n\n'
        'Chapter 2\nThis is the second chapter and its own content.',
      );
      final source = XFile(sourceFile.path);

      final book = await library.importFile(source);
      final chapters = await library.chapters(book.id);
      expect(book.title, 'Test Book');
      expect(chapters.map((item) => item.title), ['Chapter 1', 'Chapter 2']);
      expect(
        await library.readChapter(chapters.first),
        contains('opening chapter'),
      );

      await library.saveProgress(chapters.first.id, 0.42);
      expect(
        (await library.chapters(book.id)).first.progress,
        closeTo(0.42, 0.001),
      );
      await library.removeBook(book);
      expect(await library.books(), isEmpty);
      expect(
        await Directory(File(book.localPath!).parent.path).exists(),
        isFalse,
      );
    },
  );

  test(
    'encrypted backups omit credentials and merge portable records',
    () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 1,
        'player.watchedEpisodes': '{"episode":{"watchedPercentage":35}}',
        'tracking.account.anilist': 'do-not-export',
        'downloads.episodes': ['device-specific-path'],
      });
      final preferences = PreferencesService();
      await preferences.load();
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.notificationSubscriptions)
          .insert(
            NotificationSubscriptionsCompanion.insert(
              id: 'manual:anime:1',
              mediaId: 1,
              mediaType: 'anime',
              origin: 'manual',
              mediaTitle: const Value('Backup Show'),
              updatedAt: DateTime(2026, 1, 1),
            ),
          );
      final backup = BackupService(
        database: database,
        preferences: preferences,
        keyDerivationIterations: 10000,
      );

      final bytes = await backup.create('correct horse battery staple');
      final envelopeText = utf8.decode(bytes);
      expect(envelopeText, isNot(contains('Backup Show')));
      expect(envelopeText, isNot(contains('do-not-export')));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', 0);
      await prefs.setString('tracking.account.anilist', 'current-credential');
      await database.delete(database.notificationSubscriptions).go();
      final restored = await backup.restore(
        bytes,
        'correct horse battery staple',
      );

      expect(restored.records, 1);
      expect(prefs.getInt('themeMode'), 1);
      expect(prefs.getString('tracking.account.anilist'), 'current-credential');
      expect(
        await database.select(database.notificationSubscriptions).get(),
        hasLength(1),
      );
      await expectLater(
        backup.restore(bytes, 'wrong password'),
        throwsA(isA<BackupException>()),
      );
    },
  );

  test(
    'release refresh establishes a baseline before notifying new episodes',
    () async {
      SharedPreferences.setMockInitialValues({'notificationsEnabled': true});
      final preferences = PreferencesService();
      await preferences.load();
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.notificationSubscriptions)
          .insert(
            NotificationSubscriptionsCompanion.insert(
              id: 'manual:anime:42',
              mediaId: 42,
              mediaType: 'anime',
              origin: 'manual',
              mediaTitle: const Value('Release Test'),
              sourceKey: const Value('test-source'),
              providerItemId: const Value('show-42'),
              updatedAt: DateTime.now(),
            ),
          );
      final juro = _ReleaseJuroService([
        const AnimeEpisode(id: '1', number: 1),
        const AnimeEpisode(id: '2', number: 2),
      ]);
      final notifications = _RecordingNotifications();
      final aniList = _ReleaseAniListService(nextEpisode: 3);
      final refresh = NotificationRefreshService(
        database: database,
        aniListService: aniList,
        juroService: juro,
        localNotifications: notifications,
        preferences: preferences,
      );

      await refresh.refresh();
      expect(notifications.shown, isEmpty);
      expect(notifications.scheduled, isNotEmpty);
      expect(
        (await database.select(database.notificationSubscriptions).getSingle())
            .lastEpisode,
        2,
      );

      juro.episodes = [
        ...juro.episodes,
        const AnimeEpisode(id: '3', number: 3),
      ];
      aniList.nextEpisode = 4;
      await refresh.refresh();

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.body, contains('Episode 3'));
      expect(
        await database.select(database.appNotifications).get(),
        hasLength(1),
      );
    },
  );

  test('disabling one AniList source only unsyncs that origin', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final subscriptions = NotificationSubscriptionService(database);
    for (final origin in ['manual', 'anilist_current', 'anilist_planning']) {
      await database
          .into(database.notificationSubscriptions)
          .insert(
            NotificationSubscriptionsCompanion.insert(
              id: '$origin:anime:7',
              mediaId: 7,
              mediaType: 'anime',
              origin: origin,
              mediaTitle: const Value('Origin Test'),
              updatedAt: DateTime.now(),
            ),
          );
    }

    await subscriptions.clearOrigin(
      NotificationSubscriptionOrigin.aniListCurrent,
    );

    expect((await subscriptions.all()).map((item) => item.origin).toSet(), {
      'manual',
      'anilist_planning',
    });
  });

  test('AniList character details include biography and known media', () async {
    final service = AniListService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['query'], contains('Character(id: \$id)'));
        return http.Response(
          jsonEncode({
            'data': {
              'Character': {
                'id': 9,
                'name': {
                  'full': 'Test Character',
                  'native': 'テスト',
                  'alternative': ['Tester'],
                },
                'image': {'large': null},
                'description': 'A <b>useful</b> biography.',
                'gender': 'Female',
                'age': '18',
                'dateOfBirth': {'year': 2008, 'month': 2, 'day': 3},
                'favourites': 1200,
                'siteUrl': 'https://anilist.co/character/9',
                'media': {
                  'nodes': [
                    {
                      'id': 10,
                      'type': 'ANIME',
                      'title': {'english': 'Known Show'},
                      'coverImage': {},
                      'genres': [],
                      'isAdult': false,
                    },
                  ],
                },
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final details = await service.getPersonDetails(
      id: 9,
      kind: AniListPersonKind.character,
    );

    expect(details.name, 'Test Character');
    expect(details.description, 'A useful biography.');
    expect(details.dateOfBirth, 'Feb 3 2008');
    expect(details.knownFor.single.displayTitle, 'Known Show');
  });

  testWidgets('character cards expose an in-app click action', (tester) async {
    AniListPersonCredit? selectedPerson;
    AniListPersonKind? selectedKind;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RichMediaDetailsPanel(
              details: AniListMediaDetails(
                media: const AniListMedia(
                  id: 1,
                  title: MediaTitle(english: 'Test'),
                  cover: MediaCover(),
                ),
                characters: const [
                  AniListPersonCredit(
                    id: 2,
                    name: 'Clickable Character',
                    role: 'Main',
                  ),
                ],
              ),
              onMediaTap: (_) {},
              onPersonTap: (person, kind) {
                selectedPerson = person;
                selectedKind = kind;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Clickable Character'));
    await tester.pump();

    expect(selectedPerson?.id, 2);
    expect(selectedKind, AniListPersonKind.character);
  });

  test(
    'LNReader plugin boundary validates indexes and owns installed files',
    () async {
      final root = await Directory.systemTemp.createTemp('anikin-plugin-test-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final service = LnReaderPluginService(
        capabilities: const PlatformCapabilities(
          platform: TargetPlatform.android,
        ),
        directoryProvider: () async => root,
        client: MockClient((request) async {
          return http.Response('globalThis.plugin = true;', 200);
        }),
      );
      addTearDown(service.dispose);
      final plugins = LnReaderPluginService.parseIndex(
        jsonEncode([
          {
            'id': '../unsafe',
            'name': 'Unsafe',
            'lang': 'en',
            'version': '1.0.0',
            'url': 'https://example.com/unsafe.js',
          },
          {
            'id': 'safe-plugin',
            'name': 'Safe plugin',
            'lang': 'en',
            'version': '1.0.0',
            'url': 'https://example.com/plugin.js',
          },
        ]),
      );
      expect(plugins, hasLength(1));

      await service.install(plugins.single);
      expect(await service.installed(), hasLength(1));
      expect(await service.installedScript('safe-plugin'), contains('plugin'));
      await service.uninstall('safe-plugin');
      expect(await service.installed(), isEmpty);
    },
  );
}

class _ReleaseJuroService extends JuroService {
  _ReleaseJuroService(this.episodes);

  List<AnimeEpisode> episodes;

  @override
  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async => episodes;
}

class _ReleaseAniListService extends AniListService {
  _ReleaseAniListService({required this.nextEpisode});

  int nextEpisode;

  @override
  Future<AniListMediaDetails> getMediaDetails({
    required int id,
    required AniListMediaType mediaType,
  }) async => AniListMediaDetails(
    media: AniListMedia(
      id: id,
      title: const MediaTitle(english: 'Release Test'),
      cover: const MediaCover(),
      mediaType: mediaType.graphqlName,
    ),
    nextAiringEpisode: nextEpisode,
    nextAiringAt: DateTime.now().add(const Duration(hours: 2)),
  );
}

class _RecordingNotifications extends LocalNotificationService {
  final List<({int id, String title, String body, String? payload})> shown = [];
  final List<({int id, String title, String body, DateTime when})> scheduled =
      [];

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    scheduled.add((id: id, title: title, body: body, when: when));
  }
}
