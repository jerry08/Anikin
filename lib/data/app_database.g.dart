// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SchemaMetadataTable extends SchemaMetadata
    with TableInfo<$SchemaMetadataTable, SchemaMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchemaMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schema_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchemaMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SchemaMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchemaMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SchemaMetadataTable createAlias(String alias) {
    return $SchemaMetadataTable(attachedDatabase, alias);
  }
}

class SchemaMetadataData extends DataClass
    implements Insertable<SchemaMetadataData> {
  final String key;
  final String value;
  const SchemaMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SchemaMetadataCompanion toCompanion(bool nullToAbsent) {
    return SchemaMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SchemaMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchemaMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SchemaMetadataData copyWith({String? key, String? value}) =>
      SchemaMetadataData(key: key ?? this.key, value: value ?? this.value);
  SchemaMetadataData copyWithCompanion(SchemaMetadataCompanion data) {
    return SchemaMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchemaMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchemaMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SchemaMetadataCompanion extends UpdateCompanion<SchemaMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SchemaMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchemaMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SchemaMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchemaMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SchemaMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchemaMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryEntriesTable extends SearchHistoryEntries
    with TableInfo<$SearchHistoryEntriesTable, SearchHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedAtMeta = const VerificationMeta('usedAt');
  @override
  late final GeneratedColumn<DateTime> usedAt = GeneratedColumn<DateTime>(
    'used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, target, query, usedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('used_at')) {
      context.handle(
        _usedAtMeta,
        usedAt.isAcceptableOrUnknown(data['used_at']!, _usedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_usedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {target, query},
  ];
  @override
  SearchHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      usedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}used_at'],
      )!,
    );
  }

  @override
  $SearchHistoryEntriesTable createAlias(String alias) {
    return $SearchHistoryEntriesTable(attachedDatabase, alias);
  }
}

class SearchHistoryEntry extends DataClass
    implements Insertable<SearchHistoryEntry> {
  final int id;
  final String target;
  final String query;
  final DateTime usedAt;
  const SearchHistoryEntry({
    required this.id,
    required this.target,
    required this.query,
    required this.usedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target'] = Variable<String>(target);
    map['query'] = Variable<String>(query);
    map['used_at'] = Variable<DateTime>(usedAt);
    return map;
  }

  SearchHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryEntriesCompanion(
      id: Value(id),
      target: Value(target),
      query: Value(query),
      usedAt: Value(usedAt),
    );
  }

  factory SearchHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      target: serializer.fromJson<String>(json['target']),
      query: serializer.fromJson<String>(json['query']),
      usedAt: serializer.fromJson<DateTime>(json['usedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'target': serializer.toJson<String>(target),
      'query': serializer.toJson<String>(query),
      'usedAt': serializer.toJson<DateTime>(usedAt),
    };
  }

  SearchHistoryEntry copyWith({
    int? id,
    String? target,
    String? query,
    DateTime? usedAt,
  }) => SearchHistoryEntry(
    id: id ?? this.id,
    target: target ?? this.target,
    query: query ?? this.query,
    usedAt: usedAt ?? this.usedAt,
  );
  SearchHistoryEntry copyWithCompanion(SearchHistoryEntriesCompanion data) {
    return SearchHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      target: data.target.present ? data.target.value : this.target,
      query: data.query.present ? data.query.value : this.query,
      usedAt: data.usedAt.present ? data.usedAt.value : this.usedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryEntry(')
          ..write('id: $id, ')
          ..write('target: $target, ')
          ..write('query: $query, ')
          ..write('usedAt: $usedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, target, query, usedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryEntry &&
          other.id == this.id &&
          other.target == this.target &&
          other.query == this.query &&
          other.usedAt == this.usedAt);
}

class SearchHistoryEntriesCompanion
    extends UpdateCompanion<SearchHistoryEntry> {
  final Value<int> id;
  final Value<String> target;
  final Value<String> query;
  final Value<DateTime> usedAt;
  const SearchHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.target = const Value.absent(),
    this.query = const Value.absent(),
    this.usedAt = const Value.absent(),
  });
  SearchHistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String target,
    required String query,
    required DateTime usedAt,
  }) : target = Value(target),
       query = Value(query),
       usedAt = Value(usedAt);
  static Insertable<SearchHistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? target,
    Expression<String>? query,
    Expression<DateTime>? usedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (target != null) 'target': target,
      if (query != null) 'query': query,
      if (usedAt != null) 'used_at': usedAt,
    });
  }

  SearchHistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? target,
    Value<String>? query,
    Value<DateTime>? usedAt,
  }) {
    return SearchHistoryEntriesCompanion(
      id: id ?? this.id,
      target: target ?? this.target,
      query: query ?? this.query,
      usedAt: usedAt ?? this.usedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (usedAt.present) {
      map['used_at'] = Variable<DateTime>(usedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('target: $target, ')
          ..write('query: $query, ')
          ..write('usedAt: $usedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedResponsesTable extends CachedResponses
    with TableInfo<$CachedResponsesTable, CachedResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storedAtMeta = const VerificationMeta(
    'storedAt',
  );
  @override
  late final GeneratedColumn<DateTime> storedAt = GeneratedColumn<DateTime>(
    'stored_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, body, etag, storedAt, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('stored_at')) {
      context.handle(
        _storedAtMeta,
        storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_storedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedResponse(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      storedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stored_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $CachedResponsesTable createAlias(String alias) {
    return $CachedResponsesTable(attachedDatabase, alias);
  }
}

class CachedResponse extends DataClass implements Insertable<CachedResponse> {
  final String key;
  final String body;
  final String? etag;
  final DateTime storedAt;
  final DateTime expiresAt;
  const CachedResponse({
    required this.key,
    required this.body,
    this.etag,
    required this.storedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['stored_at'] = Variable<DateTime>(storedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  CachedResponsesCompanion toCompanion(bool nullToAbsent) {
    return CachedResponsesCompanion(
      key: Value(key),
      body: Value(body),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      storedAt: Value(storedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory CachedResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedResponse(
      key: serializer.fromJson<String>(json['key']),
      body: serializer.fromJson<String>(json['body']),
      etag: serializer.fromJson<String?>(json['etag']),
      storedAt: serializer.fromJson<DateTime>(json['storedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'body': serializer.toJson<String>(body),
      'etag': serializer.toJson<String?>(etag),
      'storedAt': serializer.toJson<DateTime>(storedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  CachedResponse copyWith({
    String? key,
    String? body,
    Value<String?> etag = const Value.absent(),
    DateTime? storedAt,
    DateTime? expiresAt,
  }) => CachedResponse(
    key: key ?? this.key,
    body: body ?? this.body,
    etag: etag.present ? etag.value : this.etag,
    storedAt: storedAt ?? this.storedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  CachedResponse copyWithCompanion(CachedResponsesCompanion data) {
    return CachedResponse(
      key: data.key.present ? data.key.value : this.key,
      body: data.body.present ? data.body.value : this.body,
      etag: data.etag.present ? data.etag.value : this.etag,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponse(')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('etag: $etag, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, body, etag, storedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedResponse &&
          other.key == this.key &&
          other.body == this.body &&
          other.etag == this.etag &&
          other.storedAt == this.storedAt &&
          other.expiresAt == this.expiresAt);
}

class CachedResponsesCompanion extends UpdateCompanion<CachedResponse> {
  final Value<String> key;
  final Value<String> body;
  final Value<String?> etag;
  final Value<DateTime> storedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const CachedResponsesCompanion({
    this.key = const Value.absent(),
    this.body = const Value.absent(),
    this.etag = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedResponsesCompanion.insert({
    required String key,
    required String body,
    this.etag = const Value.absent(),
    required DateTime storedAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       body = Value(body),
       storedAt = Value(storedAt),
       expiresAt = Value(expiresAt);
  static Insertable<CachedResponse> custom({
    Expression<String>? key,
    Expression<String>? body,
    Expression<String>? etag,
    Expression<DateTime>? storedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (body != null) 'body': body,
      if (etag != null) 'etag': etag,
      if (storedAt != null) 'stored_at': storedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedResponsesCompanion copyWith({
    Value<String>? key,
    Value<String>? body,
    Value<String?>? etag,
    Value<DateTime>? storedAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return CachedResponsesCompanion(
      key: key ?? this.key,
      body: body ?? this.body,
      etag: etag ?? this.etag,
      storedAt: storedAt ?? this.storedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<DateTime>(storedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponsesCompanion(')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('etag: $etag, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SourceHealthEntriesTable extends SourceHealthEntries
    with TableInfo<$SourceHealthEntriesTable, SourceHealthEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceHealthEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _succeededMeta = const VerificationMeta(
    'succeeded',
  );
  @override
  late final GeneratedColumn<bool> succeeded = GeneratedColumn<bool>(
    'succeeded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("succeeded" IN (0, 1))',
    ),
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceKey,
    succeeded,
    latencyMs,
    lastError,
    checkedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_health_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceHealthEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('succeeded')) {
      context.handle(
        _succeededMeta,
        succeeded.isAcceptableOrUnknown(data['succeeded']!, _succeededMeta),
      );
    } else if (isInserting) {
      context.missing(_succeededMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceKey};
  @override
  SourceHealthEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceHealthEntry(
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      succeeded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}succeeded'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $SourceHealthEntriesTable createAlias(String alias) {
    return $SourceHealthEntriesTable(attachedDatabase, alias);
  }
}

class SourceHealthEntry extends DataClass
    implements Insertable<SourceHealthEntry> {
  final String sourceKey;
  final bool succeeded;
  final int? latencyMs;
  final String? lastError;
  final DateTime checkedAt;
  const SourceHealthEntry({
    required this.sourceKey,
    required this.succeeded,
    this.latencyMs,
    this.lastError,
    required this.checkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_key'] = Variable<String>(sourceKey);
    map['succeeded'] = Variable<bool>(succeeded);
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['checked_at'] = Variable<DateTime>(checkedAt);
    return map;
  }

  SourceHealthEntriesCompanion toCompanion(bool nullToAbsent) {
    return SourceHealthEntriesCompanion(
      sourceKey: Value(sourceKey),
      succeeded: Value(succeeded),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      checkedAt: Value(checkedAt),
    );
  }

  factory SourceHealthEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceHealthEntry(
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      succeeded: serializer.fromJson<bool>(json['succeeded']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceKey': serializer.toJson<String>(sourceKey),
      'succeeded': serializer.toJson<bool>(succeeded),
      'latencyMs': serializer.toJson<int?>(latencyMs),
      'lastError': serializer.toJson<String?>(lastError),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
    };
  }

  SourceHealthEntry copyWith({
    String? sourceKey,
    bool? succeeded,
    Value<int?> latencyMs = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? checkedAt,
  }) => SourceHealthEntry(
    sourceKey: sourceKey ?? this.sourceKey,
    succeeded: succeeded ?? this.succeeded,
    latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
    lastError: lastError.present ? lastError.value : this.lastError,
    checkedAt: checkedAt ?? this.checkedAt,
  );
  SourceHealthEntry copyWithCompanion(SourceHealthEntriesCompanion data) {
    return SourceHealthEntry(
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      succeeded: data.succeeded.present ? data.succeeded.value : this.succeeded,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceHealthEntry(')
          ..write('sourceKey: $sourceKey, ')
          ..write('succeeded: $succeeded, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('lastError: $lastError, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceKey, succeeded, latencyMs, lastError, checkedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceHealthEntry &&
          other.sourceKey == this.sourceKey &&
          other.succeeded == this.succeeded &&
          other.latencyMs == this.latencyMs &&
          other.lastError == this.lastError &&
          other.checkedAt == this.checkedAt);
}

class SourceHealthEntriesCompanion extends UpdateCompanion<SourceHealthEntry> {
  final Value<String> sourceKey;
  final Value<bool> succeeded;
  final Value<int?> latencyMs;
  final Value<String?> lastError;
  final Value<DateTime> checkedAt;
  final Value<int> rowid;
  const SourceHealthEntriesCompanion({
    this.sourceKey = const Value.absent(),
    this.succeeded = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.lastError = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceHealthEntriesCompanion.insert({
    required String sourceKey,
    required bool succeeded,
    this.latencyMs = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime checkedAt,
    this.rowid = const Value.absent(),
  }) : sourceKey = Value(sourceKey),
       succeeded = Value(succeeded),
       checkedAt = Value(checkedAt);
  static Insertable<SourceHealthEntry> custom({
    Expression<String>? sourceKey,
    Expression<bool>? succeeded,
    Expression<int>? latencyMs,
    Expression<String>? lastError,
    Expression<DateTime>? checkedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceKey != null) 'source_key': sourceKey,
      if (succeeded != null) 'succeeded': succeeded,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (lastError != null) 'last_error': lastError,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceHealthEntriesCompanion copyWith({
    Value<String>? sourceKey,
    Value<bool>? succeeded,
    Value<int?>? latencyMs,
    Value<String?>? lastError,
    Value<DateTime>? checkedAt,
    Value<int>? rowid,
  }) {
    return SourceHealthEntriesCompanion(
      sourceKey: sourceKey ?? this.sourceKey,
      succeeded: succeeded ?? this.succeeded,
      latencyMs: latencyMs ?? this.latencyMs,
      lastError: lastError ?? this.lastError,
      checkedAt: checkedAt ?? this.checkedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (succeeded.present) {
      map['succeeded'] = Variable<bool>(succeeded.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceHealthEntriesCompanion(')
          ..write('sourceKey: $sourceKey, ')
          ..write('succeeded: $succeeded, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('lastError: $lastError, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationSubscriptionsTable extends NotificationSubscriptions
    with TableInfo<$NotificationSubscriptionsTable, NotificationSubscription> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationSubscriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTitleMeta = const VerificationMeta(
    'mediaTitle',
  );
  @override
  late final GeneratedColumn<String> mediaTitle = GeneratedColumn<String>(
    'media_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerItemIdMeta = const VerificationMeta(
    'providerItemId',
  );
  @override
  late final GeneratedColumn<String> providerItemId = GeneratedColumn<String>(
    'provider_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notifyPremiereMeta = const VerificationMeta(
    'notifyPremiere',
  );
  @override
  late final GeneratedColumn<bool> notifyPremiere = GeneratedColumn<bool>(
    'notify_premiere',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_premiere" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notifyEpisodeMeta = const VerificationMeta(
    'notifyEpisode',
  );
  @override
  late final GeneratedColumn<bool> notifyEpisode = GeneratedColumn<bool>(
    'notify_episode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_episode" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notifyChapterMeta = const VerificationMeta(
    'notifyChapter',
  );
  @override
  late final GeneratedColumn<bool> notifyChapter = GeneratedColumn<bool>(
    'notify_chapter',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_chapter" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notifyAiringMeta = const VerificationMeta(
    'notifyAiring',
  );
  @override
  late final GeneratedColumn<bool> notifyAiring = GeneratedColumn<bool>(
    'notify_airing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_airing" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastEpisodeMeta = const VerificationMeta(
    'lastEpisode',
  );
  @override
  late final GeneratedColumn<double> lastEpisode = GeneratedColumn<double>(
    'last_episode',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChapterMeta = const VerificationMeta(
    'lastChapter',
  );
  @override
  late final GeneratedColumn<String> lastChapter = GeneratedColumn<String>(
    'last_chapter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAiringAtMeta = const VerificationMeta(
    'nextAiringAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAiringAt = GeneratedColumn<DateTime>(
    'next_airing_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mediaId,
    mediaType,
    origin,
    mediaTitle,
    coverUrl,
    sourceKey,
    providerItemId,
    enabled,
    notifyPremiere,
    notifyEpisode,
    notifyChapter,
    notifyAiring,
    lastEpisode,
    lastChapter,
    nextAiringAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_subscriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationSubscription> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('media_title')) {
      context.handle(
        _mediaTitleMeta,
        mediaTitle.isAcceptableOrUnknown(data['media_title']!, _mediaTitleMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    }
    if (data.containsKey('provider_item_id')) {
      context.handle(
        _providerItemIdMeta,
        providerItemId.isAcceptableOrUnknown(
          data['provider_item_id']!,
          _providerItemIdMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('notify_premiere')) {
      context.handle(
        _notifyPremiereMeta,
        notifyPremiere.isAcceptableOrUnknown(
          data['notify_premiere']!,
          _notifyPremiereMeta,
        ),
      );
    }
    if (data.containsKey('notify_episode')) {
      context.handle(
        _notifyEpisodeMeta,
        notifyEpisode.isAcceptableOrUnknown(
          data['notify_episode']!,
          _notifyEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('notify_chapter')) {
      context.handle(
        _notifyChapterMeta,
        notifyChapter.isAcceptableOrUnknown(
          data['notify_chapter']!,
          _notifyChapterMeta,
        ),
      );
    }
    if (data.containsKey('notify_airing')) {
      context.handle(
        _notifyAiringMeta,
        notifyAiring.isAcceptableOrUnknown(
          data['notify_airing']!,
          _notifyAiringMeta,
        ),
      );
    }
    if (data.containsKey('last_episode')) {
      context.handle(
        _lastEpisodeMeta,
        lastEpisode.isAcceptableOrUnknown(
          data['last_episode']!,
          _lastEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('last_chapter')) {
      context.handle(
        _lastChapterMeta,
        lastChapter.isAcceptableOrUnknown(
          data['last_chapter']!,
          _lastChapterMeta,
        ),
      );
    }
    if (data.containsKey('next_airing_at')) {
      context.handle(
        _nextAiringAtMeta,
        nextAiringAt.isAcceptableOrUnknown(
          data['next_airing_at']!,
          _nextAiringAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationSubscription map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationSubscription(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_id'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      mediaTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_title'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      ),
      providerItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_item_id'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      notifyPremiere: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_premiere'],
      )!,
      notifyEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_episode'],
      )!,
      notifyChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_chapter'],
      )!,
      notifyAiring: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_airing'],
      )!,
      lastEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_episode'],
      ),
      lastChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_chapter'],
      ),
      nextAiringAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_airing_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotificationSubscriptionsTable createAlias(String alias) {
    return $NotificationSubscriptionsTable(attachedDatabase, alias);
  }
}

class NotificationSubscription extends DataClass
    implements Insertable<NotificationSubscription> {
  final String id;
  final int mediaId;
  final String mediaType;
  final String origin;
  final String mediaTitle;
  final String? coverUrl;
  final String? sourceKey;
  final String? providerItemId;
  final bool enabled;
  final bool notifyPremiere;
  final bool notifyEpisode;
  final bool notifyChapter;
  final bool notifyAiring;
  final double? lastEpisode;
  final String? lastChapter;
  final DateTime? nextAiringAt;
  final DateTime updatedAt;
  const NotificationSubscription({
    required this.id,
    required this.mediaId,
    required this.mediaType,
    required this.origin,
    required this.mediaTitle,
    this.coverUrl,
    this.sourceKey,
    this.providerItemId,
    required this.enabled,
    required this.notifyPremiere,
    required this.notifyEpisode,
    required this.notifyChapter,
    required this.notifyAiring,
    this.lastEpisode,
    this.lastChapter,
    this.nextAiringAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['media_id'] = Variable<int>(mediaId);
    map['media_type'] = Variable<String>(mediaType);
    map['origin'] = Variable<String>(origin);
    map['media_title'] = Variable<String>(mediaTitle);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    if (!nullToAbsent || providerItemId != null) {
      map['provider_item_id'] = Variable<String>(providerItemId);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['notify_premiere'] = Variable<bool>(notifyPremiere);
    map['notify_episode'] = Variable<bool>(notifyEpisode);
    map['notify_chapter'] = Variable<bool>(notifyChapter);
    map['notify_airing'] = Variable<bool>(notifyAiring);
    if (!nullToAbsent || lastEpisode != null) {
      map['last_episode'] = Variable<double>(lastEpisode);
    }
    if (!nullToAbsent || lastChapter != null) {
      map['last_chapter'] = Variable<String>(lastChapter);
    }
    if (!nullToAbsent || nextAiringAt != null) {
      map['next_airing_at'] = Variable<DateTime>(nextAiringAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotificationSubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return NotificationSubscriptionsCompanion(
      id: Value(id),
      mediaId: Value(mediaId),
      mediaType: Value(mediaType),
      origin: Value(origin),
      mediaTitle: Value(mediaTitle),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      sourceKey: sourceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceKey),
      providerItemId: providerItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerItemId),
      enabled: Value(enabled),
      notifyPremiere: Value(notifyPremiere),
      notifyEpisode: Value(notifyEpisode),
      notifyChapter: Value(notifyChapter),
      notifyAiring: Value(notifyAiring),
      lastEpisode: lastEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEpisode),
      lastChapter: lastChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(lastChapter),
      nextAiringAt: nextAiringAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAiringAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NotificationSubscription.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationSubscription(
      id: serializer.fromJson<String>(json['id']),
      mediaId: serializer.fromJson<int>(json['mediaId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      origin: serializer.fromJson<String>(json['origin']),
      mediaTitle: serializer.fromJson<String>(json['mediaTitle']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
      providerItemId: serializer.fromJson<String?>(json['providerItemId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      notifyPremiere: serializer.fromJson<bool>(json['notifyPremiere']),
      notifyEpisode: serializer.fromJson<bool>(json['notifyEpisode']),
      notifyChapter: serializer.fromJson<bool>(json['notifyChapter']),
      notifyAiring: serializer.fromJson<bool>(json['notifyAiring']),
      lastEpisode: serializer.fromJson<double?>(json['lastEpisode']),
      lastChapter: serializer.fromJson<String?>(json['lastChapter']),
      nextAiringAt: serializer.fromJson<DateTime?>(json['nextAiringAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mediaId': serializer.toJson<int>(mediaId),
      'mediaType': serializer.toJson<String>(mediaType),
      'origin': serializer.toJson<String>(origin),
      'mediaTitle': serializer.toJson<String>(mediaTitle),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'sourceKey': serializer.toJson<String?>(sourceKey),
      'providerItemId': serializer.toJson<String?>(providerItemId),
      'enabled': serializer.toJson<bool>(enabled),
      'notifyPremiere': serializer.toJson<bool>(notifyPremiere),
      'notifyEpisode': serializer.toJson<bool>(notifyEpisode),
      'notifyChapter': serializer.toJson<bool>(notifyChapter),
      'notifyAiring': serializer.toJson<bool>(notifyAiring),
      'lastEpisode': serializer.toJson<double?>(lastEpisode),
      'lastChapter': serializer.toJson<String?>(lastChapter),
      'nextAiringAt': serializer.toJson<DateTime?>(nextAiringAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NotificationSubscription copyWith({
    String? id,
    int? mediaId,
    String? mediaType,
    String? origin,
    String? mediaTitle,
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> sourceKey = const Value.absent(),
    Value<String?> providerItemId = const Value.absent(),
    bool? enabled,
    bool? notifyPremiere,
    bool? notifyEpisode,
    bool? notifyChapter,
    bool? notifyAiring,
    Value<double?> lastEpisode = const Value.absent(),
    Value<String?> lastChapter = const Value.absent(),
    Value<DateTime?> nextAiringAt = const Value.absent(),
    DateTime? updatedAt,
  }) => NotificationSubscription(
    id: id ?? this.id,
    mediaId: mediaId ?? this.mediaId,
    mediaType: mediaType ?? this.mediaType,
    origin: origin ?? this.origin,
    mediaTitle: mediaTitle ?? this.mediaTitle,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
    providerItemId: providerItemId.present
        ? providerItemId.value
        : this.providerItemId,
    enabled: enabled ?? this.enabled,
    notifyPremiere: notifyPremiere ?? this.notifyPremiere,
    notifyEpisode: notifyEpisode ?? this.notifyEpisode,
    notifyChapter: notifyChapter ?? this.notifyChapter,
    notifyAiring: notifyAiring ?? this.notifyAiring,
    lastEpisode: lastEpisode.present ? lastEpisode.value : this.lastEpisode,
    lastChapter: lastChapter.present ? lastChapter.value : this.lastChapter,
    nextAiringAt: nextAiringAt.present ? nextAiringAt.value : this.nextAiringAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NotificationSubscription copyWithCompanion(
    NotificationSubscriptionsCompanion data,
  ) {
    return NotificationSubscription(
      id: data.id.present ? data.id.value : this.id,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      origin: data.origin.present ? data.origin.value : this.origin,
      mediaTitle: data.mediaTitle.present
          ? data.mediaTitle.value
          : this.mediaTitle,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      providerItemId: data.providerItemId.present
          ? data.providerItemId.value
          : this.providerItemId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      notifyPremiere: data.notifyPremiere.present
          ? data.notifyPremiere.value
          : this.notifyPremiere,
      notifyEpisode: data.notifyEpisode.present
          ? data.notifyEpisode.value
          : this.notifyEpisode,
      notifyChapter: data.notifyChapter.present
          ? data.notifyChapter.value
          : this.notifyChapter,
      notifyAiring: data.notifyAiring.present
          ? data.notifyAiring.value
          : this.notifyAiring,
      lastEpisode: data.lastEpisode.present
          ? data.lastEpisode.value
          : this.lastEpisode,
      lastChapter: data.lastChapter.present
          ? data.lastChapter.value
          : this.lastChapter,
      nextAiringAt: data.nextAiringAt.present
          ? data.nextAiringAt.value
          : this.nextAiringAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSubscription(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('mediaType: $mediaType, ')
          ..write('origin: $origin, ')
          ..write('mediaTitle: $mediaTitle, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('providerItemId: $providerItemId, ')
          ..write('enabled: $enabled, ')
          ..write('notifyPremiere: $notifyPremiere, ')
          ..write('notifyEpisode: $notifyEpisode, ')
          ..write('notifyChapter: $notifyChapter, ')
          ..write('notifyAiring: $notifyAiring, ')
          ..write('lastEpisode: $lastEpisode, ')
          ..write('lastChapter: $lastChapter, ')
          ..write('nextAiringAt: $nextAiringAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mediaId,
    mediaType,
    origin,
    mediaTitle,
    coverUrl,
    sourceKey,
    providerItemId,
    enabled,
    notifyPremiere,
    notifyEpisode,
    notifyChapter,
    notifyAiring,
    lastEpisode,
    lastChapter,
    nextAiringAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationSubscription &&
          other.id == this.id &&
          other.mediaId == this.mediaId &&
          other.mediaType == this.mediaType &&
          other.origin == this.origin &&
          other.mediaTitle == this.mediaTitle &&
          other.coverUrl == this.coverUrl &&
          other.sourceKey == this.sourceKey &&
          other.providerItemId == this.providerItemId &&
          other.enabled == this.enabled &&
          other.notifyPremiere == this.notifyPremiere &&
          other.notifyEpisode == this.notifyEpisode &&
          other.notifyChapter == this.notifyChapter &&
          other.notifyAiring == this.notifyAiring &&
          other.lastEpisode == this.lastEpisode &&
          other.lastChapter == this.lastChapter &&
          other.nextAiringAt == this.nextAiringAt &&
          other.updatedAt == this.updatedAt);
}

class NotificationSubscriptionsCompanion
    extends UpdateCompanion<NotificationSubscription> {
  final Value<String> id;
  final Value<int> mediaId;
  final Value<String> mediaType;
  final Value<String> origin;
  final Value<String> mediaTitle;
  final Value<String?> coverUrl;
  final Value<String?> sourceKey;
  final Value<String?> providerItemId;
  final Value<bool> enabled;
  final Value<bool> notifyPremiere;
  final Value<bool> notifyEpisode;
  final Value<bool> notifyChapter;
  final Value<bool> notifyAiring;
  final Value<double?> lastEpisode;
  final Value<String?> lastChapter;
  final Value<DateTime?> nextAiringAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotificationSubscriptionsCompanion({
    this.id = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.origin = const Value.absent(),
    this.mediaTitle = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.providerItemId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notifyPremiere = const Value.absent(),
    this.notifyEpisode = const Value.absent(),
    this.notifyChapter = const Value.absent(),
    this.notifyAiring = const Value.absent(),
    this.lastEpisode = const Value.absent(),
    this.lastChapter = const Value.absent(),
    this.nextAiringAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationSubscriptionsCompanion.insert({
    required String id,
    required int mediaId,
    required String mediaType,
    required String origin,
    this.mediaTitle = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.providerItemId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notifyPremiere = const Value.absent(),
    this.notifyEpisode = const Value.absent(),
    this.notifyChapter = const Value.absent(),
    this.notifyAiring = const Value.absent(),
    this.lastEpisode = const Value.absent(),
    this.lastChapter = const Value.absent(),
    this.nextAiringAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mediaId = Value(mediaId),
       mediaType = Value(mediaType),
       origin = Value(origin),
       updatedAt = Value(updatedAt);
  static Insertable<NotificationSubscription> custom({
    Expression<String>? id,
    Expression<int>? mediaId,
    Expression<String>? mediaType,
    Expression<String>? origin,
    Expression<String>? mediaTitle,
    Expression<String>? coverUrl,
    Expression<String>? sourceKey,
    Expression<String>? providerItemId,
    Expression<bool>? enabled,
    Expression<bool>? notifyPremiere,
    Expression<bool>? notifyEpisode,
    Expression<bool>? notifyChapter,
    Expression<bool>? notifyAiring,
    Expression<double>? lastEpisode,
    Expression<String>? lastChapter,
    Expression<DateTime>? nextAiringAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaId != null) 'media_id': mediaId,
      if (mediaType != null) 'media_type': mediaType,
      if (origin != null) 'origin': origin,
      if (mediaTitle != null) 'media_title': mediaTitle,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (sourceKey != null) 'source_key': sourceKey,
      if (providerItemId != null) 'provider_item_id': providerItemId,
      if (enabled != null) 'enabled': enabled,
      if (notifyPremiere != null) 'notify_premiere': notifyPremiere,
      if (notifyEpisode != null) 'notify_episode': notifyEpisode,
      if (notifyChapter != null) 'notify_chapter': notifyChapter,
      if (notifyAiring != null) 'notify_airing': notifyAiring,
      if (lastEpisode != null) 'last_episode': lastEpisode,
      if (lastChapter != null) 'last_chapter': lastChapter,
      if (nextAiringAt != null) 'next_airing_at': nextAiringAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationSubscriptionsCompanion copyWith({
    Value<String>? id,
    Value<int>? mediaId,
    Value<String>? mediaType,
    Value<String>? origin,
    Value<String>? mediaTitle,
    Value<String?>? coverUrl,
    Value<String?>? sourceKey,
    Value<String?>? providerItemId,
    Value<bool>? enabled,
    Value<bool>? notifyPremiere,
    Value<bool>? notifyEpisode,
    Value<bool>? notifyChapter,
    Value<bool>? notifyAiring,
    Value<double?>? lastEpisode,
    Value<String?>? lastChapter,
    Value<DateTime?>? nextAiringAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotificationSubscriptionsCompanion(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      mediaType: mediaType ?? this.mediaType,
      origin: origin ?? this.origin,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      coverUrl: coverUrl ?? this.coverUrl,
      sourceKey: sourceKey ?? this.sourceKey,
      providerItemId: providerItemId ?? this.providerItemId,
      enabled: enabled ?? this.enabled,
      notifyPremiere: notifyPremiere ?? this.notifyPremiere,
      notifyEpisode: notifyEpisode ?? this.notifyEpisode,
      notifyChapter: notifyChapter ?? this.notifyChapter,
      notifyAiring: notifyAiring ?? this.notifyAiring,
      lastEpisode: lastEpisode ?? this.lastEpisode,
      lastChapter: lastChapter ?? this.lastChapter,
      nextAiringAt: nextAiringAt ?? this.nextAiringAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (mediaTitle.present) {
      map['media_title'] = Variable<String>(mediaTitle.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (providerItemId.present) {
      map['provider_item_id'] = Variable<String>(providerItemId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (notifyPremiere.present) {
      map['notify_premiere'] = Variable<bool>(notifyPremiere.value);
    }
    if (notifyEpisode.present) {
      map['notify_episode'] = Variable<bool>(notifyEpisode.value);
    }
    if (notifyChapter.present) {
      map['notify_chapter'] = Variable<bool>(notifyChapter.value);
    }
    if (notifyAiring.present) {
      map['notify_airing'] = Variable<bool>(notifyAiring.value);
    }
    if (lastEpisode.present) {
      map['last_episode'] = Variable<double>(lastEpisode.value);
    }
    if (lastChapter.present) {
      map['last_chapter'] = Variable<String>(lastChapter.value);
    }
    if (nextAiringAt.present) {
      map['next_airing_at'] = Variable<DateTime>(nextAiringAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSubscriptionsCompanion(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('mediaType: $mediaType, ')
          ..write('origin: $origin, ')
          ..write('mediaTitle: $mediaTitle, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('providerItemId: $providerItemId, ')
          ..write('enabled: $enabled, ')
          ..write('notifyPremiere: $notifyPremiere, ')
          ..write('notifyEpisode: $notifyEpisode, ')
          ..write('notifyChapter: $notifyChapter, ')
          ..write('notifyAiring: $notifyAiring, ')
          ..write('lastEpisode: $lastEpisode, ')
          ..write('lastChapter: $lastChapter, ')
          ..write('nextAiringAt: $nextAiringAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppNotificationsTable extends AppNotifications
    with TableInfo<$AppNotificationsTable, AppNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
    'media_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deepLinkMeta = const VerificationMeta(
    'deepLink',
  );
  @override
  late final GeneratedColumn<String> deepLink = GeneratedColumn<String>(
    'deep_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _privacyLevelMeta = const VerificationMeta(
    'privacyLevel',
  );
  @override
  late final GeneratedColumn<String> privacyLevel = GeneratedColumn<String>(
    'privacy_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventAtMeta = const VerificationMeta(
    'eventAt',
  );
  @override
  late final GeneratedColumn<DateTime> eventAt = GeneratedColumn<DateTime>(
    'event_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    mediaId,
    title,
    body,
    deepLink,
    privacyLevel,
    eventAt,
    isRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppNotification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('deep_link')) {
      context.handle(
        _deepLinkMeta,
        deepLink.isAcceptableOrUnknown(data['deep_link']!, _deepLinkMeta),
      );
    }
    if (data.containsKey('privacy_level')) {
      context.handle(
        _privacyLevelMeta,
        privacyLevel.isAcceptableOrUnknown(
          data['privacy_level']!,
          _privacyLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_privacyLevelMeta);
    }
    if (data.containsKey('event_at')) {
      context.handle(
        _eventAtMeta,
        eventAt.isAcceptableOrUnknown(data['event_at']!, _eventAtMeta),
      );
    } else if (isInserting) {
      context.missing(_eventAtMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppNotification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      deepLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deep_link'],
      ),
      privacyLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}privacy_level'],
      )!,
      eventAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_at'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
    );
  }

  @override
  $AppNotificationsTable createAlias(String alias) {
    return $AppNotificationsTable(attachedDatabase, alias);
  }
}

class AppNotification extends DataClass implements Insertable<AppNotification> {
  final String id;
  final String category;
  final int? mediaId;
  final String title;
  final String body;
  final String? deepLink;
  final String privacyLevel;
  final DateTime eventAt;
  final bool isRead;
  const AppNotification({
    required this.id,
    required this.category,
    this.mediaId,
    required this.title,
    required this.body,
    this.deepLink,
    required this.privacyLevel,
    required this.eventAt,
    required this.isRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<int>(mediaId);
    }
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || deepLink != null) {
      map['deep_link'] = Variable<String>(deepLink);
    }
    map['privacy_level'] = Variable<String>(privacyLevel);
    map['event_at'] = Variable<DateTime>(eventAt);
    map['is_read'] = Variable<bool>(isRead);
    return map;
  }

  AppNotificationsCompanion toCompanion(bool nullToAbsent) {
    return AppNotificationsCompanion(
      id: Value(id),
      category: Value(category),
      mediaId: mediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaId),
      title: Value(title),
      body: Value(body),
      deepLink: deepLink == null && nullToAbsent
          ? const Value.absent()
          : Value(deepLink),
      privacyLevel: Value(privacyLevel),
      eventAt: Value(eventAt),
      isRead: Value(isRead),
    );
  }

  factory AppNotification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppNotification(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      mediaId: serializer.fromJson<int?>(json['mediaId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      deepLink: serializer.fromJson<String?>(json['deepLink']),
      privacyLevel: serializer.fromJson<String>(json['privacyLevel']),
      eventAt: serializer.fromJson<DateTime>(json['eventAt']),
      isRead: serializer.fromJson<bool>(json['isRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'mediaId': serializer.toJson<int?>(mediaId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'deepLink': serializer.toJson<String?>(deepLink),
      'privacyLevel': serializer.toJson<String>(privacyLevel),
      'eventAt': serializer.toJson<DateTime>(eventAt),
      'isRead': serializer.toJson<bool>(isRead),
    };
  }

  AppNotification copyWith({
    String? id,
    String? category,
    Value<int?> mediaId = const Value.absent(),
    String? title,
    String? body,
    Value<String?> deepLink = const Value.absent(),
    String? privacyLevel,
    DateTime? eventAt,
    bool? isRead,
  }) => AppNotification(
    id: id ?? this.id,
    category: category ?? this.category,
    mediaId: mediaId.present ? mediaId.value : this.mediaId,
    title: title ?? this.title,
    body: body ?? this.body,
    deepLink: deepLink.present ? deepLink.value : this.deepLink,
    privacyLevel: privacyLevel ?? this.privacyLevel,
    eventAt: eventAt ?? this.eventAt,
    isRead: isRead ?? this.isRead,
  );
  AppNotification copyWithCompanion(AppNotificationsCompanion data) {
    return AppNotification(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      deepLink: data.deepLink.present ? data.deepLink.value : this.deepLink,
      privacyLevel: data.privacyLevel.present
          ? data.privacyLevel.value
          : this.privacyLevel,
      eventAt: data.eventAt.present ? data.eventAt.value : this.eventAt,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppNotification(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('mediaId: $mediaId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('deepLink: $deepLink, ')
          ..write('privacyLevel: $privacyLevel, ')
          ..write('eventAt: $eventAt, ')
          ..write('isRead: $isRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    mediaId,
    title,
    body,
    deepLink,
    privacyLevel,
    eventAt,
    isRead,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppNotification &&
          other.id == this.id &&
          other.category == this.category &&
          other.mediaId == this.mediaId &&
          other.title == this.title &&
          other.body == this.body &&
          other.deepLink == this.deepLink &&
          other.privacyLevel == this.privacyLevel &&
          other.eventAt == this.eventAt &&
          other.isRead == this.isRead);
}

class AppNotificationsCompanion extends UpdateCompanion<AppNotification> {
  final Value<String> id;
  final Value<String> category;
  final Value<int?> mediaId;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> deepLink;
  final Value<String> privacyLevel;
  final Value<DateTime> eventAt;
  final Value<bool> isRead;
  final Value<int> rowid;
  const AppNotificationsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.deepLink = const Value.absent(),
    this.privacyLevel = const Value.absent(),
    this.eventAt = const Value.absent(),
    this.isRead = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppNotificationsCompanion.insert({
    required String id,
    required String category,
    this.mediaId = const Value.absent(),
    required String title,
    required String body,
    this.deepLink = const Value.absent(),
    required String privacyLevel,
    required DateTime eventAt,
    this.isRead = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       title = Value(title),
       body = Value(body),
       privacyLevel = Value(privacyLevel),
       eventAt = Value(eventAt);
  static Insertable<AppNotification> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<int>? mediaId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? deepLink,
    Expression<String>? privacyLevel,
    Expression<DateTime>? eventAt,
    Expression<bool>? isRead,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (mediaId != null) 'media_id': mediaId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (deepLink != null) 'deep_link': deepLink,
      if (privacyLevel != null) 'privacy_level': privacyLevel,
      if (eventAt != null) 'event_at': eventAt,
      if (isRead != null) 'is_read': isRead,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppNotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<int?>? mediaId,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? deepLink,
    Value<String>? privacyLevel,
    Value<DateTime>? eventAt,
    Value<bool>? isRead,
    Value<int>? rowid,
  }) {
    return AppNotificationsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      body: body ?? this.body,
      deepLink: deepLink ?? this.deepLink,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      eventAt: eventAt ?? this.eventAt,
      isRead: isRead ?? this.isRead,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (deepLink.present) {
      map['deep_link'] = Variable<String>(deepLink.value);
    }
    if (privacyLevel.present) {
      map['privacy_level'] = Variable<String>(privacyLevel.value);
    }
    if (eventAt.present) {
      map['event_at'] = Variable<DateTime>(eventAt.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('mediaId: $mediaId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('deepLink: $deepLink, ')
          ..write('privacyLevel: $privacyLevel, ')
          ..write('eventAt: $eventAt, ')
          ..write('isRead: $isRead, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchOrderCacheEntriesTable extends WatchOrderCacheEntries
    with TableInfo<$WatchOrderCacheEntriesTable, WatchOrderCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchOrderCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storedAtMeta = const VerificationMeta(
    'storedAt',
  );
  @override
  late final GeneratedColumn<DateTime> storedAt = GeneratedColumn<DateTime>(
    'stored_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaId,
    source,
    payload,
    storedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_order_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchOrderCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('stored_at')) {
      context.handle(
        _storedAtMeta,
        storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_storedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaId, source};
  @override
  WatchOrderCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchOrderCacheEntry(
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      storedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stored_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $WatchOrderCacheEntriesTable createAlias(String alias) {
    return $WatchOrderCacheEntriesTable(attachedDatabase, alias);
  }
}

class WatchOrderCacheEntry extends DataClass
    implements Insertable<WatchOrderCacheEntry> {
  final int mediaId;
  final String source;
  final String payload;
  final DateTime storedAt;
  final DateTime expiresAt;
  const WatchOrderCacheEntry({
    required this.mediaId,
    required this.source,
    required this.payload,
    required this.storedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_id'] = Variable<int>(mediaId);
    map['source'] = Variable<String>(source);
    map['payload'] = Variable<String>(payload);
    map['stored_at'] = Variable<DateTime>(storedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  WatchOrderCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return WatchOrderCacheEntriesCompanion(
      mediaId: Value(mediaId),
      source: Value(source),
      payload: Value(payload),
      storedAt: Value(storedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory WatchOrderCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchOrderCacheEntry(
      mediaId: serializer.fromJson<int>(json['mediaId']),
      source: serializer.fromJson<String>(json['source']),
      payload: serializer.fromJson<String>(json['payload']),
      storedAt: serializer.fromJson<DateTime>(json['storedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaId': serializer.toJson<int>(mediaId),
      'source': serializer.toJson<String>(source),
      'payload': serializer.toJson<String>(payload),
      'storedAt': serializer.toJson<DateTime>(storedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  WatchOrderCacheEntry copyWith({
    int? mediaId,
    String? source,
    String? payload,
    DateTime? storedAt,
    DateTime? expiresAt,
  }) => WatchOrderCacheEntry(
    mediaId: mediaId ?? this.mediaId,
    source: source ?? this.source,
    payload: payload ?? this.payload,
    storedAt: storedAt ?? this.storedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  WatchOrderCacheEntry copyWithCompanion(WatchOrderCacheEntriesCompanion data) {
    return WatchOrderCacheEntry(
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      source: data.source.present ? data.source.value : this.source,
      payload: data.payload.present ? data.payload.value : this.payload,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchOrderCacheEntry(')
          ..write('mediaId: $mediaId, ')
          ..write('source: $source, ')
          ..write('payload: $payload, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mediaId, source, payload, storedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchOrderCacheEntry &&
          other.mediaId == this.mediaId &&
          other.source == this.source &&
          other.payload == this.payload &&
          other.storedAt == this.storedAt &&
          other.expiresAt == this.expiresAt);
}

class WatchOrderCacheEntriesCompanion
    extends UpdateCompanion<WatchOrderCacheEntry> {
  final Value<int> mediaId;
  final Value<String> source;
  final Value<String> payload;
  final Value<DateTime> storedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const WatchOrderCacheEntriesCompanion({
    this.mediaId = const Value.absent(),
    this.source = const Value.absent(),
    this.payload = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchOrderCacheEntriesCompanion.insert({
    required int mediaId,
    required String source,
    required String payload,
    required DateTime storedAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : mediaId = Value(mediaId),
       source = Value(source),
       payload = Value(payload),
       storedAt = Value(storedAt),
       expiresAt = Value(expiresAt);
  static Insertable<WatchOrderCacheEntry> custom({
    Expression<int>? mediaId,
    Expression<String>? source,
    Expression<String>? payload,
    Expression<DateTime>? storedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaId != null) 'media_id': mediaId,
      if (source != null) 'source': source,
      if (payload != null) 'payload': payload,
      if (storedAt != null) 'stored_at': storedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchOrderCacheEntriesCompanion copyWith({
    Value<int>? mediaId,
    Value<String>? source,
    Value<String>? payload,
    Value<DateTime>? storedAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return WatchOrderCacheEntriesCompanion(
      mediaId: mediaId ?? this.mediaId,
      source: source ?? this.source,
      payload: payload ?? this.payload,
      storedAt: storedAt ?? this.storedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<DateTime>(storedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchOrderCacheEntriesCompanion(')
          ..write('mediaId: $mediaId, ')
          ..write('source: $source, ')
          ..write('payload: $payload, ')
          ..write('storedAt: $storedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NovelLibraryEntriesTable extends NovelLibraryEntries
    with TableInfo<$NovelLibraryEntriesTable, NovelLibraryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NovelLibraryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aniListIdMeta = const VerificationMeta(
    'aniListId',
  );
  @override
  late final GeneratedColumn<int> aniListId = GeneratedColumn<int>(
    'ani_list_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerKeyMeta = const VerificationMeta(
    'providerKey',
  );
  @override
  late final GeneratedColumn<String> providerKey = GeneratedColumn<String>(
    'provider_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerItemIdMeta = const VerificationMeta(
    'providerItemId',
  );
  @override
  late final GeneratedColumn<String> providerItemId = GeneratedColumn<String>(
    'provider_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    aniListId,
    title,
    author,
    coverUrl,
    providerKey,
    providerItemId,
    localPath,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'novel_library_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<NovelLibraryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ani_list_id')) {
      context.handle(
        _aniListIdMeta,
        aniListId.isAcceptableOrUnknown(data['ani_list_id']!, _aniListIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('provider_key')) {
      context.handle(
        _providerKeyMeta,
        providerKey.isAcceptableOrUnknown(
          data['provider_key']!,
          _providerKeyMeta,
        ),
      );
    }
    if (data.containsKey('provider_item_id')) {
      context.handle(
        _providerItemIdMeta,
        providerItemId.isAcceptableOrUnknown(
          data['provider_item_id']!,
          _providerItemIdMeta,
        ),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NovelLibraryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NovelLibraryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      aniListId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ani_list_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      providerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_key'],
      ),
      providerItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_item_id'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NovelLibraryEntriesTable createAlias(String alias) {
    return $NovelLibraryEntriesTable(attachedDatabase, alias);
  }
}

class NovelLibraryEntry extends DataClass
    implements Insertable<NovelLibraryEntry> {
  final String id;
  final int? aniListId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? providerKey;
  final String? providerItemId;
  final String? localPath;
  final DateTime updatedAt;
  const NovelLibraryEntry({
    required this.id,
    this.aniListId,
    required this.title,
    this.author,
    this.coverUrl,
    this.providerKey,
    this.providerItemId,
    this.localPath,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || aniListId != null) {
      map['ani_list_id'] = Variable<int>(aniListId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || providerKey != null) {
      map['provider_key'] = Variable<String>(providerKey);
    }
    if (!nullToAbsent || providerItemId != null) {
      map['provider_item_id'] = Variable<String>(providerItemId);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NovelLibraryEntriesCompanion toCompanion(bool nullToAbsent) {
    return NovelLibraryEntriesCompanion(
      id: Value(id),
      aniListId: aniListId == null && nullToAbsent
          ? const Value.absent()
          : Value(aniListId),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      providerKey: providerKey == null && nullToAbsent
          ? const Value.absent()
          : Value(providerKey),
      providerItemId: providerItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerItemId),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      updatedAt: Value(updatedAt),
    );
  }

  factory NovelLibraryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NovelLibraryEntry(
      id: serializer.fromJson<String>(json['id']),
      aniListId: serializer.fromJson<int?>(json['aniListId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      providerKey: serializer.fromJson<String?>(json['providerKey']),
      providerItemId: serializer.fromJson<String?>(json['providerItemId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'aniListId': serializer.toJson<int?>(aniListId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'providerKey': serializer.toJson<String?>(providerKey),
      'providerItemId': serializer.toJson<String?>(providerItemId),
      'localPath': serializer.toJson<String?>(localPath),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NovelLibraryEntry copyWith({
    String? id,
    Value<int?> aniListId = const Value.absent(),
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> providerKey = const Value.absent(),
    Value<String?> providerItemId = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    DateTime? updatedAt,
  }) => NovelLibraryEntry(
    id: id ?? this.id,
    aniListId: aniListId.present ? aniListId.value : this.aniListId,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    providerKey: providerKey.present ? providerKey.value : this.providerKey,
    providerItemId: providerItemId.present
        ? providerItemId.value
        : this.providerItemId,
    localPath: localPath.present ? localPath.value : this.localPath,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NovelLibraryEntry copyWithCompanion(NovelLibraryEntriesCompanion data) {
    return NovelLibraryEntry(
      id: data.id.present ? data.id.value : this.id,
      aniListId: data.aniListId.present ? data.aniListId.value : this.aniListId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      providerKey: data.providerKey.present
          ? data.providerKey.value
          : this.providerKey,
      providerItemId: data.providerItemId.present
          ? data.providerItemId.value
          : this.providerItemId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NovelLibraryEntry(')
          ..write('id: $id, ')
          ..write('aniListId: $aniListId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('providerKey: $providerKey, ')
          ..write('providerItemId: $providerItemId, ')
          ..write('localPath: $localPath, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    aniListId,
    title,
    author,
    coverUrl,
    providerKey,
    providerItemId,
    localPath,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NovelLibraryEntry &&
          other.id == this.id &&
          other.aniListId == this.aniListId &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverUrl == this.coverUrl &&
          other.providerKey == this.providerKey &&
          other.providerItemId == this.providerItemId &&
          other.localPath == this.localPath &&
          other.updatedAt == this.updatedAt);
}

class NovelLibraryEntriesCompanion extends UpdateCompanion<NovelLibraryEntry> {
  final Value<String> id;
  final Value<int?> aniListId;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> coverUrl;
  final Value<String?> providerKey;
  final Value<String?> providerItemId;
  final Value<String?> localPath;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NovelLibraryEntriesCompanion({
    this.id = const Value.absent(),
    this.aniListId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.providerKey = const Value.absent(),
    this.providerItemId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NovelLibraryEntriesCompanion.insert({
    required String id,
    this.aniListId = const Value.absent(),
    required String title,
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.providerKey = const Value.absent(),
    this.providerItemId = const Value.absent(),
    this.localPath = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<NovelLibraryEntry> custom({
    Expression<String>? id,
    Expression<int>? aniListId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverUrl,
    Expression<String>? providerKey,
    Expression<String>? providerItemId,
    Expression<String>? localPath,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (aniListId != null) 'ani_list_id': aniListId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (providerKey != null) 'provider_key': providerKey,
      if (providerItemId != null) 'provider_item_id': providerItemId,
      if (localPath != null) 'local_path': localPath,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NovelLibraryEntriesCompanion copyWith({
    Value<String>? id,
    Value<int?>? aniListId,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? coverUrl,
    Value<String?>? providerKey,
    Value<String?>? providerItemId,
    Value<String?>? localPath,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NovelLibraryEntriesCompanion(
      id: id ?? this.id,
      aniListId: aniListId ?? this.aniListId,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      providerKey: providerKey ?? this.providerKey,
      providerItemId: providerItemId ?? this.providerItemId,
      localPath: localPath ?? this.localPath,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (aniListId.present) {
      map['ani_list_id'] = Variable<int>(aniListId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (providerKey.present) {
      map['provider_key'] = Variable<String>(providerKey.value);
    }
    if (providerItemId.present) {
      map['provider_item_id'] = Variable<String>(providerItemId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NovelLibraryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('aniListId: $aniListId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('providerKey: $providerKey, ')
          ..write('providerItemId: $providerItemId, ')
          ..write('localPath: $localPath, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NovelChapterEntriesTable extends NovelChapterEntries
    with TableInfo<$NovelChapterEntriesTable, NovelChapterEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NovelChapterEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<String> novelId = GeneratedColumn<String>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novel_library_entries (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterNumberMeta = const VerificationMeta(
    'chapterNumber',
  );
  @override
  late final GeneratedColumn<String> chapterNumber = GeneratedColumn<String>(
    'chapter_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    title,
    chapterNumber,
    sourceUrl,
    localPath,
    progress,
    readAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'novel_chapter_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<NovelChapterEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('chapter_number')) {
      context.handle(
        _chapterNumberMeta,
        chapterNumber.isAcceptableOrUnknown(
          data['chapter_number']!,
          _chapterNumberMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NovelChapterEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NovelChapterEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}novel_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      chapterNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_number'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NovelChapterEntriesTable createAlias(String alias) {
    return $NovelChapterEntriesTable(attachedDatabase, alias);
  }
}

class NovelChapterEntry extends DataClass
    implements Insertable<NovelChapterEntry> {
  final String id;
  final String novelId;
  final String title;
  final String? chapterNumber;
  final String? sourceUrl;
  final String? localPath;
  final double progress;
  final DateTime? readAt;
  final DateTime updatedAt;
  const NovelChapterEntry({
    required this.id,
    required this.novelId,
    required this.title,
    this.chapterNumber,
    this.sourceUrl,
    this.localPath,
    required this.progress,
    this.readAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['novel_id'] = Variable<String>(novelId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || chapterNumber != null) {
      map['chapter_number'] = Variable<String>(chapterNumber);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NovelChapterEntriesCompanion toCompanion(bool nullToAbsent) {
    return NovelChapterEntriesCompanion(
      id: Value(id),
      novelId: Value(novelId),
      title: Value(title),
      chapterNumber: chapterNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterNumber),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      progress: Value(progress),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NovelChapterEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NovelChapterEntry(
      id: serializer.fromJson<String>(json['id']),
      novelId: serializer.fromJson<String>(json['novelId']),
      title: serializer.fromJson<String>(json['title']),
      chapterNumber: serializer.fromJson<String?>(json['chapterNumber']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      progress: serializer.fromJson<double>(json['progress']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'novelId': serializer.toJson<String>(novelId),
      'title': serializer.toJson<String>(title),
      'chapterNumber': serializer.toJson<String?>(chapterNumber),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'localPath': serializer.toJson<String?>(localPath),
      'progress': serializer.toJson<double>(progress),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NovelChapterEntry copyWith({
    String? id,
    String? novelId,
    String? title,
    Value<String?> chapterNumber = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    double? progress,
    Value<DateTime?> readAt = const Value.absent(),
    DateTime? updatedAt,
  }) => NovelChapterEntry(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    title: title ?? this.title,
    chapterNumber: chapterNumber.present
        ? chapterNumber.value
        : this.chapterNumber,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    localPath: localPath.present ? localPath.value : this.localPath,
    progress: progress ?? this.progress,
    readAt: readAt.present ? readAt.value : this.readAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NovelChapterEntry copyWithCompanion(NovelChapterEntriesCompanion data) {
    return NovelChapterEntry(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      title: data.title.present ? data.title.value : this.title,
      chapterNumber: data.chapterNumber.present
          ? data.chapterNumber.value
          : this.chapterNumber,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      progress: data.progress.present ? data.progress.value : this.progress,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NovelChapterEntry(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('title: $title, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('localPath: $localPath, ')
          ..write('progress: $progress, ')
          ..write('readAt: $readAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    novelId,
    title,
    chapterNumber,
    sourceUrl,
    localPath,
    progress,
    readAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NovelChapterEntry &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.title == this.title &&
          other.chapterNumber == this.chapterNumber &&
          other.sourceUrl == this.sourceUrl &&
          other.localPath == this.localPath &&
          other.progress == this.progress &&
          other.readAt == this.readAt &&
          other.updatedAt == this.updatedAt);
}

class NovelChapterEntriesCompanion extends UpdateCompanion<NovelChapterEntry> {
  final Value<String> id;
  final Value<String> novelId;
  final Value<String> title;
  final Value<String?> chapterNumber;
  final Value<String?> sourceUrl;
  final Value<String?> localPath;
  final Value<double> progress;
  final Value<DateTime?> readAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NovelChapterEntriesCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.title = const Value.absent(),
    this.chapterNumber = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.progress = const Value.absent(),
    this.readAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NovelChapterEntriesCompanion.insert({
    required String id,
    required String novelId,
    required String title,
    this.chapterNumber = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.progress = const Value.absent(),
    this.readAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       novelId = Value(novelId),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<NovelChapterEntry> custom({
    Expression<String>? id,
    Expression<String>? novelId,
    Expression<String>? title,
    Expression<String>? chapterNumber,
    Expression<String>? sourceUrl,
    Expression<String>? localPath,
    Expression<double>? progress,
    Expression<DateTime>? readAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (title != null) 'title': title,
      if (chapterNumber != null) 'chapter_number': chapterNumber,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (localPath != null) 'local_path': localPath,
      if (progress != null) 'progress': progress,
      if (readAt != null) 'read_at': readAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NovelChapterEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? novelId,
    Value<String>? title,
    Value<String?>? chapterNumber,
    Value<String?>? sourceUrl,
    Value<String?>? localPath,
    Value<double>? progress,
    Value<DateTime?>? readAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NovelChapterEntriesCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      title: title ?? this.title,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      progress: progress ?? this.progress,
      readAt: readAt ?? this.readAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<String>(novelId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (chapterNumber.present) {
      map['chapter_number'] = Variable<String>(chapterNumber.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NovelChapterEntriesCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('title: $title, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('localPath: $localPath, ')
          ..write('progress: $progress, ')
          ..write('readAt: $readAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SchemaMetadataTable schemaMetadata = $SchemaMetadataTable(this);
  late final $SearchHistoryEntriesTable searchHistoryEntries =
      $SearchHistoryEntriesTable(this);
  late final $CachedResponsesTable cachedResponses = $CachedResponsesTable(
    this,
  );
  late final $SourceHealthEntriesTable sourceHealthEntries =
      $SourceHealthEntriesTable(this);
  late final $NotificationSubscriptionsTable notificationSubscriptions =
      $NotificationSubscriptionsTable(this);
  late final $AppNotificationsTable appNotifications = $AppNotificationsTable(
    this,
  );
  late final $WatchOrderCacheEntriesTable watchOrderCacheEntries =
      $WatchOrderCacheEntriesTable(this);
  late final $NovelLibraryEntriesTable novelLibraryEntries =
      $NovelLibraryEntriesTable(this);
  late final $NovelChapterEntriesTable novelChapterEntries =
      $NovelChapterEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    schemaMetadata,
    searchHistoryEntries,
    cachedResponses,
    sourceHealthEntries,
    notificationSubscriptions,
    appNotifications,
    watchOrderCacheEntries,
    novelLibraryEntries,
    novelChapterEntries,
  ];
}

typedef $$SchemaMetadataTableCreateCompanionBuilder =
    SchemaMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SchemaMetadataTableUpdateCompanionBuilder =
    SchemaMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SchemaMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SchemaMetadataTable> {
  $$SchemaMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchemaMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SchemaMetadataTable> {
  $$SchemaMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchemaMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchemaMetadataTable> {
  $$SchemaMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SchemaMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SchemaMetadataTable,
          SchemaMetadataData,
          $$SchemaMetadataTableFilterComposer,
          $$SchemaMetadataTableOrderingComposer,
          $$SchemaMetadataTableAnnotationComposer,
          $$SchemaMetadataTableCreateCompanionBuilder,
          $$SchemaMetadataTableUpdateCompanionBuilder,
          (
            SchemaMetadataData,
            BaseReferences<
              _$AppDatabase,
              $SchemaMetadataTable,
              SchemaMetadataData
            >,
          ),
          SchemaMetadataData,
          PrefetchHooks Function()
        > {
  $$SchemaMetadataTableTableManager(
    _$AppDatabase db,
    $SchemaMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchemaMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchemaMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchemaMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  SchemaMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SchemaMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SchemaMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SchemaMetadataTable,
      SchemaMetadataData,
      $$SchemaMetadataTableFilterComposer,
      $$SchemaMetadataTableOrderingComposer,
      $$SchemaMetadataTableAnnotationComposer,
      $$SchemaMetadataTableCreateCompanionBuilder,
      $$SchemaMetadataTableUpdateCompanionBuilder,
      (
        SchemaMetadataData,
        BaseReferences<_$AppDatabase, $SchemaMetadataTable, SchemaMetadataData>,
      ),
      SchemaMetadataData,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryEntriesTableCreateCompanionBuilder =
    SearchHistoryEntriesCompanion Function({
      Value<int> id,
      required String target,
      required String query,
      required DateTime usedAt,
    });
typedef $$SearchHistoryEntriesTableUpdateCompanionBuilder =
    SearchHistoryEntriesCompanion Function({
      Value<int> id,
      Value<String> target,
      Value<String> query,
      Value<DateTime> usedAt,
    });

class $$SearchHistoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryEntriesTable> {
  $$SearchHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<DateTime> get usedAt =>
      $composableBuilder(column: $table.usedAt, builder: (column) => column);
}

class $$SearchHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryEntriesTable,
          SearchHistoryEntry,
          $$SearchHistoryEntriesTableFilterComposer,
          $$SearchHistoryEntriesTableOrderingComposer,
          $$SearchHistoryEntriesTableAnnotationComposer,
          $$SearchHistoryEntriesTableCreateCompanionBuilder,
          $$SearchHistoryEntriesTableUpdateCompanionBuilder,
          (
            SearchHistoryEntry,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryEntriesTable,
              SearchHistoryEntry
            >,
          ),
          SearchHistoryEntry,
          PrefetchHooks Function()
        > {
  $$SearchHistoryEntriesTableTableManager(
    _$AppDatabase db,
    $SearchHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SearchHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<DateTime> usedAt = const Value.absent(),
              }) => SearchHistoryEntriesCompanion(
                id: id,
                target: target,
                query: query,
                usedAt: usedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String target,
                required String query,
                required DateTime usedAt,
              }) => SearchHistoryEntriesCompanion.insert(
                id: id,
                target: target,
                query: query,
                usedAt: usedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryEntriesTable,
      SearchHistoryEntry,
      $$SearchHistoryEntriesTableFilterComposer,
      $$SearchHistoryEntriesTableOrderingComposer,
      $$SearchHistoryEntriesTableAnnotationComposer,
      $$SearchHistoryEntriesTableCreateCompanionBuilder,
      $$SearchHistoryEntriesTableUpdateCompanionBuilder,
      (
        SearchHistoryEntry,
        BaseReferences<
          _$AppDatabase,
          $SearchHistoryEntriesTable,
          SearchHistoryEntry
        >,
      ),
      SearchHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedResponsesTableCreateCompanionBuilder =
    CachedResponsesCompanion Function({
      required String key,
      required String body,
      Value<String?> etag,
      required DateTime storedAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$CachedResponsesTableUpdateCompanionBuilder =
    CachedResponsesCompanion Function({
      Value<String> key,
      Value<String> body,
      Value<String?> etag,
      Value<DateTime> storedAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$CachedResponsesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedResponsesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedResponsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$CachedResponsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedResponsesTable,
          CachedResponse,
          $$CachedResponsesTableFilterComposer,
          $$CachedResponsesTableOrderingComposer,
          $$CachedResponsesTableAnnotationComposer,
          $$CachedResponsesTableCreateCompanionBuilder,
          $$CachedResponsesTableUpdateCompanionBuilder,
          (
            CachedResponse,
            BaseReferences<
              _$AppDatabase,
              $CachedResponsesTable,
              CachedResponse
            >,
          ),
          CachedResponse,
          PrefetchHooks Function()
        > {
  $$CachedResponsesTableTableManager(
    _$AppDatabase db,
    $CachedResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime> storedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion(
                key: key,
                body: body,
                etag: etag,
                storedAt: storedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String body,
                Value<String?> etag = const Value.absent(),
                required DateTime storedAt,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion.insert(
                key: key,
                body: body,
                etag: etag,
                storedAt: storedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedResponsesTable,
      CachedResponse,
      $$CachedResponsesTableFilterComposer,
      $$CachedResponsesTableOrderingComposer,
      $$CachedResponsesTableAnnotationComposer,
      $$CachedResponsesTableCreateCompanionBuilder,
      $$CachedResponsesTableUpdateCompanionBuilder,
      (
        CachedResponse,
        BaseReferences<_$AppDatabase, $CachedResponsesTable, CachedResponse>,
      ),
      CachedResponse,
      PrefetchHooks Function()
    >;
typedef $$SourceHealthEntriesTableCreateCompanionBuilder =
    SourceHealthEntriesCompanion Function({
      required String sourceKey,
      required bool succeeded,
      Value<int?> latencyMs,
      Value<String?> lastError,
      required DateTime checkedAt,
      Value<int> rowid,
    });
typedef $$SourceHealthEntriesTableUpdateCompanionBuilder =
    SourceHealthEntriesCompanion Function({
      Value<String> sourceKey,
      Value<bool> succeeded,
      Value<int?> latencyMs,
      Value<String?> lastError,
      Value<DateTime> checkedAt,
      Value<int> rowid,
    });

class $$SourceHealthEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SourceHealthEntriesTable> {
  $$SourceHealthEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get succeeded => $composableBuilder(
    column: $table.succeeded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceHealthEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceHealthEntriesTable> {
  $$SourceHealthEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get succeeded => $composableBuilder(
    column: $table.succeeded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceHealthEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceHealthEntriesTable> {
  $$SourceHealthEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<bool> get succeeded =>
      $composableBuilder(column: $table.succeeded, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$SourceHealthEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceHealthEntriesTable,
          SourceHealthEntry,
          $$SourceHealthEntriesTableFilterComposer,
          $$SourceHealthEntriesTableOrderingComposer,
          $$SourceHealthEntriesTableAnnotationComposer,
          $$SourceHealthEntriesTableCreateCompanionBuilder,
          $$SourceHealthEntriesTableUpdateCompanionBuilder,
          (
            SourceHealthEntry,
            BaseReferences<
              _$AppDatabase,
              $SourceHealthEntriesTable,
              SourceHealthEntry
            >,
          ),
          SourceHealthEntry,
          PrefetchHooks Function()
        > {
  $$SourceHealthEntriesTableTableManager(
    _$AppDatabase db,
    $SourceHealthEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceHealthEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceHealthEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SourceHealthEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceKey = const Value.absent(),
                Value<bool> succeeded = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceHealthEntriesCompanion(
                sourceKey: sourceKey,
                succeeded: succeeded,
                latencyMs: latencyMs,
                lastError: lastError,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceKey,
                required bool succeeded,
                Value<int?> latencyMs = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime checkedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourceHealthEntriesCompanion.insert(
                sourceKey: sourceKey,
                succeeded: succeeded,
                latencyMs: latencyMs,
                lastError: lastError,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceHealthEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceHealthEntriesTable,
      SourceHealthEntry,
      $$SourceHealthEntriesTableFilterComposer,
      $$SourceHealthEntriesTableOrderingComposer,
      $$SourceHealthEntriesTableAnnotationComposer,
      $$SourceHealthEntriesTableCreateCompanionBuilder,
      $$SourceHealthEntriesTableUpdateCompanionBuilder,
      (
        SourceHealthEntry,
        BaseReferences<
          _$AppDatabase,
          $SourceHealthEntriesTable,
          SourceHealthEntry
        >,
      ),
      SourceHealthEntry,
      PrefetchHooks Function()
    >;
typedef $$NotificationSubscriptionsTableCreateCompanionBuilder =
    NotificationSubscriptionsCompanion Function({
      required String id,
      required int mediaId,
      required String mediaType,
      required String origin,
      Value<String> mediaTitle,
      Value<String?> coverUrl,
      Value<String?> sourceKey,
      Value<String?> providerItemId,
      Value<bool> enabled,
      Value<bool> notifyPremiere,
      Value<bool> notifyEpisode,
      Value<bool> notifyChapter,
      Value<bool> notifyAiring,
      Value<double?> lastEpisode,
      Value<String?> lastChapter,
      Value<DateTime?> nextAiringAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NotificationSubscriptionsTableUpdateCompanionBuilder =
    NotificationSubscriptionsCompanion Function({
      Value<String> id,
      Value<int> mediaId,
      Value<String> mediaType,
      Value<String> origin,
      Value<String> mediaTitle,
      Value<String?> coverUrl,
      Value<String?> sourceKey,
      Value<String?> providerItemId,
      Value<bool> enabled,
      Value<bool> notifyPremiere,
      Value<bool> notifyEpisode,
      Value<bool> notifyChapter,
      Value<bool> notifyAiring,
      Value<double?> lastEpisode,
      Value<String?> lastChapter,
      Value<DateTime?> nextAiringAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$NotificationSubscriptionsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationSubscriptionsTable> {
  $$NotificationSubscriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaTitle => $composableBuilder(
    column: $table.mediaTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyPremiere => $composableBuilder(
    column: $table.notifyPremiere,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyEpisode => $composableBuilder(
    column: $table.notifyEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyChapter => $composableBuilder(
    column: $table.notifyChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyAiring => $composableBuilder(
    column: $table.notifyAiring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastEpisode => $composableBuilder(
    column: $table.lastEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastChapter => $composableBuilder(
    column: $table.lastChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAiringAt => $composableBuilder(
    column: $table.nextAiringAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationSubscriptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationSubscriptionsTable> {
  $$NotificationSubscriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaTitle => $composableBuilder(
    column: $table.mediaTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyPremiere => $composableBuilder(
    column: $table.notifyPremiere,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyEpisode => $composableBuilder(
    column: $table.notifyEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyChapter => $composableBuilder(
    column: $table.notifyChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyAiring => $composableBuilder(
    column: $table.notifyAiring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastEpisode => $composableBuilder(
    column: $table.lastEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastChapter => $composableBuilder(
    column: $table.lastChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAiringAt => $composableBuilder(
    column: $table.nextAiringAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationSubscriptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationSubscriptionsTable> {
  $$NotificationSubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get mediaTitle => $composableBuilder(
    column: $table.mediaTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get notifyPremiere => $composableBuilder(
    column: $table.notifyPremiere,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notifyEpisode => $composableBuilder(
    column: $table.notifyEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notifyChapter => $composableBuilder(
    column: $table.notifyChapter,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notifyAiring => $composableBuilder(
    column: $table.notifyAiring,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lastEpisode => $composableBuilder(
    column: $table.lastEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastChapter => $composableBuilder(
    column: $table.lastChapter,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAiringAt => $composableBuilder(
    column: $table.nextAiringAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotificationSubscriptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationSubscriptionsTable,
          NotificationSubscription,
          $$NotificationSubscriptionsTableFilterComposer,
          $$NotificationSubscriptionsTableOrderingComposer,
          $$NotificationSubscriptionsTableAnnotationComposer,
          $$NotificationSubscriptionsTableCreateCompanionBuilder,
          $$NotificationSubscriptionsTableUpdateCompanionBuilder,
          (
            NotificationSubscription,
            BaseReferences<
              _$AppDatabase,
              $NotificationSubscriptionsTable,
              NotificationSubscription
            >,
          ),
          NotificationSubscription,
          PrefetchHooks Function()
        > {
  $$NotificationSubscriptionsTableTableManager(
    _$AppDatabase db,
    $NotificationSubscriptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationSubscriptionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationSubscriptionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationSubscriptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> mediaId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> mediaTitle = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<String?> providerItemId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> notifyPremiere = const Value.absent(),
                Value<bool> notifyEpisode = const Value.absent(),
                Value<bool> notifyChapter = const Value.absent(),
                Value<bool> notifyAiring = const Value.absent(),
                Value<double?> lastEpisode = const Value.absent(),
                Value<String?> lastChapter = const Value.absent(),
                Value<DateTime?> nextAiringAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationSubscriptionsCompanion(
                id: id,
                mediaId: mediaId,
                mediaType: mediaType,
                origin: origin,
                mediaTitle: mediaTitle,
                coverUrl: coverUrl,
                sourceKey: sourceKey,
                providerItemId: providerItemId,
                enabled: enabled,
                notifyPremiere: notifyPremiere,
                notifyEpisode: notifyEpisode,
                notifyChapter: notifyChapter,
                notifyAiring: notifyAiring,
                lastEpisode: lastEpisode,
                lastChapter: lastChapter,
                nextAiringAt: nextAiringAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int mediaId,
                required String mediaType,
                required String origin,
                Value<String> mediaTitle = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<String?> providerItemId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> notifyPremiere = const Value.absent(),
                Value<bool> notifyEpisode = const Value.absent(),
                Value<bool> notifyChapter = const Value.absent(),
                Value<bool> notifyAiring = const Value.absent(),
                Value<double?> lastEpisode = const Value.absent(),
                Value<String?> lastChapter = const Value.absent(),
                Value<DateTime?> nextAiringAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotificationSubscriptionsCompanion.insert(
                id: id,
                mediaId: mediaId,
                mediaType: mediaType,
                origin: origin,
                mediaTitle: mediaTitle,
                coverUrl: coverUrl,
                sourceKey: sourceKey,
                providerItemId: providerItemId,
                enabled: enabled,
                notifyPremiere: notifyPremiere,
                notifyEpisode: notifyEpisode,
                notifyChapter: notifyChapter,
                notifyAiring: notifyAiring,
                lastEpisode: lastEpisode,
                lastChapter: lastChapter,
                nextAiringAt: nextAiringAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationSubscriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationSubscriptionsTable,
      NotificationSubscription,
      $$NotificationSubscriptionsTableFilterComposer,
      $$NotificationSubscriptionsTableOrderingComposer,
      $$NotificationSubscriptionsTableAnnotationComposer,
      $$NotificationSubscriptionsTableCreateCompanionBuilder,
      $$NotificationSubscriptionsTableUpdateCompanionBuilder,
      (
        NotificationSubscription,
        BaseReferences<
          _$AppDatabase,
          $NotificationSubscriptionsTable,
          NotificationSubscription
        >,
      ),
      NotificationSubscription,
      PrefetchHooks Function()
    >;
typedef $$AppNotificationsTableCreateCompanionBuilder =
    AppNotificationsCompanion Function({
      required String id,
      required String category,
      Value<int?> mediaId,
      required String title,
      required String body,
      Value<String?> deepLink,
      required String privacyLevel,
      required DateTime eventAt,
      Value<bool> isRead,
      Value<int> rowid,
    });
typedef $$AppNotificationsTableUpdateCompanionBuilder =
    AppNotificationsCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<int?> mediaId,
      Value<String> title,
      Value<String> body,
      Value<String?> deepLink,
      Value<String> privacyLevel,
      Value<DateTime> eventAt,
      Value<bool> isRead,
      Value<int> rowid,
    });

class $$AppNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deepLink => $composableBuilder(
    column: $table.deepLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventAt => $composableBuilder(
    column: $table.eventAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deepLink => $composableBuilder(
    column: $table.deepLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventAt => $composableBuilder(
    column: $table.eventAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get deepLink =>
      $composableBuilder(column: $table.deepLink, builder: (column) => column);

  GeneratedColumn<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eventAt =>
      $composableBuilder(column: $table.eventAt, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);
}

class $$AppNotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppNotificationsTable,
          AppNotification,
          $$AppNotificationsTableFilterComposer,
          $$AppNotificationsTableOrderingComposer,
          $$AppNotificationsTableAnnotationComposer,
          $$AppNotificationsTableCreateCompanionBuilder,
          $$AppNotificationsTableUpdateCompanionBuilder,
          (
            AppNotification,
            BaseReferences<
              _$AppDatabase,
              $AppNotificationsTable,
              AppNotification
            >,
          ),
          AppNotification,
          PrefetchHooks Function()
        > {
  $$AppNotificationsTableTableManager(
    _$AppDatabase db,
    $AppNotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppNotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppNotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppNotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int?> mediaId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> deepLink = const Value.absent(),
                Value<String> privacyLevel = const Value.absent(),
                Value<DateTime> eventAt = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppNotificationsCompanion(
                id: id,
                category: category,
                mediaId: mediaId,
                title: title,
                body: body,
                deepLink: deepLink,
                privacyLevel: privacyLevel,
                eventAt: eventAt,
                isRead: isRead,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                Value<int?> mediaId = const Value.absent(),
                required String title,
                required String body,
                Value<String?> deepLink = const Value.absent(),
                required String privacyLevel,
                required DateTime eventAt,
                Value<bool> isRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppNotificationsCompanion.insert(
                id: id,
                category: category,
                mediaId: mediaId,
                title: title,
                body: body,
                deepLink: deepLink,
                privacyLevel: privacyLevel,
                eventAt: eventAt,
                isRead: isRead,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppNotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppNotificationsTable,
      AppNotification,
      $$AppNotificationsTableFilterComposer,
      $$AppNotificationsTableOrderingComposer,
      $$AppNotificationsTableAnnotationComposer,
      $$AppNotificationsTableCreateCompanionBuilder,
      $$AppNotificationsTableUpdateCompanionBuilder,
      (
        AppNotification,
        BaseReferences<_$AppDatabase, $AppNotificationsTable, AppNotification>,
      ),
      AppNotification,
      PrefetchHooks Function()
    >;
typedef $$WatchOrderCacheEntriesTableCreateCompanionBuilder =
    WatchOrderCacheEntriesCompanion Function({
      required int mediaId,
      required String source,
      required String payload,
      required DateTime storedAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$WatchOrderCacheEntriesTableUpdateCompanionBuilder =
    WatchOrderCacheEntriesCompanion Function({
      Value<int> mediaId,
      Value<String> source,
      Value<String> payload,
      Value<DateTime> storedAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$WatchOrderCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WatchOrderCacheEntriesTable> {
  $$WatchOrderCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchOrderCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchOrderCacheEntriesTable> {
  $$WatchOrderCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get storedAt => $composableBuilder(
    column: $table.storedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchOrderCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchOrderCacheEntriesTable> {
  $$WatchOrderCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$WatchOrderCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchOrderCacheEntriesTable,
          WatchOrderCacheEntry,
          $$WatchOrderCacheEntriesTableFilterComposer,
          $$WatchOrderCacheEntriesTableOrderingComposer,
          $$WatchOrderCacheEntriesTableAnnotationComposer,
          $$WatchOrderCacheEntriesTableCreateCompanionBuilder,
          $$WatchOrderCacheEntriesTableUpdateCompanionBuilder,
          (
            WatchOrderCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $WatchOrderCacheEntriesTable,
              WatchOrderCacheEntry
            >,
          ),
          WatchOrderCacheEntry,
          PrefetchHooks Function()
        > {
  $$WatchOrderCacheEntriesTableTableManager(
    _$AppDatabase db,
    $WatchOrderCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchOrderCacheEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WatchOrderCacheEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WatchOrderCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> mediaId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> storedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchOrderCacheEntriesCompanion(
                mediaId: mediaId,
                source: source,
                payload: payload,
                storedAt: storedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int mediaId,
                required String source,
                required String payload,
                required DateTime storedAt,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchOrderCacheEntriesCompanion.insert(
                mediaId: mediaId,
                source: source,
                payload: payload,
                storedAt: storedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchOrderCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchOrderCacheEntriesTable,
      WatchOrderCacheEntry,
      $$WatchOrderCacheEntriesTableFilterComposer,
      $$WatchOrderCacheEntriesTableOrderingComposer,
      $$WatchOrderCacheEntriesTableAnnotationComposer,
      $$WatchOrderCacheEntriesTableCreateCompanionBuilder,
      $$WatchOrderCacheEntriesTableUpdateCompanionBuilder,
      (
        WatchOrderCacheEntry,
        BaseReferences<
          _$AppDatabase,
          $WatchOrderCacheEntriesTable,
          WatchOrderCacheEntry
        >,
      ),
      WatchOrderCacheEntry,
      PrefetchHooks Function()
    >;
typedef $$NovelLibraryEntriesTableCreateCompanionBuilder =
    NovelLibraryEntriesCompanion Function({
      required String id,
      Value<int?> aniListId,
      required String title,
      Value<String?> author,
      Value<String?> coverUrl,
      Value<String?> providerKey,
      Value<String?> providerItemId,
      Value<String?> localPath,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NovelLibraryEntriesTableUpdateCompanionBuilder =
    NovelLibraryEntriesCompanion Function({
      Value<String> id,
      Value<int?> aniListId,
      Value<String> title,
      Value<String?> author,
      Value<String?> coverUrl,
      Value<String?> providerKey,
      Value<String?> providerItemId,
      Value<String?> localPath,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$NovelLibraryEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NovelLibraryEntriesTable,
          NovelLibraryEntry
        > {
  $$NovelLibraryEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$NovelChapterEntriesTable, List<NovelChapterEntry>>
  _novelChapterEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.novelChapterEntries,
        aliasName: 'novel_library_entries__id__novel_chapter_entries__novel_id',
      );

  $$NovelChapterEntriesTableProcessedTableManager get novelChapterEntriesRefs {
    final manager = $$NovelChapterEntriesTableTableManager(
      $_db,
      $_db.novelChapterEntries,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _novelChapterEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NovelLibraryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $NovelLibraryEntriesTable> {
  $$NovelLibraryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aniListId => $composableBuilder(
    column: $table.aniListId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerKey => $composableBuilder(
    column: $table.providerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> novelChapterEntriesRefs(
    Expression<bool> Function($$NovelChapterEntriesTableFilterComposer f) f,
  ) {
    final $$NovelChapterEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.novelChapterEntries,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelChapterEntriesTableFilterComposer(
            $db: $db,
            $table: $db.novelChapterEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NovelLibraryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $NovelLibraryEntriesTable> {
  $$NovelLibraryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aniListId => $composableBuilder(
    column: $table.aniListId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerKey => $composableBuilder(
    column: $table.providerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NovelLibraryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NovelLibraryEntriesTable> {
  $$NovelLibraryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get aniListId =>
      $composableBuilder(column: $table.aniListId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get providerKey => $composableBuilder(
    column: $table.providerKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerItemId => $composableBuilder(
    column: $table.providerItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> novelChapterEntriesRefs<T extends Object>(
    Expression<T> Function($$NovelChapterEntriesTableAnnotationComposer a) f,
  ) {
    final $$NovelChapterEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.novelChapterEntries,
          getReferencedColumn: (t) => t.novelId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NovelChapterEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.novelChapterEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$NovelLibraryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NovelLibraryEntriesTable,
          NovelLibraryEntry,
          $$NovelLibraryEntriesTableFilterComposer,
          $$NovelLibraryEntriesTableOrderingComposer,
          $$NovelLibraryEntriesTableAnnotationComposer,
          $$NovelLibraryEntriesTableCreateCompanionBuilder,
          $$NovelLibraryEntriesTableUpdateCompanionBuilder,
          (NovelLibraryEntry, $$NovelLibraryEntriesTableReferences),
          NovelLibraryEntry,
          PrefetchHooks Function({bool novelChapterEntriesRefs})
        > {
  $$NovelLibraryEntriesTableTableManager(
    _$AppDatabase db,
    $NovelLibraryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NovelLibraryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NovelLibraryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NovelLibraryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> aniListId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> providerKey = const Value.absent(),
                Value<String?> providerItemId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NovelLibraryEntriesCompanion(
                id: id,
                aniListId: aniListId,
                title: title,
                author: author,
                coverUrl: coverUrl,
                providerKey: providerKey,
                providerItemId: providerItemId,
                localPath: localPath,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> aniListId = const Value.absent(),
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> providerKey = const Value.absent(),
                Value<String?> providerItemId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NovelLibraryEntriesCompanion.insert(
                id: id,
                aniListId: aniListId,
                title: title,
                author: author,
                coverUrl: coverUrl,
                providerKey: providerKey,
                providerItemId: providerItemId,
                localPath: localPath,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NovelLibraryEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelChapterEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (novelChapterEntriesRefs) db.novelChapterEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (novelChapterEntriesRefs)
                    await $_getPrefetchedData<
                      NovelLibraryEntry,
                      $NovelLibraryEntriesTable,
                      NovelChapterEntry
                    >(
                      currentTable: table,
                      referencedTable: $$NovelLibraryEntriesTableReferences
                          ._novelChapterEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NovelLibraryEntriesTableReferences(
                            db,
                            table,
                            p0,
                          ).novelChapterEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.novelId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NovelLibraryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NovelLibraryEntriesTable,
      NovelLibraryEntry,
      $$NovelLibraryEntriesTableFilterComposer,
      $$NovelLibraryEntriesTableOrderingComposer,
      $$NovelLibraryEntriesTableAnnotationComposer,
      $$NovelLibraryEntriesTableCreateCompanionBuilder,
      $$NovelLibraryEntriesTableUpdateCompanionBuilder,
      (NovelLibraryEntry, $$NovelLibraryEntriesTableReferences),
      NovelLibraryEntry,
      PrefetchHooks Function({bool novelChapterEntriesRefs})
    >;
typedef $$NovelChapterEntriesTableCreateCompanionBuilder =
    NovelChapterEntriesCompanion Function({
      required String id,
      required String novelId,
      required String title,
      Value<String?> chapterNumber,
      Value<String?> sourceUrl,
      Value<String?> localPath,
      Value<double> progress,
      Value<DateTime?> readAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NovelChapterEntriesTableUpdateCompanionBuilder =
    NovelChapterEntriesCompanion Function({
      Value<String> id,
      Value<String> novelId,
      Value<String> title,
      Value<String?> chapterNumber,
      Value<String?> sourceUrl,
      Value<String?> localPath,
      Value<double> progress,
      Value<DateTime?> readAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$NovelChapterEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NovelChapterEntriesTable,
          NovelChapterEntry
        > {
  $$NovelChapterEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NovelLibraryEntriesTable _novelIdTable(_$AppDatabase db) =>
      db.novelLibraryEntries.createAlias(
        'novel_chapter_entries__novel_id__novel_library_entries__id',
      );

  $$NovelLibraryEntriesTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<String>('novel_id')!;

    final manager = $$NovelLibraryEntriesTableTableManager(
      $_db,
      $_db.novelLibraryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NovelChapterEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $NovelChapterEntriesTable> {
  $$NovelChapterEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelLibraryEntriesTableFilterComposer get novelId {
    final $$NovelLibraryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novelLibraryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelLibraryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.novelLibraryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NovelChapterEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $NovelChapterEntriesTable> {
  $$NovelChapterEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelLibraryEntriesTableOrderingComposer get novelId {
    final $$NovelLibraryEntriesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.novelId,
          referencedTable: $db.novelLibraryEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NovelLibraryEntriesTableOrderingComposer(
                $db: $db,
                $table: $db.novelLibraryEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$NovelChapterEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NovelChapterEntriesTable> {
  $$NovelChapterEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NovelLibraryEntriesTableAnnotationComposer get novelId {
    final $$NovelLibraryEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.novelId,
          referencedTable: $db.novelLibraryEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NovelLibraryEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.novelLibraryEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$NovelChapterEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NovelChapterEntriesTable,
          NovelChapterEntry,
          $$NovelChapterEntriesTableFilterComposer,
          $$NovelChapterEntriesTableOrderingComposer,
          $$NovelChapterEntriesTableAnnotationComposer,
          $$NovelChapterEntriesTableCreateCompanionBuilder,
          $$NovelChapterEntriesTableUpdateCompanionBuilder,
          (NovelChapterEntry, $$NovelChapterEntriesTableReferences),
          NovelChapterEntry,
          PrefetchHooks Function({bool novelId})
        > {
  $$NovelChapterEntriesTableTableManager(
    _$AppDatabase db,
    $NovelChapterEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NovelChapterEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NovelChapterEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NovelChapterEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> novelId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> chapterNumber = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NovelChapterEntriesCompanion(
                id: id,
                novelId: novelId,
                title: title,
                chapterNumber: chapterNumber,
                sourceUrl: sourceUrl,
                localPath: localPath,
                progress: progress,
                readAt: readAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String novelId,
                required String title,
                Value<String?> chapterNumber = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NovelChapterEntriesCompanion.insert(
                id: id,
                novelId: novelId,
                title: title,
                chapterNumber: chapterNumber,
                sourceUrl: sourceUrl,
                localPath: localPath,
                progress: progress,
                readAt: readAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NovelChapterEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (novelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.novelId,
                                referencedTable:
                                    $$NovelChapterEntriesTableReferences
                                        ._novelIdTable(db),
                                referencedColumn:
                                    $$NovelChapterEntriesTableReferences
                                        ._novelIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NovelChapterEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NovelChapterEntriesTable,
      NovelChapterEntry,
      $$NovelChapterEntriesTableFilterComposer,
      $$NovelChapterEntriesTableOrderingComposer,
      $$NovelChapterEntriesTableAnnotationComposer,
      $$NovelChapterEntriesTableCreateCompanionBuilder,
      $$NovelChapterEntriesTableUpdateCompanionBuilder,
      (NovelChapterEntry, $$NovelChapterEntriesTableReferences),
      NovelChapterEntry,
      PrefetchHooks Function({bool novelId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SchemaMetadataTableTableManager get schemaMetadata =>
      $$SchemaMetadataTableTableManager(_db, _db.schemaMetadata);
  $$SearchHistoryEntriesTableTableManager get searchHistoryEntries =>
      $$SearchHistoryEntriesTableTableManager(_db, _db.searchHistoryEntries);
  $$CachedResponsesTableTableManager get cachedResponses =>
      $$CachedResponsesTableTableManager(_db, _db.cachedResponses);
  $$SourceHealthEntriesTableTableManager get sourceHealthEntries =>
      $$SourceHealthEntriesTableTableManager(_db, _db.sourceHealthEntries);
  $$NotificationSubscriptionsTableTableManager get notificationSubscriptions =>
      $$NotificationSubscriptionsTableTableManager(
        _db,
        _db.notificationSubscriptions,
      );
  $$AppNotificationsTableTableManager get appNotifications =>
      $$AppNotificationsTableTableManager(_db, _db.appNotifications);
  $$WatchOrderCacheEntriesTableTableManager get watchOrderCacheEntries =>
      $$WatchOrderCacheEntriesTableTableManager(
        _db,
        _db.watchOrderCacheEntries,
      );
  $$NovelLibraryEntriesTableTableManager get novelLibraryEntries =>
      $$NovelLibraryEntriesTableTableManager(_db, _db.novelLibraryEntries);
  $$NovelChapterEntriesTableTableManager get novelChapterEntries =>
      $$NovelChapterEntriesTableTableManager(_db, _db.novelChapterEntries);
}
