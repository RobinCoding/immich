// dart format width=80
// ignore_for_file: type=lint
import 'package:drift/drift.dart' as i0;
import 'package:immich_mobile/infrastructure/entities/offline_asset.entity.drift.dart'
    as i1;
import 'package:immich_mobile/infrastructure/entities/offline_asset.entity.dart'
    as i2;
import 'package:immich_mobile/infrastructure/entities/remote_asset.entity.drift.dart'
    as i3;
import 'package:drift/internal/modular.dart' as i4;

typedef $$OfflineAssetEntityTableCreateCompanionBuilder =
    i1.OfflineAssetEntityCompanion Function({
      required String remoteAssetId,
      i0.Value<String?> thumbnailPath,
      i0.Value<String?> fullImagePath,
      i0.Value<String?> videoPath,
      required DateTime downloadedAt,
      required int fileSize,
      required DateTime lastAccessedAt,
    });
typedef $$OfflineAssetEntityTableUpdateCompanionBuilder =
    i1.OfflineAssetEntityCompanion Function({
      i0.Value<String> remoteAssetId,
      i0.Value<String?> thumbnailPath,
      i0.Value<String?> fullImagePath,
      i0.Value<String?> videoPath,
      i0.Value<DateTime> downloadedAt,
      i0.Value<int> fileSize,
      i0.Value<DateTime> lastAccessedAt,
    });

final class $$OfflineAssetEntityTableReferences
    extends
        i0.BaseReferences<
          i0.GeneratedDatabase,
          i1.$OfflineAssetEntityTable,
          i1.OfflineAssetEntityData
        > {
  $$OfflineAssetEntityTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static i3.$RemoteAssetEntityTable _remoteAssetIdTable(
    i0.GeneratedDatabase db,
  ) => i4.ReadDatabaseContainer(db)
      .resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity')
      .createAlias(
        i0.$_aliasNameGenerator(
          i4.ReadDatabaseContainer(db)
              .resultSet<i1.$OfflineAssetEntityTable>('offline_asset_entity')
              .remoteAssetId,
          i4.ReadDatabaseContainer(
            db,
          ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity').id,
        ),
      );

  i3.$$RemoteAssetEntityTableProcessedTableManager get remoteAssetId {
    final $_column = $_itemColumn<String>('remote_asset_id')!;

    final manager = i3
        .$$RemoteAssetEntityTableTableManager(
          $_db,
          i4.ReadDatabaseContainer(
            $_db,
          ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity'),
        )
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_remoteAssetIdTable($_db));
    if (item == null) return manager;
    return i0.ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OfflineAssetEntityTableFilterComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$OfflineAssetEntityTable> {
  $$OfflineAssetEntityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get fullImagePath => $composableBuilder(
    column: $table.fullImagePath,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => i0.ColumnFilters(column),
  );

  i0.ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => i0.ColumnFilters(column),
  );

  i3.$$RemoteAssetEntityTableFilterComposer get remoteAssetId {
    final i3.$$RemoteAssetEntityTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.remoteAssetId,
      referencedTable: i4.ReadDatabaseContainer(
        $db,
      ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity'),
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => i3.$$RemoteAssetEntityTableFilterComposer(
            $db: $db,
            $table: i4.ReadDatabaseContainer(
              $db,
            ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity'),
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OfflineAssetEntityTableOrderingComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$OfflineAssetEntityTable> {
  $$OfflineAssetEntityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get fullImagePath => $composableBuilder(
    column: $table.fullImagePath,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i0.ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => i0.ColumnOrderings(column),
  );

  i3.$$RemoteAssetEntityTableOrderingComposer get remoteAssetId {
    final i3.$$RemoteAssetEntityTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.remoteAssetId,
          referencedTable: i4.ReadDatabaseContainer(
            $db,
          ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity'),
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => i3.$$RemoteAssetEntityTableOrderingComposer(
                $db: $db,
                $table: i4.ReadDatabaseContainer(
                  $db,
                ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity'),
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$OfflineAssetEntityTableAnnotationComposer
    extends i0.Composer<i0.GeneratedDatabase, i1.$OfflineAssetEntityTable> {
  $$OfflineAssetEntityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  i0.GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  i0.GeneratedColumn<String> get fullImagePath => $composableBuilder(
    column: $table.fullImagePath,
    builder: (column) => column,
  );

  i0.GeneratedColumn<String> get videoPath =>
      $composableBuilder(column: $table.videoPath, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  i0.GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  i0.GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  i3.$$RemoteAssetEntityTableAnnotationComposer get remoteAssetId {
    final i3.$$RemoteAssetEntityTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.remoteAssetId,
          referencedTable: i4.ReadDatabaseContainer(
            $db,
          ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity'),
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => i3.$$RemoteAssetEntityTableAnnotationComposer(
                $db: $db,
                $table: i4.ReadDatabaseContainer(
                  $db,
                ).resultSet<i3.$RemoteAssetEntityTable>('remote_asset_entity'),
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$OfflineAssetEntityTableTableManager
    extends
        i0.RootTableManager<
          i0.GeneratedDatabase,
          i1.$OfflineAssetEntityTable,
          i1.OfflineAssetEntityData,
          i1.$$OfflineAssetEntityTableFilterComposer,
          i1.$$OfflineAssetEntityTableOrderingComposer,
          i1.$$OfflineAssetEntityTableAnnotationComposer,
          $$OfflineAssetEntityTableCreateCompanionBuilder,
          $$OfflineAssetEntityTableUpdateCompanionBuilder,
          (i1.OfflineAssetEntityData, i1.$$OfflineAssetEntityTableReferences),
          i1.OfflineAssetEntityData,
          i0.PrefetchHooks Function({bool remoteAssetId})
        > {
  $$OfflineAssetEntityTableTableManager(
    i0.GeneratedDatabase db,
    i1.$OfflineAssetEntityTable table,
  ) : super(
        i0.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => i1
              .$$OfflineAssetEntityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              i1.$$OfflineAssetEntityTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              i1.$$OfflineAssetEntityTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                i0.Value<String> remoteAssetId = const i0.Value.absent(),
                i0.Value<String?> thumbnailPath = const i0.Value.absent(),
                i0.Value<String?> fullImagePath = const i0.Value.absent(),
                i0.Value<String?> videoPath = const i0.Value.absent(),
                i0.Value<DateTime> downloadedAt = const i0.Value.absent(),
                i0.Value<int> fileSize = const i0.Value.absent(),
                i0.Value<DateTime> lastAccessedAt = const i0.Value.absent(),
              }) => i1.OfflineAssetEntityCompanion(
                remoteAssetId: remoteAssetId,
                thumbnailPath: thumbnailPath,
                fullImagePath: fullImagePath,
                videoPath: videoPath,
                downloadedAt: downloadedAt,
                fileSize: fileSize,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                required String remoteAssetId,
                i0.Value<String?> thumbnailPath = const i0.Value.absent(),
                i0.Value<String?> fullImagePath = const i0.Value.absent(),
                i0.Value<String?> videoPath = const i0.Value.absent(),
                required DateTime downloadedAt,
                required int fileSize,
                required DateTime lastAccessedAt,
              }) => i1.OfflineAssetEntityCompanion.insert(
                remoteAssetId: remoteAssetId,
                thumbnailPath: thumbnailPath,
                fullImagePath: fullImagePath,
                videoPath: videoPath,
                downloadedAt: downloadedAt,
                fileSize: fileSize,
                lastAccessedAt: lastAccessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  i1.$$OfflineAssetEntityTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({remoteAssetId = false}) {
            return i0.PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends i0.TableManagerState<
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
                    if (remoteAssetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.remoteAssetId,
                                referencedTable: i1
                                    .$$OfflineAssetEntityTableReferences
                                    ._remoteAssetIdTable(db),
                                referencedColumn: i1
                                    .$$OfflineAssetEntityTableReferences
                                    ._remoteAssetIdTable(db)
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

typedef $$OfflineAssetEntityTableProcessedTableManager =
    i0.ProcessedTableManager<
      i0.GeneratedDatabase,
      i1.$OfflineAssetEntityTable,
      i1.OfflineAssetEntityData,
      i1.$$OfflineAssetEntityTableFilterComposer,
      i1.$$OfflineAssetEntityTableOrderingComposer,
      i1.$$OfflineAssetEntityTableAnnotationComposer,
      $$OfflineAssetEntityTableCreateCompanionBuilder,
      $$OfflineAssetEntityTableUpdateCompanionBuilder,
      (i1.OfflineAssetEntityData, i1.$$OfflineAssetEntityTableReferences),
      i1.OfflineAssetEntityData,
      i0.PrefetchHooks Function({bool remoteAssetId})
    >;
i0.Index get idxOfflineAssetRemoteAssetId => i0.Index(
  'idx_offline_asset_remote_asset_id',
  'CREATE INDEX IF NOT EXISTS idx_offline_asset_remote_asset_id ON offline_asset_entity (remote_asset_id)',
);

class $OfflineAssetEntityTable extends i2.OfflineAssetEntity
    with i0.TableInfo<$OfflineAssetEntityTable, i1.OfflineAssetEntityData> {
  @override
  final i0.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineAssetEntityTable(this.attachedDatabase, [this._alias]);
  static const i0.VerificationMeta _remoteAssetIdMeta =
      const i0.VerificationMeta('remoteAssetId');
  @override
  late final i0.GeneratedColumn<String> remoteAssetId =
      i0.GeneratedColumn<String>(
        'remote_asset_id',
        aliasedName,
        false,
        type: i0.DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: i0.GeneratedColumn.constraintIsAlways(
          'REFERENCES remote_asset_entity (id) ON DELETE CASCADE',
        ),
      );
  static const i0.VerificationMeta _thumbnailPathMeta =
      const i0.VerificationMeta('thumbnailPath');
  @override
  late final i0.GeneratedColumn<String> thumbnailPath =
      i0.GeneratedColumn<String>(
        'thumbnail_path',
        aliasedName,
        true,
        type: i0.DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const i0.VerificationMeta _fullImagePathMeta =
      const i0.VerificationMeta('fullImagePath');
  @override
  late final i0.GeneratedColumn<String> fullImagePath =
      i0.GeneratedColumn<String>(
        'full_image_path',
        aliasedName,
        true,
        type: i0.DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const i0.VerificationMeta _videoPathMeta = const i0.VerificationMeta(
    'videoPath',
  );
  @override
  late final i0.GeneratedColumn<String> videoPath = i0.GeneratedColumn<String>(
    'video_path',
    aliasedName,
    true,
    type: i0.DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const i0.VerificationMeta _downloadedAtMeta =
      const i0.VerificationMeta('downloadedAt');
  @override
  late final i0.GeneratedColumn<DateTime> downloadedAt =
      i0.GeneratedColumn<DateTime>(
        'downloaded_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const i0.VerificationMeta _fileSizeMeta = const i0.VerificationMeta(
    'fileSize',
  );
  @override
  late final i0.GeneratedColumn<int> fileSize = i0.GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: i0.DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const i0.VerificationMeta _lastAccessedAtMeta =
      const i0.VerificationMeta('lastAccessedAt');
  @override
  late final i0.GeneratedColumn<DateTime> lastAccessedAt =
      i0.GeneratedColumn<DateTime>(
        'last_accessed_at',
        aliasedName,
        false,
        type: i0.DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<i0.GeneratedColumn> get $columns => [
    remoteAssetId,
    thumbnailPath,
    fullImagePath,
    videoPath,
    downloadedAt,
    fileSize,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_asset_entity';
  @override
  i0.VerificationContext validateIntegrity(
    i0.Insertable<i1.OfflineAssetEntityData> instance, {
    bool isInserting = false,
  }) {
    final context = i0.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('remote_asset_id')) {
      context.handle(
        _remoteAssetIdMeta,
        remoteAssetId.isAcceptableOrUnknown(
          data['remote_asset_id']!,
          _remoteAssetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteAssetIdMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('full_image_path')) {
      context.handle(
        _fullImagePathMeta,
        fullImagePath.isAcceptableOrUnknown(
          data['full_image_path']!,
          _fullImagePathMeta,
        ),
      );
    }
    if (data.containsKey('video_path')) {
      context.handle(
        _videoPathMeta,
        videoPath.isAcceptableOrUnknown(data['video_path']!, _videoPathMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    return context;
  }

  @override
  Set<i0.GeneratedColumn> get $primaryKey => {remoteAssetId};
  @override
  i1.OfflineAssetEntityData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return i1.OfflineAssetEntityData(
      remoteAssetId: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}remote_asset_id'],
      )!,
      thumbnailPath: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      fullImagePath: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}full_image_path'],
      ),
      videoPath: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.string,
        data['${effectivePrefix}video_path'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        i0.DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $OfflineAssetEntityTable createAlias(String alias) {
    return $OfflineAssetEntityTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
  @override
  bool get isStrict => true;
}

class OfflineAssetEntityData extends i0.DataClass
    implements i0.Insertable<i1.OfflineAssetEntityData> {
  /// Foreign key reference to the remote asset
  final String remoteAssetId;

  /// File path to the cached thumbnail image
  final String? thumbnailPath;

  /// File path to the cached full-resolution image
  final String? fullImagePath;

  /// File path to the cached video file (for video assets)
  final String? videoPath;

  /// Timestamp when the asset was downloaded/cached
  final DateTime downloadedAt;

  /// Total file size in bytes (sum of all cached files)
  final int fileSize;

  /// Timestamp when the asset was last accessed/viewed
  final DateTime lastAccessedAt;
  const OfflineAssetEntityData({
    required this.remoteAssetId,
    this.thumbnailPath,
    this.fullImagePath,
    this.videoPath,
    required this.downloadedAt,
    required this.fileSize,
    required this.lastAccessedAt,
  });
  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    map['remote_asset_id'] = i0.Variable<String>(remoteAssetId);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = i0.Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || fullImagePath != null) {
      map['full_image_path'] = i0.Variable<String>(fullImagePath);
    }
    if (!nullToAbsent || videoPath != null) {
      map['video_path'] = i0.Variable<String>(videoPath);
    }
    map['downloaded_at'] = i0.Variable<DateTime>(downloadedAt);
    map['file_size'] = i0.Variable<int>(fileSize);
    map['last_accessed_at'] = i0.Variable<DateTime>(lastAccessedAt);
    return map;
  }

  factory OfflineAssetEntityData.fromJson(
    Map<String, dynamic> json, {
    i0.ValueSerializer? serializer,
  }) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return OfflineAssetEntityData(
      remoteAssetId: serializer.fromJson<String>(json['remoteAssetId']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      fullImagePath: serializer.fromJson<String?>(json['fullImagePath']),
      videoPath: serializer.fromJson<String?>(json['videoPath']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({i0.ValueSerializer? serializer}) {
    serializer ??= i0.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'remoteAssetId': serializer.toJson<String>(remoteAssetId),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'fullImagePath': serializer.toJson<String?>(fullImagePath),
      'videoPath': serializer.toJson<String?>(videoPath),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
      'fileSize': serializer.toJson<int>(fileSize),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
    };
  }

  i1.OfflineAssetEntityData copyWith({
    String? remoteAssetId,
    i0.Value<String?> thumbnailPath = const i0.Value.absent(),
    i0.Value<String?> fullImagePath = const i0.Value.absent(),
    i0.Value<String?> videoPath = const i0.Value.absent(),
    DateTime? downloadedAt,
    int? fileSize,
    DateTime? lastAccessedAt,
  }) => i1.OfflineAssetEntityData(
    remoteAssetId: remoteAssetId ?? this.remoteAssetId,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    fullImagePath: fullImagePath.present
        ? fullImagePath.value
        : this.fullImagePath,
    videoPath: videoPath.present ? videoPath.value : this.videoPath,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    fileSize: fileSize ?? this.fileSize,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  OfflineAssetEntityData copyWithCompanion(
    i1.OfflineAssetEntityCompanion data,
  ) {
    return OfflineAssetEntityData(
      remoteAssetId: data.remoteAssetId.present
          ? data.remoteAssetId.value
          : this.remoteAssetId,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      fullImagePath: data.fullImagePath.present
          ? data.fullImagePath.value
          : this.fullImagePath,
      videoPath: data.videoPath.present ? data.videoPath.value : this.videoPath,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineAssetEntityData(')
          ..write('remoteAssetId: $remoteAssetId, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('fullImagePath: $fullImagePath, ')
          ..write('videoPath: $videoPath, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('fileSize: $fileSize, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    remoteAssetId,
    thumbnailPath,
    fullImagePath,
    videoPath,
    downloadedAt,
    fileSize,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is i1.OfflineAssetEntityData &&
          other.remoteAssetId == this.remoteAssetId &&
          other.thumbnailPath == this.thumbnailPath &&
          other.fullImagePath == this.fullImagePath &&
          other.videoPath == this.videoPath &&
          other.downloadedAt == this.downloadedAt &&
          other.fileSize == this.fileSize &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class OfflineAssetEntityCompanion
    extends i0.UpdateCompanion<i1.OfflineAssetEntityData> {
  final i0.Value<String> remoteAssetId;
  final i0.Value<String?> thumbnailPath;
  final i0.Value<String?> fullImagePath;
  final i0.Value<String?> videoPath;
  final i0.Value<DateTime> downloadedAt;
  final i0.Value<int> fileSize;
  final i0.Value<DateTime> lastAccessedAt;
  const OfflineAssetEntityCompanion({
    this.remoteAssetId = const i0.Value.absent(),
    this.thumbnailPath = const i0.Value.absent(),
    this.fullImagePath = const i0.Value.absent(),
    this.videoPath = const i0.Value.absent(),
    this.downloadedAt = const i0.Value.absent(),
    this.fileSize = const i0.Value.absent(),
    this.lastAccessedAt = const i0.Value.absent(),
  });
  OfflineAssetEntityCompanion.insert({
    required String remoteAssetId,
    this.thumbnailPath = const i0.Value.absent(),
    this.fullImagePath = const i0.Value.absent(),
    this.videoPath = const i0.Value.absent(),
    required DateTime downloadedAt,
    required int fileSize,
    required DateTime lastAccessedAt,
  }) : remoteAssetId = i0.Value(remoteAssetId),
       downloadedAt = i0.Value(downloadedAt),
       fileSize = i0.Value(fileSize),
       lastAccessedAt = i0.Value(lastAccessedAt);
  static i0.Insertable<i1.OfflineAssetEntityData> custom({
    i0.Expression<String>? remoteAssetId,
    i0.Expression<String>? thumbnailPath,
    i0.Expression<String>? fullImagePath,
    i0.Expression<String>? videoPath,
    i0.Expression<DateTime>? downloadedAt,
    i0.Expression<int>? fileSize,
    i0.Expression<DateTime>? lastAccessedAt,
  }) {
    return i0.RawValuesInsertable({
      if (remoteAssetId != null) 'remote_asset_id': remoteAssetId,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (fullImagePath != null) 'full_image_path': fullImagePath,
      if (videoPath != null) 'video_path': videoPath,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (fileSize != null) 'file_size': fileSize,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  i1.OfflineAssetEntityCompanion copyWith({
    i0.Value<String>? remoteAssetId,
    i0.Value<String?>? thumbnailPath,
    i0.Value<String?>? fullImagePath,
    i0.Value<String?>? videoPath,
    i0.Value<DateTime>? downloadedAt,
    i0.Value<int>? fileSize,
    i0.Value<DateTime>? lastAccessedAt,
  }) {
    return i1.OfflineAssetEntityCompanion(
      remoteAssetId: remoteAssetId ?? this.remoteAssetId,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fullImagePath: fullImagePath ?? this.fullImagePath,
      videoPath: videoPath ?? this.videoPath,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      fileSize: fileSize ?? this.fileSize,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  Map<String, i0.Expression> toColumns(bool nullToAbsent) {
    final map = <String, i0.Expression>{};
    if (remoteAssetId.present) {
      map['remote_asset_id'] = i0.Variable<String>(remoteAssetId.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = i0.Variable<String>(thumbnailPath.value);
    }
    if (fullImagePath.present) {
      map['full_image_path'] = i0.Variable<String>(fullImagePath.value);
    }
    if (videoPath.present) {
      map['video_path'] = i0.Variable<String>(videoPath.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = i0.Variable<DateTime>(downloadedAt.value);
    }
    if (fileSize.present) {
      map['file_size'] = i0.Variable<int>(fileSize.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = i0.Variable<DateTime>(lastAccessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineAssetEntityCompanion(')
          ..write('remoteAssetId: $remoteAssetId, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('fullImagePath: $fullImagePath, ')
          ..write('videoPath: $videoPath, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('fileSize: $fileSize, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }
}

i0.Index get idxOfflineAssetLastAccessed => i0.Index(
  'idx_offline_asset_last_accessed',
  'CREATE INDEX IF NOT EXISTS idx_offline_asset_last_accessed ON offline_asset_entity (last_accessed_at DESC)',
);
