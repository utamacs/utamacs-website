// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedNoticesTable extends CachedNotices
    with TableInfo<$CachedNoticesTable, CachedNotice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedNoticesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _societyIdMeta = const VerificationMeta(
    'societyId',
  );
  @override
  late final GeneratedColumn<String> societyId = GeneratedColumn<String>(
    'society_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('general'),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    societyId,
    title,
    body,
    category,
    isPinned,
    isArchived,
    publishedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_notices';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedNotice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('society_id')) {
      context.handle(
        _societyIdMeta,
        societyId.isAcceptableOrUnknown(data['society_id']!, _societyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_societyIdMeta);
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
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedNotice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedNotice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      societyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}society_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedNoticesTable createAlias(String alias) {
    return $CachedNoticesTable(attachedDatabase, alias);
  }
}

class CachedNotice extends DataClass implements Insertable<CachedNotice> {
  final String id;
  final String societyId;
  final String title;
  final String body;
  final String category;
  final bool isPinned;
  final bool isArchived;
  final DateTime publishedAt;
  final DateTime cachedAt;
  const CachedNotice({
    required this.id,
    required this.societyId,
    required this.title,
    required this.body,
    required this.category,
    required this.isPinned,
    required this.isArchived,
    required this.publishedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['society_id'] = Variable<String>(societyId);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['category'] = Variable<String>(category);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_archived'] = Variable<bool>(isArchived);
    map['published_at'] = Variable<DateTime>(publishedAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedNoticesCompanion toCompanion(bool nullToAbsent) {
    return CachedNoticesCompanion(
      id: Value(id),
      societyId: Value(societyId),
      title: Value(title),
      body: Value(body),
      category: Value(category),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
      publishedAt: Value(publishedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedNotice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedNotice(
      id: serializer.fromJson<String>(json['id']),
      societyId: serializer.fromJson<String>(json['societyId']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      category: serializer.fromJson<String>(json['category']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'societyId': serializer.toJson<String>(societyId),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'category': serializer.toJson<String>(category),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isArchived': serializer.toJson<bool>(isArchived),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedNotice copyWith({
    String? id,
    String? societyId,
    String? title,
    String? body,
    String? category,
    bool? isPinned,
    bool? isArchived,
    DateTime? publishedAt,
    DateTime? cachedAt,
  }) => CachedNotice(
    id: id ?? this.id,
    societyId: societyId ?? this.societyId,
    title: title ?? this.title,
    body: body ?? this.body,
    category: category ?? this.category,
    isPinned: isPinned ?? this.isPinned,
    isArchived: isArchived ?? this.isArchived,
    publishedAt: publishedAt ?? this.publishedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedNotice copyWithCompanion(CachedNoticesCompanion data) {
    return CachedNotice(
      id: data.id.present ? data.id.value : this.id,
      societyId: data.societyId.present ? data.societyId.value : this.societyId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      category: data.category.present ? data.category.value : this.category,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedNotice(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('category: $category, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    societyId,
    title,
    body,
    category,
    isPinned,
    isArchived,
    publishedAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedNotice &&
          other.id == this.id &&
          other.societyId == this.societyId &&
          other.title == this.title &&
          other.body == this.body &&
          other.category == this.category &&
          other.isPinned == this.isPinned &&
          other.isArchived == this.isArchived &&
          other.publishedAt == this.publishedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedNoticesCompanion extends UpdateCompanion<CachedNotice> {
  final Value<String> id;
  final Value<String> societyId;
  final Value<String> title;
  final Value<String> body;
  final Value<String> category;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<DateTime> publishedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedNoticesCompanion({
    this.id = const Value.absent(),
    this.societyId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.category = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedNoticesCompanion.insert({
    required String id,
    required String societyId,
    required String title,
    required String body,
    this.category = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime publishedAt,
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       societyId = Value(societyId),
       title = Value(title),
       body = Value(body),
       publishedAt = Value(publishedAt);
  static Insertable<CachedNotice> custom({
    Expression<String>? id,
    Expression<String>? societyId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? category,
    Expression<bool>? isPinned,
    Expression<bool>? isArchived,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (societyId != null) 'society_id': societyId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (category != null) 'category': category,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isArchived != null) 'is_archived': isArchived,
      if (publishedAt != null) 'published_at': publishedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedNoticesCompanion copyWith({
    Value<String>? id,
    Value<String>? societyId,
    Value<String>? title,
    Value<String>? body,
    Value<String>? category,
    Value<bool>? isPinned,
    Value<bool>? isArchived,
    Value<DateTime>? publishedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedNoticesCompanion(
      id: id ?? this.id,
      societyId: societyId ?? this.societyId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      publishedAt: publishedAt ?? this.publishedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (societyId.present) {
      map['society_id'] = Variable<String>(societyId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedNoticesCompanion(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('category: $category, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedComplaintsTable extends CachedComplaints
    with TableInfo<$CachedComplaintsTable, CachedComplaint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedComplaintsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _societyIdMeta = const VerificationMeta(
    'societyId',
  );
  @override
  late final GeneratedColumn<String> societyId = GeneratedColumn<String>(
    'society_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<String> unitId = GeneratedColumn<String>(
    'unit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    societyId,
    unitId,
    title,
    category,
    priority,
    status,
    description,
    createdAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_complaints';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedComplaint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('society_id')) {
      context.handle(
        _societyIdMeta,
        societyId.isAcceptableOrUnknown(data['society_id']!, _societyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_societyIdMeta);
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
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
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedComplaint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedComplaint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      societyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}society_id'],
      )!,
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedComplaintsTable createAlias(String alias) {
    return $CachedComplaintsTable(attachedDatabase, alias);
  }
}

class CachedComplaint extends DataClass implements Insertable<CachedComplaint> {
  final String id;
  final String societyId;
  final String? unitId;
  final String title;
  final String category;
  final String priority;
  final String status;
  final String? description;
  final DateTime createdAt;
  final DateTime cachedAt;
  const CachedComplaint({
    required this.id,
    required this.societyId,
    this.unitId,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    this.description,
    required this.createdAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['society_id'] = Variable<String>(societyId);
    if (!nullToAbsent || unitId != null) {
      map['unit_id'] = Variable<String>(unitId);
    }
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['priority'] = Variable<String>(priority);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedComplaintsCompanion toCompanion(bool nullToAbsent) {
    return CachedComplaintsCompanion(
      id: Value(id),
      societyId: Value(societyId),
      unitId: unitId == null && nullToAbsent
          ? const Value.absent()
          : Value(unitId),
      title: Value(title),
      category: Value(category),
      priority: Value(priority),
      status: Value(status),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedComplaint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedComplaint(
      id: serializer.fromJson<String>(json['id']),
      societyId: serializer.fromJson<String>(json['societyId']),
      unitId: serializer.fromJson<String?>(json['unitId']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      priority: serializer.fromJson<String>(json['priority']),
      status: serializer.fromJson<String>(json['status']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'societyId': serializer.toJson<String>(societyId),
      'unitId': serializer.toJson<String?>(unitId),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'priority': serializer.toJson<String>(priority),
      'status': serializer.toJson<String>(status),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedComplaint copyWith({
    String? id,
    String? societyId,
    Value<String?> unitId = const Value.absent(),
    String? title,
    String? category,
    String? priority,
    String? status,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
    DateTime? cachedAt,
  }) => CachedComplaint(
    id: id ?? this.id,
    societyId: societyId ?? this.societyId,
    unitId: unitId.present ? unitId.value : this.unitId,
    title: title ?? this.title,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedComplaint copyWithCompanion(CachedComplaintsCompanion data) {
    return CachedComplaint(
      id: data.id.present ? data.id.value : this.id,
      societyId: data.societyId.present ? data.societyId.value : this.societyId,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedComplaint(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('unitId: $unitId, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    societyId,
    unitId,
    title,
    category,
    priority,
    status,
    description,
    createdAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedComplaint &&
          other.id == this.id &&
          other.societyId == this.societyId &&
          other.unitId == this.unitId &&
          other.title == this.title &&
          other.category == this.category &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.cachedAt == this.cachedAt);
}

class CachedComplaintsCompanion extends UpdateCompanion<CachedComplaint> {
  final Value<String> id;
  final Value<String> societyId;
  final Value<String?> unitId;
  final Value<String> title;
  final Value<String> category;
  final Value<String> priority;
  final Value<String> status;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedComplaintsCompanion({
    this.id = const Value.absent(),
    this.societyId = const Value.absent(),
    this.unitId = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedComplaintsCompanion.insert({
    required String id,
    required String societyId,
    this.unitId = const Value.absent(),
    required String title,
    required String category,
    required String priority,
    this.status = const Value.absent(),
    this.description = const Value.absent(),
    required DateTime createdAt,
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       societyId = Value(societyId),
       title = Value(title),
       category = Value(category),
       priority = Value(priority),
       createdAt = Value(createdAt);
  static Insertable<CachedComplaint> custom({
    Expression<String>? id,
    Expression<String>? societyId,
    Expression<String>? unitId,
    Expression<String>? title,
    Expression<String>? category,
    Expression<String>? priority,
    Expression<String>? status,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (societyId != null) 'society_id': societyId,
      if (unitId != null) 'unit_id': unitId,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedComplaintsCompanion copyWith({
    Value<String>? id,
    Value<String>? societyId,
    Value<String?>? unitId,
    Value<String>? title,
    Value<String>? category,
    Value<String>? priority,
    Value<String>? status,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedComplaintsCompanion(
      id: id ?? this.id,
      societyId: societyId ?? this.societyId,
      unitId: unitId ?? this.unitId,
      title: title ?? this.title,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (societyId.present) {
      map['society_id'] = Variable<String>(societyId.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<String>(unitId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedComplaintsCompanion(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('unitId: $unitId, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDuesTable extends CachedDues
    with TableInfo<$CachedDuesTable, CachedDue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _societyIdMeta = const VerificationMeta(
    'societyId',
  );
  @override
  late final GeneratedColumn<String> societyId = GeneratedColumn<String>(
    'society_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<String> unitId = GeneratedColumn<String>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    societyId,
    unitId,
    amount,
    description,
    status,
    dueDate,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_dues';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('society_id')) {
      context.handle(
        _societyIdMeta,
        societyId.isAcceptableOrUnknown(data['society_id']!, _societyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_societyIdMeta);
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedDue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDue(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      societyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}society_id'],
      )!,
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedDuesTable createAlias(String alias) {
    return $CachedDuesTable(attachedDatabase, alias);
  }
}

class CachedDue extends DataClass implements Insertable<CachedDue> {
  final String id;
  final String societyId;
  final String unitId;
  final double amount;
  final String? description;
  final String status;
  final DateTime dueDate;
  final DateTime cachedAt;
  const CachedDue({
    required this.id,
    required this.societyId,
    required this.unitId,
    required this.amount,
    this.description,
    required this.status,
    required this.dueDate,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['society_id'] = Variable<String>(societyId);
    map['unit_id'] = Variable<String>(unitId);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedDuesCompanion toCompanion(bool nullToAbsent) {
    return CachedDuesCompanion(
      id: Value(id),
      societyId: Value(societyId),
      unitId: Value(unitId),
      amount: Value(amount),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      dueDate: Value(dueDate),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedDue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDue(
      id: serializer.fromJson<String>(json['id']),
      societyId: serializer.fromJson<String>(json['societyId']),
      unitId: serializer.fromJson<String>(json['unitId']),
      amount: serializer.fromJson<double>(json['amount']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'societyId': serializer.toJson<String>(societyId),
      'unitId': serializer.toJson<String>(unitId),
      'amount': serializer.toJson<double>(amount),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedDue copyWith({
    String? id,
    String? societyId,
    String? unitId,
    double? amount,
    Value<String?> description = const Value.absent(),
    String? status,
    DateTime? dueDate,
    DateTime? cachedAt,
  }) => CachedDue(
    id: id ?? this.id,
    societyId: societyId ?? this.societyId,
    unitId: unitId ?? this.unitId,
    amount: amount ?? this.amount,
    description: description.present ? description.value : this.description,
    status: status ?? this.status,
    dueDate: dueDate ?? this.dueDate,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedDue copyWithCompanion(CachedDuesCompanion data) {
    return CachedDue(
      id: data.id.present ? data.id.value : this.id,
      societyId: data.societyId.present ? data.societyId.value : this.societyId,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      amount: data.amount.present ? data.amount.value : this.amount,
      description: data.description.present
          ? data.description.value
          : this.description,
      status: data.status.present ? data.status.value : this.status,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDue(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('unitId: $unitId, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('dueDate: $dueDate, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    societyId,
    unitId,
    amount,
    description,
    status,
    dueDate,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDue &&
          other.id == this.id &&
          other.societyId == this.societyId &&
          other.unitId == this.unitId &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.status == this.status &&
          other.dueDate == this.dueDate &&
          other.cachedAt == this.cachedAt);
}

class CachedDuesCompanion extends UpdateCompanion<CachedDue> {
  final Value<String> id;
  final Value<String> societyId;
  final Value<String> unitId;
  final Value<double> amount;
  final Value<String?> description;
  final Value<String> status;
  final Value<DateTime> dueDate;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedDuesCompanion({
    this.id = const Value.absent(),
    this.societyId = const Value.absent(),
    this.unitId = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDuesCompanion.insert({
    required String id,
    required String societyId,
    required String unitId,
    required double amount,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime dueDate,
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       societyId = Value(societyId),
       unitId = Value(unitId),
       amount = Value(amount),
       dueDate = Value(dueDate);
  static Insertable<CachedDue> custom({
    Expression<String>? id,
    Expression<String>? societyId,
    Expression<String>? unitId,
    Expression<double>? amount,
    Expression<String>? description,
    Expression<String>? status,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (societyId != null) 'society_id': societyId,
      if (unitId != null) 'unit_id': unitId,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (dueDate != null) 'due_date': dueDate,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDuesCompanion copyWith({
    Value<String>? id,
    Value<String>? societyId,
    Value<String>? unitId,
    Value<double>? amount,
    Value<String?>? description,
    Value<String>? status,
    Value<DateTime>? dueDate,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedDuesCompanion(
      id: id ?? this.id,
      societyId: societyId ?? this.societyId,
      unitId: unitId ?? this.unitId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (societyId.present) {
      map['society_id'] = Variable<String>(societyId.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<String>(unitId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDuesCompanion(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('unitId: $unitId, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('dueDate: $dueDate, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedVisitorPassesTable extends CachedVisitorPasses
    with TableInfo<$CachedVisitorPassesTable, CachedVisitorPass> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVisitorPassesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _societyIdMeta = const VerificationMeta(
    'societyId',
  );
  @override
  late final GeneratedColumn<String> societyId = GeneratedColumn<String>(
    'society_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostUnitIdMeta = const VerificationMeta(
    'hostUnitId',
  );
  @override
  late final GeneratedColumn<String> hostUnitId = GeneratedColumn<String>(
    'host_unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitorNameMeta = const VerificationMeta(
    'visitorName',
  );
  @override
  late final GeneratedColumn<String> visitorName = GeneratedColumn<String>(
    'visitor_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitorPhoneMeta = const VerificationMeta(
    'visitorPhone',
  );
  @override
  late final GeneratedColumn<String> visitorPhone = GeneratedColumn<String>(
    'visitor_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _validFromMeta = const VerificationMeta(
    'validFrom',
  );
  @override
  late final GeneratedColumn<DateTime> validFrom = GeneratedColumn<DateTime>(
    'valid_from',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validUntilMeta = const VerificationMeta(
    'validUntil',
  );
  @override
  late final GeneratedColumn<DateTime> validUntil = GeneratedColumn<DateTime>(
    'valid_until',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    societyId,
    hostUnitId,
    visitorName,
    visitorPhone,
    purpose,
    status,
    validFrom,
    validUntil,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_visitor_passes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedVisitorPass> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('society_id')) {
      context.handle(
        _societyIdMeta,
        societyId.isAcceptableOrUnknown(data['society_id']!, _societyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_societyIdMeta);
    }
    if (data.containsKey('host_unit_id')) {
      context.handle(
        _hostUnitIdMeta,
        hostUnitId.isAcceptableOrUnknown(
          data['host_unit_id']!,
          _hostUnitIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hostUnitIdMeta);
    }
    if (data.containsKey('visitor_name')) {
      context.handle(
        _visitorNameMeta,
        visitorName.isAcceptableOrUnknown(
          data['visitor_name']!,
          _visitorNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_visitorNameMeta);
    }
    if (data.containsKey('visitor_phone')) {
      context.handle(
        _visitorPhoneMeta,
        visitorPhone.isAcceptableOrUnknown(
          data['visitor_phone']!,
          _visitorPhoneMeta,
        ),
      );
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    } else if (isInserting) {
      context.missing(_purposeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('valid_from')) {
      context.handle(
        _validFromMeta,
        validFrom.isAcceptableOrUnknown(data['valid_from']!, _validFromMeta),
      );
    } else if (isInserting) {
      context.missing(_validFromMeta);
    }
    if (data.containsKey('valid_until')) {
      context.handle(
        _validUntilMeta,
        validUntil.isAcceptableOrUnknown(data['valid_until']!, _validUntilMeta),
      );
    } else if (isInserting) {
      context.missing(_validUntilMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedVisitorPass map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVisitorPass(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      societyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}society_id'],
      )!,
      hostUnitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_unit_id'],
      )!,
      visitorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visitor_name'],
      )!,
      visitorPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visitor_phone'],
      ),
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      validFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}valid_from'],
      )!,
      validUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}valid_until'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedVisitorPassesTable createAlias(String alias) {
    return $CachedVisitorPassesTable(attachedDatabase, alias);
  }
}

class CachedVisitorPass extends DataClass
    implements Insertable<CachedVisitorPass> {
  final String id;
  final String societyId;
  final String hostUnitId;
  final String visitorName;
  final String? visitorPhone;
  final String purpose;
  final String status;
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime cachedAt;
  const CachedVisitorPass({
    required this.id,
    required this.societyId,
    required this.hostUnitId,
    required this.visitorName,
    this.visitorPhone,
    required this.purpose,
    required this.status,
    required this.validFrom,
    required this.validUntil,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['society_id'] = Variable<String>(societyId);
    map['host_unit_id'] = Variable<String>(hostUnitId);
    map['visitor_name'] = Variable<String>(visitorName);
    if (!nullToAbsent || visitorPhone != null) {
      map['visitor_phone'] = Variable<String>(visitorPhone);
    }
    map['purpose'] = Variable<String>(purpose);
    map['status'] = Variable<String>(status);
    map['valid_from'] = Variable<DateTime>(validFrom);
    map['valid_until'] = Variable<DateTime>(validUntil);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedVisitorPassesCompanion toCompanion(bool nullToAbsent) {
    return CachedVisitorPassesCompanion(
      id: Value(id),
      societyId: Value(societyId),
      hostUnitId: Value(hostUnitId),
      visitorName: Value(visitorName),
      visitorPhone: visitorPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(visitorPhone),
      purpose: Value(purpose),
      status: Value(status),
      validFrom: Value(validFrom),
      validUntil: Value(validUntil),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedVisitorPass.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVisitorPass(
      id: serializer.fromJson<String>(json['id']),
      societyId: serializer.fromJson<String>(json['societyId']),
      hostUnitId: serializer.fromJson<String>(json['hostUnitId']),
      visitorName: serializer.fromJson<String>(json['visitorName']),
      visitorPhone: serializer.fromJson<String?>(json['visitorPhone']),
      purpose: serializer.fromJson<String>(json['purpose']),
      status: serializer.fromJson<String>(json['status']),
      validFrom: serializer.fromJson<DateTime>(json['validFrom']),
      validUntil: serializer.fromJson<DateTime>(json['validUntil']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'societyId': serializer.toJson<String>(societyId),
      'hostUnitId': serializer.toJson<String>(hostUnitId),
      'visitorName': serializer.toJson<String>(visitorName),
      'visitorPhone': serializer.toJson<String?>(visitorPhone),
      'purpose': serializer.toJson<String>(purpose),
      'status': serializer.toJson<String>(status),
      'validFrom': serializer.toJson<DateTime>(validFrom),
      'validUntil': serializer.toJson<DateTime>(validUntil),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedVisitorPass copyWith({
    String? id,
    String? societyId,
    String? hostUnitId,
    String? visitorName,
    Value<String?> visitorPhone = const Value.absent(),
    String? purpose,
    String? status,
    DateTime? validFrom,
    DateTime? validUntil,
    DateTime? cachedAt,
  }) => CachedVisitorPass(
    id: id ?? this.id,
    societyId: societyId ?? this.societyId,
    hostUnitId: hostUnitId ?? this.hostUnitId,
    visitorName: visitorName ?? this.visitorName,
    visitorPhone: visitorPhone.present ? visitorPhone.value : this.visitorPhone,
    purpose: purpose ?? this.purpose,
    status: status ?? this.status,
    validFrom: validFrom ?? this.validFrom,
    validUntil: validUntil ?? this.validUntil,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedVisitorPass copyWithCompanion(CachedVisitorPassesCompanion data) {
    return CachedVisitorPass(
      id: data.id.present ? data.id.value : this.id,
      societyId: data.societyId.present ? data.societyId.value : this.societyId,
      hostUnitId: data.hostUnitId.present
          ? data.hostUnitId.value
          : this.hostUnitId,
      visitorName: data.visitorName.present
          ? data.visitorName.value
          : this.visitorName,
      visitorPhone: data.visitorPhone.present
          ? data.visitorPhone.value
          : this.visitorPhone,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      status: data.status.present ? data.status.value : this.status,
      validFrom: data.validFrom.present ? data.validFrom.value : this.validFrom,
      validUntil: data.validUntil.present
          ? data.validUntil.value
          : this.validUntil,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVisitorPass(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('hostUnitId: $hostUnitId, ')
          ..write('visitorName: $visitorName, ')
          ..write('visitorPhone: $visitorPhone, ')
          ..write('purpose: $purpose, ')
          ..write('status: $status, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    societyId,
    hostUnitId,
    visitorName,
    visitorPhone,
    purpose,
    status,
    validFrom,
    validUntil,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVisitorPass &&
          other.id == this.id &&
          other.societyId == this.societyId &&
          other.hostUnitId == this.hostUnitId &&
          other.visitorName == this.visitorName &&
          other.visitorPhone == this.visitorPhone &&
          other.purpose == this.purpose &&
          other.status == this.status &&
          other.validFrom == this.validFrom &&
          other.validUntil == this.validUntil &&
          other.cachedAt == this.cachedAt);
}

class CachedVisitorPassesCompanion extends UpdateCompanion<CachedVisitorPass> {
  final Value<String> id;
  final Value<String> societyId;
  final Value<String> hostUnitId;
  final Value<String> visitorName;
  final Value<String?> visitorPhone;
  final Value<String> purpose;
  final Value<String> status;
  final Value<DateTime> validFrom;
  final Value<DateTime> validUntil;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedVisitorPassesCompanion({
    this.id = const Value.absent(),
    this.societyId = const Value.absent(),
    this.hostUnitId = const Value.absent(),
    this.visitorName = const Value.absent(),
    this.visitorPhone = const Value.absent(),
    this.purpose = const Value.absent(),
    this.status = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validUntil = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedVisitorPassesCompanion.insert({
    required String id,
    required String societyId,
    required String hostUnitId,
    required String visitorName,
    this.visitorPhone = const Value.absent(),
    required String purpose,
    this.status = const Value.absent(),
    required DateTime validFrom,
    required DateTime validUntil,
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       societyId = Value(societyId),
       hostUnitId = Value(hostUnitId),
       visitorName = Value(visitorName),
       purpose = Value(purpose),
       validFrom = Value(validFrom),
       validUntil = Value(validUntil);
  static Insertable<CachedVisitorPass> custom({
    Expression<String>? id,
    Expression<String>? societyId,
    Expression<String>? hostUnitId,
    Expression<String>? visitorName,
    Expression<String>? visitorPhone,
    Expression<String>? purpose,
    Expression<String>? status,
    Expression<DateTime>? validFrom,
    Expression<DateTime>? validUntil,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (societyId != null) 'society_id': societyId,
      if (hostUnitId != null) 'host_unit_id': hostUnitId,
      if (visitorName != null) 'visitor_name': visitorName,
      if (visitorPhone != null) 'visitor_phone': visitorPhone,
      if (purpose != null) 'purpose': purpose,
      if (status != null) 'status': status,
      if (validFrom != null) 'valid_from': validFrom,
      if (validUntil != null) 'valid_until': validUntil,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedVisitorPassesCompanion copyWith({
    Value<String>? id,
    Value<String>? societyId,
    Value<String>? hostUnitId,
    Value<String>? visitorName,
    Value<String?>? visitorPhone,
    Value<String>? purpose,
    Value<String>? status,
    Value<DateTime>? validFrom,
    Value<DateTime>? validUntil,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedVisitorPassesCompanion(
      id: id ?? this.id,
      societyId: societyId ?? this.societyId,
      hostUnitId: hostUnitId ?? this.hostUnitId,
      visitorName: visitorName ?? this.visitorName,
      visitorPhone: visitorPhone ?? this.visitorPhone,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (societyId.present) {
      map['society_id'] = Variable<String>(societyId.value);
    }
    if (hostUnitId.present) {
      map['host_unit_id'] = Variable<String>(hostUnitId.value);
    }
    if (visitorName.present) {
      map['visitor_name'] = Variable<String>(visitorName.value);
    }
    if (visitorPhone.present) {
      map['visitor_phone'] = Variable<String>(visitorPhone.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (validFrom.present) {
      map['valid_from'] = Variable<DateTime>(validFrom.value);
    }
    if (validUntil.present) {
      map['valid_until'] = Variable<DateTime>(validUntil.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVisitorPassesCompanion(')
          ..write('id: $id, ')
          ..write('societyId: $societyId, ')
          ..write('hostUnitId: $hostUnitId, ')
          ..write('visitorName: $visitorName, ')
          ..write('visitorPhone: $visitorPhone, ')
          ..write('purpose: $purpose, ')
          ..write('status: $status, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedNoticesTable cachedNotices = $CachedNoticesTable(this);
  late final $CachedComplaintsTable cachedComplaints = $CachedComplaintsTable(
    this,
  );
  late final $CachedDuesTable cachedDues = $CachedDuesTable(this);
  late final $CachedVisitorPassesTable cachedVisitorPasses =
      $CachedVisitorPassesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedNotices,
    cachedComplaints,
    cachedDues,
    cachedVisitorPasses,
  ];
}

typedef $$CachedNoticesTableCreateCompanionBuilder =
    CachedNoticesCompanion Function({
      required String id,
      required String societyId,
      required String title,
      required String body,
      Value<String> category,
      Value<bool> isPinned,
      Value<bool> isArchived,
      required DateTime publishedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });
typedef $$CachedNoticesTableUpdateCompanionBuilder =
    CachedNoticesCompanion Function({
      Value<String> id,
      Value<String> societyId,
      Value<String> title,
      Value<String> body,
      Value<String> category,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<DateTime> publishedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedNoticesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedNoticesTable> {
  $$CachedNoticesTableFilterComposer({
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

  ColumnFilters<String> get societyId => $composableBuilder(
    column: $table.societyId,
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

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedNoticesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedNoticesTable> {
  $$CachedNoticesTableOrderingComposer({
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

  ColumnOrderings<String> get societyId => $composableBuilder(
    column: $table.societyId,
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

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedNoticesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedNoticesTable> {
  $$CachedNoticesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get societyId =>
      $composableBuilder(column: $table.societyId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedNoticesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedNoticesTable,
          CachedNotice,
          $$CachedNoticesTableFilterComposer,
          $$CachedNoticesTableOrderingComposer,
          $$CachedNoticesTableAnnotationComposer,
          $$CachedNoticesTableCreateCompanionBuilder,
          $$CachedNoticesTableUpdateCompanionBuilder,
          (
            CachedNotice,
            BaseReferences<_$AppDatabase, $CachedNoticesTable, CachedNotice>,
          ),
          CachedNotice,
          PrefetchHooks Function()
        > {
  $$CachedNoticesTableTableManager(_$AppDatabase db, $CachedNoticesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedNoticesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedNoticesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedNoticesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> societyId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedNoticesCompanion(
                id: id,
                societyId: societyId,
                title: title,
                body: body,
                category: category,
                isPinned: isPinned,
                isArchived: isArchived,
                publishedAt: publishedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String societyId,
                required String title,
                required String body,
                Value<String> category = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required DateTime publishedAt,
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedNoticesCompanion.insert(
                id: id,
                societyId: societyId,
                title: title,
                body: body,
                category: category,
                isPinned: isPinned,
                isArchived: isArchived,
                publishedAt: publishedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedNoticesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedNoticesTable,
      CachedNotice,
      $$CachedNoticesTableFilterComposer,
      $$CachedNoticesTableOrderingComposer,
      $$CachedNoticesTableAnnotationComposer,
      $$CachedNoticesTableCreateCompanionBuilder,
      $$CachedNoticesTableUpdateCompanionBuilder,
      (
        CachedNotice,
        BaseReferences<_$AppDatabase, $CachedNoticesTable, CachedNotice>,
      ),
      CachedNotice,
      PrefetchHooks Function()
    >;
typedef $$CachedComplaintsTableCreateCompanionBuilder =
    CachedComplaintsCompanion Function({
      required String id,
      required String societyId,
      Value<String?> unitId,
      required String title,
      required String category,
      required String priority,
      Value<String> status,
      Value<String?> description,
      required DateTime createdAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });
typedef $$CachedComplaintsTableUpdateCompanionBuilder =
    CachedComplaintsCompanion Function({
      Value<String> id,
      Value<String> societyId,
      Value<String?> unitId,
      Value<String> title,
      Value<String> category,
      Value<String> priority,
      Value<String> status,
      Value<String?> description,
      Value<DateTime> createdAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedComplaintsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedComplaintsTable> {
  $$CachedComplaintsTableFilterComposer({
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

  ColumnFilters<String> get societyId => $composableBuilder(
    column: $table.societyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedComplaintsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedComplaintsTable> {
  $$CachedComplaintsTableOrderingComposer({
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

  ColumnOrderings<String> get societyId => $composableBuilder(
    column: $table.societyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedComplaintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedComplaintsTable> {
  $$CachedComplaintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get societyId =>
      $composableBuilder(column: $table.societyId, builder: (column) => column);

  GeneratedColumn<String> get unitId =>
      $composableBuilder(column: $table.unitId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedComplaintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedComplaintsTable,
          CachedComplaint,
          $$CachedComplaintsTableFilterComposer,
          $$CachedComplaintsTableOrderingComposer,
          $$CachedComplaintsTableAnnotationComposer,
          $$CachedComplaintsTableCreateCompanionBuilder,
          $$CachedComplaintsTableUpdateCompanionBuilder,
          (
            CachedComplaint,
            BaseReferences<
              _$AppDatabase,
              $CachedComplaintsTable,
              CachedComplaint
            >,
          ),
          CachedComplaint,
          PrefetchHooks Function()
        > {
  $$CachedComplaintsTableTableManager(
    _$AppDatabase db,
    $CachedComplaintsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedComplaintsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedComplaintsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedComplaintsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> societyId = const Value.absent(),
                Value<String?> unitId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedComplaintsCompanion(
                id: id,
                societyId: societyId,
                unitId: unitId,
                title: title,
                category: category,
                priority: priority,
                status: status,
                description: description,
                createdAt: createdAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String societyId,
                Value<String?> unitId = const Value.absent(),
                required String title,
                required String category,
                required String priority,
                Value<String> status = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedComplaintsCompanion.insert(
                id: id,
                societyId: societyId,
                unitId: unitId,
                title: title,
                category: category,
                priority: priority,
                status: status,
                description: description,
                createdAt: createdAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedComplaintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedComplaintsTable,
      CachedComplaint,
      $$CachedComplaintsTableFilterComposer,
      $$CachedComplaintsTableOrderingComposer,
      $$CachedComplaintsTableAnnotationComposer,
      $$CachedComplaintsTableCreateCompanionBuilder,
      $$CachedComplaintsTableUpdateCompanionBuilder,
      (
        CachedComplaint,
        BaseReferences<_$AppDatabase, $CachedComplaintsTable, CachedComplaint>,
      ),
      CachedComplaint,
      PrefetchHooks Function()
    >;
typedef $$CachedDuesTableCreateCompanionBuilder =
    CachedDuesCompanion Function({
      required String id,
      required String societyId,
      required String unitId,
      required double amount,
      Value<String?> description,
      Value<String> status,
      required DateTime dueDate,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });
typedef $$CachedDuesTableUpdateCompanionBuilder =
    CachedDuesCompanion Function({
      Value<String> id,
      Value<String> societyId,
      Value<String> unitId,
      Value<double> amount,
      Value<String?> description,
      Value<String> status,
      Value<DateTime> dueDate,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedDuesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDuesTable> {
  $$CachedDuesTableFilterComposer({
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

  ColumnFilters<String> get societyId => $composableBuilder(
    column: $table.societyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDuesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDuesTable> {
  $$CachedDuesTableOrderingComposer({
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

  ColumnOrderings<String> get societyId => $composableBuilder(
    column: $table.societyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDuesTable> {
  $$CachedDuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get societyId =>
      $composableBuilder(column: $table.societyId, builder: (column) => column);

  GeneratedColumn<String> get unitId =>
      $composableBuilder(column: $table.unitId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedDuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDuesTable,
          CachedDue,
          $$CachedDuesTableFilterComposer,
          $$CachedDuesTableOrderingComposer,
          $$CachedDuesTableAnnotationComposer,
          $$CachedDuesTableCreateCompanionBuilder,
          $$CachedDuesTableUpdateCompanionBuilder,
          (
            CachedDue,
            BaseReferences<_$AppDatabase, $CachedDuesTable, CachedDue>,
          ),
          CachedDue,
          PrefetchHooks Function()
        > {
  $$CachedDuesTableTableManager(_$AppDatabase db, $CachedDuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> societyId = const Value.absent(),
                Value<String> unitId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDuesCompanion(
                id: id,
                societyId: societyId,
                unitId: unitId,
                amount: amount,
                description: description,
                status: status,
                dueDate: dueDate,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String societyId,
                required String unitId,
                required double amount,
                Value<String?> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime dueDate,
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDuesCompanion.insert(
                id: id,
                societyId: societyId,
                unitId: unitId,
                amount: amount,
                description: description,
                status: status,
                dueDate: dueDate,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDuesTable,
      CachedDue,
      $$CachedDuesTableFilterComposer,
      $$CachedDuesTableOrderingComposer,
      $$CachedDuesTableAnnotationComposer,
      $$CachedDuesTableCreateCompanionBuilder,
      $$CachedDuesTableUpdateCompanionBuilder,
      (CachedDue, BaseReferences<_$AppDatabase, $CachedDuesTable, CachedDue>),
      CachedDue,
      PrefetchHooks Function()
    >;
typedef $$CachedVisitorPassesTableCreateCompanionBuilder =
    CachedVisitorPassesCompanion Function({
      required String id,
      required String societyId,
      required String hostUnitId,
      required String visitorName,
      Value<String?> visitorPhone,
      required String purpose,
      Value<String> status,
      required DateTime validFrom,
      required DateTime validUntil,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });
typedef $$CachedVisitorPassesTableUpdateCompanionBuilder =
    CachedVisitorPassesCompanion Function({
      Value<String> id,
      Value<String> societyId,
      Value<String> hostUnitId,
      Value<String> visitorName,
      Value<String?> visitorPhone,
      Value<String> purpose,
      Value<String> status,
      Value<DateTime> validFrom,
      Value<DateTime> validUntil,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedVisitorPassesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedVisitorPassesTable> {
  $$CachedVisitorPassesTableFilterComposer({
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

  ColumnFilters<String> get societyId => $composableBuilder(
    column: $table.societyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostUnitId => $composableBuilder(
    column: $table.hostUnitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visitorName => $composableBuilder(
    column: $table.visitorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visitorPhone => $composableBuilder(
    column: $table.visitorPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedVisitorPassesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedVisitorPassesTable> {
  $$CachedVisitorPassesTableOrderingComposer({
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

  ColumnOrderings<String> get societyId => $composableBuilder(
    column: $table.societyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostUnitId => $composableBuilder(
    column: $table.hostUnitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visitorName => $composableBuilder(
    column: $table.visitorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visitorPhone => $composableBuilder(
    column: $table.visitorPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedVisitorPassesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedVisitorPassesTable> {
  $$CachedVisitorPassesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get societyId =>
      $composableBuilder(column: $table.societyId, builder: (column) => column);

  GeneratedColumn<String> get hostUnitId => $composableBuilder(
    column: $table.hostUnitId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get visitorName => $composableBuilder(
    column: $table.visitorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get visitorPhone => $composableBuilder(
    column: $table.visitorPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get validFrom =>
      $composableBuilder(column: $table.validFrom, builder: (column) => column);

  GeneratedColumn<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedVisitorPassesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedVisitorPassesTable,
          CachedVisitorPass,
          $$CachedVisitorPassesTableFilterComposer,
          $$CachedVisitorPassesTableOrderingComposer,
          $$CachedVisitorPassesTableAnnotationComposer,
          $$CachedVisitorPassesTableCreateCompanionBuilder,
          $$CachedVisitorPassesTableUpdateCompanionBuilder,
          (
            CachedVisitorPass,
            BaseReferences<
              _$AppDatabase,
              $CachedVisitorPassesTable,
              CachedVisitorPass
            >,
          ),
          CachedVisitorPass,
          PrefetchHooks Function()
        > {
  $$CachedVisitorPassesTableTableManager(
    _$AppDatabase db,
    $CachedVisitorPassesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVisitorPassesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVisitorPassesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedVisitorPassesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> societyId = const Value.absent(),
                Value<String> hostUnitId = const Value.absent(),
                Value<String> visitorName = const Value.absent(),
                Value<String?> visitorPhone = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> validFrom = const Value.absent(),
                Value<DateTime> validUntil = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedVisitorPassesCompanion(
                id: id,
                societyId: societyId,
                hostUnitId: hostUnitId,
                visitorName: visitorName,
                visitorPhone: visitorPhone,
                purpose: purpose,
                status: status,
                validFrom: validFrom,
                validUntil: validUntil,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String societyId,
                required String hostUnitId,
                required String visitorName,
                Value<String?> visitorPhone = const Value.absent(),
                required String purpose,
                Value<String> status = const Value.absent(),
                required DateTime validFrom,
                required DateTime validUntil,
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedVisitorPassesCompanion.insert(
                id: id,
                societyId: societyId,
                hostUnitId: hostUnitId,
                visitorName: visitorName,
                visitorPhone: visitorPhone,
                purpose: purpose,
                status: status,
                validFrom: validFrom,
                validUntil: validUntil,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedVisitorPassesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedVisitorPassesTable,
      CachedVisitorPass,
      $$CachedVisitorPassesTableFilterComposer,
      $$CachedVisitorPassesTableOrderingComposer,
      $$CachedVisitorPassesTableAnnotationComposer,
      $$CachedVisitorPassesTableCreateCompanionBuilder,
      $$CachedVisitorPassesTableUpdateCompanionBuilder,
      (
        CachedVisitorPass,
        BaseReferences<
          _$AppDatabase,
          $CachedVisitorPassesTable,
          CachedVisitorPass
        >,
      ),
      CachedVisitorPass,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedNoticesTableTableManager get cachedNotices =>
      $$CachedNoticesTableTableManager(_db, _db.cachedNotices);
  $$CachedComplaintsTableTableManager get cachedComplaints =>
      $$CachedComplaintsTableTableManager(_db, _db.cachedComplaints);
  $$CachedDuesTableTableManager get cachedDues =>
      $$CachedDuesTableTableManager(_db, _db.cachedDues);
  $$CachedVisitorPassesTableTableManager get cachedVisitorPasses =>
      $$CachedVisitorPassesTableTableManager(_db, _db.cachedVisitorPasses);
}
