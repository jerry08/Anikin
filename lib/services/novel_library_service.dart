import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';

class NovelLibraryService extends ChangeNotifier {
  NovelLibraryService(
    this._database, {
    @visibleForTesting Future<Directory> Function()? rootDirectoryProvider,
  }) : _rootDirectoryProvider = rootDirectoryProvider;

  final AppDatabase _database;
  final Future<Directory> Function()? _rootDirectoryProvider;

  Future<List<NovelLibraryEntry>> books() {
    return (_database.select(
      _database.novelLibraryEntries,
    )..orderBy([(entry) => OrderingTerm.desc(entry.updatedAt)])).get();
  }

  Future<List<NovelChapterEntry>> chapters(String novelId) {
    return (_database.select(_database.novelChapterEntries)
          ..where((entry) => entry.novelId.equals(novelId))
          ..orderBy([(entry) => OrderingTerm.asc(entry.id)]))
        .get();
  }

  Future<NovelLibraryEntry> importFile(XFile source) async {
    final length = await source.length();
    if (length > 100 * 1024 * 1024) {
      throw const NovelImportException('Novel files must be under 100 MB');
    }
    final extension = _extension(source.name);
    if (extension != 'txt' && extension != 'epub') {
      throw const NovelImportException('Choose a TXT or EPUB file');
    }
    final bytes = await source.readAsBytes();
    final parsed = extension == 'epub'
        ? _parseEpub(bytes, source.name)
        : _parseText(bytes, source.name);
    if (parsed.chapters.isEmpty) {
      throw const NovelImportException('No readable chapters were found');
    }

    final root = await _rootDirectory();
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final bookDirectory = Directory('${root.path}${Platform.pathSeparator}$id');
    await bookDirectory.create(recursive: true);
    final originalPath =
        '${bookDirectory.path}${Platform.pathSeparator}original.$extension';
    await File(originalPath).writeAsBytes(bytes, flush: true);

    final now = DateTime.now();
    final book = NovelLibraryEntry(
      id: id,
      aniListId: null,
      title: parsed.title,
      author: parsed.author,
      coverUrl: null,
      providerKey: 'local',
      providerItemId: null,
      localPath: originalPath,
      updatedAt: now,
    );
    try {
      await _database.transaction(() async {
        await _database.into(_database.novelLibraryEntries).insert(book);
        for (var index = 0; index < parsed.chapters.length; index++) {
          final parsedChapter = parsed.chapters[index];
          final chapterId = '$id:${index.toString().padLeft(6, '0')}';
          final chapterPath =
              '${bookDirectory.path}${Platform.pathSeparator}${index.toString().padLeft(6, '0')}.txt';
          await File(
            chapterPath,
          ).writeAsString(parsedChapter.content, flush: true);
          await _database
              .into(_database.novelChapterEntries)
              .insert(
                NovelChapterEntriesCompanion.insert(
                  id: chapterId,
                  novelId: id,
                  title: parsedChapter.title,
                  chapterNumber: Value('${index + 1}'),
                  localPath: Value(chapterPath),
                  updatedAt: now,
                ),
              );
        }
      });
    } catch (_) {
      if (_isOwnedPath(root, bookDirectory.path)) {
        await bookDirectory.delete(recursive: true);
      }
      rethrow;
    }
    notifyListeners();
    return book;
  }

  Future<String> readChapter(NovelChapterEntry chapter) async {
    final path = chapter.localPath;
    if (path == null) {
      throw const NovelImportException('Chapter content is unavailable');
    }
    final root = await _rootDirectory();
    if (!_isOwnedPath(root, path)) {
      throw const NovelImportException('Chapter path is outside the library');
    }
    return File(path).readAsString();
  }

  Future<void> saveProgress(String chapterId, double progress) async {
    await (_database.update(
      _database.novelChapterEntries,
    )..where((entry) => entry.id.equals(chapterId))).write(
      NovelChapterEntriesCompanion(
        progress: Value(progress.clamp(0, 1).toDouble()),
        readAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    notifyListeners();
  }

  Future<void> removeBook(NovelLibraryEntry book) async {
    final root = await _rootDirectory();
    final originalPath = book.localPath;
    Directory? bookDirectory;
    if (originalPath != null) {
      bookDirectory = File(originalPath).parent;
    }
    await _database.transaction(() async {
      await (_database.delete(
        _database.novelChapterEntries,
      )..where((entry) => entry.novelId.equals(book.id))).go();
      await (_database.delete(
        _database.novelLibraryEntries,
      )..where((entry) => entry.id.equals(book.id))).go();
    });
    if (bookDirectory != null &&
        _isOwnedPath(root, bookDirectory.path) &&
        await bookDirectory.exists()) {
      await bookDirectory.delete(recursive: true);
    }
    notifyListeners();
  }

  Future<Directory> _rootDirectory() async {
    final override = _rootDirectoryProvider;
    if (override != null) {
      final root = await override();
      await root.create(recursive: true);
      return root;
    }
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(
      '${documents.path}${Platform.pathSeparator}anikin${Platform.pathSeparator}novels',
    );
    await root.create(recursive: true);
    return root;
  }

  static bool _isOwnedPath(Directory root, String candidate) {
    final rootPath = root.absolute.path;
    final candidatePath = File(candidate).absolute.path;
    return candidatePath == rootPath ||
        candidatePath.startsWith('$rootPath${Platform.pathSeparator}');
  }

  static _ParsedNovel _parseText(Uint8List bytes, String fileName) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\r\n', '\n');
    final title = _fileTitle(fileName);
    final chapters = _splitTextChapters(text);
    return _ParsedNovel(title: title, chapters: chapters);
  }

  static _ParsedNovel _parseEpub(Uint8List bytes, String fileName) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String? title;
    String? author;
    final chapters = <_ParsedChapter>[];
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.toLowerCase();
      if (name.endsWith('.opf')) {
        final metadata = utf8.decode(file.content, allowMalformed: true);
        title ??= _firstTagText(metadata, 'dc:title');
        author ??= _firstTagText(metadata, 'dc:creator');
        continue;
      }
      if (!(name.endsWith('.xhtml') ||
          name.endsWith('.html') ||
          name.endsWith('.htm'))) {
        continue;
      }
      if (name.contains('nav') || name.contains('toc')) {
        continue;
      }
      final html = utf8.decode(file.content, allowMalformed: true);
      final content = _htmlToText(html);
      if (content.trim().length < 40) continue;
      final chapterTitle =
          _firstTagText(html, 'h1') ??
          _firstTagText(html, 'h2') ??
          _fileTitle(file.name);
      chapters.add(_ParsedChapter(title: chapterTitle, content: content));
    }
    chapters.sort((left, right) => left.title.compareTo(right.title));
    return _ParsedNovel(
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : _fileTitle(fileName),
      author: author?.trim(),
      chapters: chapters,
    );
  }

  static List<_ParsedChapter> _splitTextChapters(String text) {
    final heading = RegExp(
      r'^\s*(chapter\s+[\w\d .:-]+|prologue|epilogue|part\s+[\w\d .:-]+)\s*$',
      caseSensitive: false,
    );
    final chapters = <_ParsedChapter>[];
    var title = 'Full book';
    final buffer = StringBuffer();
    void commit() {
      final content = buffer.toString().trim();
      if (content.isNotEmpty) {
        chapters.add(_ParsedChapter(title: title, content: content));
      }
      buffer.clear();
    }

    for (final line in text.split('\n')) {
      if (heading.hasMatch(line)) {
        if (buffer.toString().trim().isNotEmpty) commit();
        title = line.trim();
      } else {
        buffer.writeln(line);
      }
    }
    commit();
    return chapters;
  }

  static String _htmlToText(String html) {
    return html
        .replaceAll(RegExp(r'<(br|hr)\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(p|div|h[1-6]|li|blockquote)>', caseSensitive: false),
          '\n\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String? _firstTagText(String source, String tag) {
    final escapedTag = RegExp.escape(tag);
    final match = RegExp(
      '<$escapedTag(?:\\s[^>]*)?>(.*?)</$escapedTag>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(source);
    if (match == null) return null;
    return _htmlToText(match.group(1) ?? '');
  }

  static String _extension(String name) {
    final index = name.lastIndexOf('.');
    return index < 0 ? '' : name.substring(index + 1).toLowerCase();
  }

  static String _fileTitle(String name) {
    final normalized = name.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final extensionIndex = fileName.lastIndexOf('.');
    return (extensionIndex > 0
            ? fileName.substring(0, extensionIndex)
            : fileName)
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();
  }
}

class NovelImportException implements Exception {
  const NovelImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ParsedNovel {
  const _ParsedNovel({
    required this.title,
    required this.chapters,
    this.author,
  });

  final String title;
  final String? author;
  final List<_ParsedChapter> chapters;
}

class _ParsedChapter {
  const _ParsedChapter({required this.title, required this.content});

  final String title;
  final String content;
}
