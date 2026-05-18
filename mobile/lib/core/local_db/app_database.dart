import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ─── Table definitions ────────────────────────────────────────────────────────

/// Cached notices — read-only for members; execs can pin/archive via the portal.
class CachedNotices extends Table {
  TextColumn get id          => text()();
  TextColumn get societyId   => text()();
  TextColumn get title       => text()();
  TextColumn get body        => text()();
  TextColumn get category    => text().withDefault(const Constant('general'))();
  BoolColumn get isPinned    => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived  => boolean().withDefault(const Constant(false))();
  DateTimeColumn get publishedAt => dateTime()();
  DateTimeColumn get cachedAt    => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached complaints for the current user's unit.
class CachedComplaints extends Table {
  TextColumn get id          => text()();
  TextColumn get societyId   => text()();
  TextColumn get unitId      => text().nullable()();
  TextColumn get title       => text()();
  TextColumn get category    => text()();
  TextColumn get priority    => text()();
  TextColumn get status      => text().withDefault(const Constant('open'))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt  => dateTime()();
  DateTimeColumn get cachedAt   => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached maintenance dues for the current user's unit.
class CachedDues extends Table {
  TextColumn get id          => text()();
  TextColumn get societyId   => text()();
  TextColumn get unitId      => text()();
  RealColumn get amount      => real()();
  TextColumn get description => text().nullable()();
  TextColumn get status      => text().withDefault(const Constant('pending'))();
  DateTimeColumn get dueDate    => dateTime()();
  DateTimeColumn get cachedAt   => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached visitor pre-approvals for the current user.
@DataClassName('CachedVisitorPass')
class CachedVisitorPasses extends Table {
  TextColumn get id           => text()();
  TextColumn get societyId    => text()();
  TextColumn get hostUnitId   => text()();
  TextColumn get visitorName  => text()();
  TextColumn get visitorPhone => text().nullable()();
  TextColumn get purpose      => text()();
  TextColumn get status       => text().withDefault(const Constant('active'))();
  DateTimeColumn get validFrom  => dateTime()();
  DateTimeColumn get validUntil => dateTime()();
  DateTimeColumn get cachedAt   => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  CachedNotices,
  CachedComplaints,
  CachedDues,
  CachedVisitorPasses,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  // ─── Notices ───────────────────────────────────────────────────────────────

  Future<List<CachedNotice>> getNotices({
    required String societyId,
    bool includeArchived = false,
  }) {
    final q = select(cachedNotices)
      ..where((t) => t.societyId.equals(societyId));
    if (!includeArchived) {
      q.where((t) => t.isArchived.not());
    }
    q.orderBy([(t) => OrderingTerm.desc(t.publishedAt)]);
    return q.get();
  }

  Future<void> upsertNotices(List<CachedNoticesCompanion> rows) =>
      batch((b) => b.insertAll(
            cachedNotices,
            rows,
            mode: InsertMode.insertOrReplace,
          ));

  Future<void> clearNotices(String societyId) => (delete(cachedNotices)
        ..where((t) => t.societyId.equals(societyId)))
      .go();

  // ─── Complaints ────────────────────────────────────────────────────────────

  Future<List<CachedComplaint>> getComplaints({
    required String societyId,
    String? unitId,
  }) {
    final q = select(cachedComplaints)
      ..where((t) => t.societyId.equals(societyId));
    if (unitId != null) q.where((t) => t.unitId.equals(unitId));
    q.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.get();
  }

  Future<void> upsertComplaints(List<CachedComplaintsCompanion> rows) =>
      batch((b) => b.insertAll(
            cachedComplaints,
            rows,
            mode: InsertMode.insertOrReplace,
          ));

  Future<void> clearComplaints(String societyId, {String? unitId}) {
    final q = delete(cachedComplaints)
      ..where((t) => t.societyId.equals(societyId));
    if (unitId != null) q.where((t) => t.unitId.equals(unitId));
    return q.go();
  }

  // ─── Dues ──────────────────────────────────────────────────────────────────

  Future<List<CachedDue>> getDues({
    required String societyId,
    required String unitId,
  }) =>
      (select(cachedDues)
            ..where((t) =>
                t.societyId.equals(societyId) & t.unitId.equals(unitId))
            ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
          .get();

  Future<void> upsertDues(List<CachedDuesCompanion> rows) =>
      batch((b) => b.insertAll(
            cachedDues,
            rows,
            mode: InsertMode.insertOrReplace,
          ));

  Future<void> clearDues(String societyId, String unitId) =>
      (delete(cachedDues)
            ..where((t) =>
                t.societyId.equals(societyId) & t.unitId.equals(unitId)))
          .go();

  // ─── Visitor passes ────────────────────────────────────────────────────────

  Future<List<CachedVisitorPass>> getVisitorPasses({
    required String societyId,
    required String hostUnitId,
  }) =>
      (select(cachedVisitorPasses)
            ..where((t) =>
                t.societyId.equals(societyId) &
                t.hostUnitId.equals(hostUnitId))
            ..orderBy([(t) => OrderingTerm.desc(t.validFrom)]))
          .get();

  Future<void> upsertVisitorPasses(List<CachedVisitorPassesCompanion> rows) =>
      batch((b) => b.insertAll(
            cachedVisitorPasses,
            rows,
            mode: InsertMode.insertOrReplace,
          ));

  Future<void> clearVisitorPasses(String societyId, String hostUnitId) =>
      (delete(cachedVisitorPasses)
            ..where((t) =>
                t.societyId.equals(societyId) &
                t.hostUnitId.equals(hostUnitId)))
          .go();
}

// ─── Connection factory ───────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'utamacs_cache.db'));
    return NativeDatabase.createInBackground(file);
  });
}
