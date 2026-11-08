import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/client.dart';

class LocalDb {
  static final LocalDb _instance = LocalDb._internal();
  factory LocalDb() => _instance;
  LocalDb._internal();

  static Database? _db;

  /// The resolved path to the database file.
  /// Must be set by calling [setDatabasePath] before the database is first accessed.
  static String? _databasePath;

  /// Inject the database path from [StorageService] before any DB access.
  static void setDatabasePath(String path) {
    _databasePath = path;
  }

  /// Call once at app start for desktop platforms.
  static void initFfiIfNeeded() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    assert(
      _databasePath != null,
      'LocalDb: call LocalDb.setDatabasePath() before accessing the database.',
    );

    final dbPath = _databasePath!;

    // Ensure the parent directory exists (StorageService creates it, but
    // this is a belt-and-suspenders guard).
    final dbDir = Directory(dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    return openDatabase(
      dbPath,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        client_name TEXT,
        address TEXT,
        phone TEXT,
        bill_to TEXT,
        date TEXT NOT NULL,
        running_hour TEXT,
        model TEXT,
        next_service_date TEXT,
        job_description TEXT,
        observations TEXT DEFAULT '',
        recommendations TEXT DEFAULT '',
        manager_name TEXT,
        technician_name TEXT DEFAULT '',
        representative_name TEXT DEFAULT '',
        transportation_amount REAL DEFAULT 0,
        labour_amount REAL DEFAULT 0,
        other_charges_amount REAL DEFAULT 0,
        grand_total REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        description TEXT,
        quantity REAL NOT NULL DEFAULT 0,
        price REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        bill_to TEXT,
        address TEXT,
        phone TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Safely runs an ALTER TABLE statement, ignoring "duplicate column" errors
  /// that occur when a previous migration was partially applied.
  Future<void> _safeAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      // Ignore duplicate column errors (code 1 = SQLITE_ERROR for dup column)
      final msg = e.toString().toLowerCase();
      if (!msg.contains('duplicate column') &&
          !msg.contains('already exists')) {
        rethrow;
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS clients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT,
            phone TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      await _safeAlter(db,
          'ALTER TABLE invoices ADD COLUMN transport_labour_amount REAL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await _safeAlter(db, 'ALTER TABLE invoices ADD COLUMN bill_to TEXT');
      await _safeAlter(
          db, 'ALTER TABLE invoices ADD COLUMN next_service_date TEXT');
      await _safeAlter(db,
          'ALTER TABLE invoices ADD COLUMN transportation_amount REAL DEFAULT 0');
      await _safeAlter(
          db, 'ALTER TABLE invoices ADD COLUMN labour_amount REAL DEFAULT 0');
      await _safeAlter(db,
          'ALTER TABLE invoices ADD COLUMN other_charges_amount REAL DEFAULT 0');
    }
    if (oldVersion < 5) {
      // Upgrade schema to support cloud synchronization with timestamps & soft-delete tombstones
      await _safeAlter(db, 'ALTER TABLE invoices ADD COLUMN updated_at TEXT');
      await _safeAlter(db,
          'ALTER TABLE invoices ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'UPDATE invoices SET updated_at = created_at WHERE updated_at IS NULL');

      await _safeAlter(
          db, 'ALTER TABLE invoice_items ADD COLUMN updated_at TEXT');
      await _safeAlter(db,
          'ALTER TABLE invoice_items ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        UPDATE invoice_items 
        SET updated_at = (SELECT created_at FROM invoices WHERE invoices.id = invoice_items.invoice_id) 
        WHERE updated_at IS NULL
      ''');
      await db.execute(
          "UPDATE invoice_items SET updated_at = datetime('now') WHERE updated_at IS NULL");

      await _safeAlter(db, 'ALTER TABLE clients ADD COLUMN updated_at TEXT');
      await _safeAlter(db,
          'ALTER TABLE clients ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'UPDATE clients SET updated_at = created_at WHERE updated_at IS NULL');
    }
    if (oldVersion < 6) {
      await _safeAlter(
          db, 'ALTER TABLE clients ADD COLUMN bill_to TEXT DEFAULT ""');
    }
    if (oldVersion < 7) {
      await _safeAlter(
          db, 'ALTER TABLE invoices ADD COLUMN observations TEXT DEFAULT ""');
      await _safeAlter(db,
          'ALTER TABLE invoices ADD COLUMN recommendations TEXT DEFAULT ""');
    }
    if (oldVersion < 8) {
      await _safeAlter(db,
          'ALTER TABLE invoices ADD COLUMN technician_name TEXT DEFAULT ""');
      await _safeAlter(db,
          'ALTER TABLE invoices ADD COLUMN representative_name TEXT DEFAULT ""');
    }
  }

  // ── Invoice CRUD ─────────────────────────────────────────────────────────

  Future<void> insertInvoice(Invoice invoice) async {
    final database = await db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final invoiceMap = invoice.toMap();
    invoiceMap['updated_at'] = nowIso;
    invoiceMap['is_deleted'] = 0;

    await database.transaction((txn) async {
      await txn.insert('invoices', invoiceMap,
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in invoice.items) {
        final itemMap = item.toMap(invoice.id);
        itemMap['updated_at'] = nowIso;
        itemMap['is_deleted'] = 0;
        await txn.insert('invoice_items', itemMap,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final database = await db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final invoiceMap = invoice.toMap();
    invoiceMap['updated_at'] = nowIso;
    invoiceMap['is_deleted'] = 0;

    await database.transaction((txn) async {
      await txn.update('invoices', invoiceMap,
          where: 'id = ?', whereArgs: [invoice.id]);

      // Soft delete existing items so Supabase sync propagates item removals
      await txn.update(
        'invoice_items',
        {'is_deleted': 1, 'updated_at': nowIso},
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      for (final item in invoice.items) {
        final itemMap = item.toMap(invoice.id);
        itemMap['updated_at'] = nowIso;
        itemMap['is_deleted'] = 0;
        await txn.insert('invoice_items', itemMap,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteInvoice(String id) async {
    final database = await db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await database.transaction((txn) async {
      await txn.update(
        'invoices',
        {'is_deleted': 1, 'updated_at': nowIso},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'invoice_items',
        {'is_deleted': 1, 'updated_at': nowIso},
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Invoice>> getAllInvoices() async {
    final database = await db;
    final maps = await database.query(
      'invoices',
      where: 'is_deleted = 0 OR is_deleted IS NULL',
      orderBy: 'created_at DESC',
    );
    final invoices = <Invoice>[];
    for (final map in maps) {
      final items = await _getItemsForInvoice(map['id'] as String);
      invoices.add(Invoice.fromMap(map, items));
    }
    return invoices;
  }

  Future<Invoice?> getInvoiceById(String id) async {
    final database = await db;
    final maps = await database.query(
      'invoices',
      where: 'id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    final items = await _getItemsForInvoice(id);
    return Invoice.fromMap(maps.first, items);
  }

  Future<List<InvoiceItem>> _getItemsForInvoice(String invoiceId) async {
    final database = await db;
    final maps = await database.query(
      'invoice_items',
      where: 'invoice_id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [invoiceId],
    );
    return maps.map(InvoiceItem.fromMap).toList();
  }

  // ── Client CRUD ──────────────────────────────────────────────────────────

  Future<void> insertClient(Client client) async {
    final database = await db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final map = client.toMap();
    map['updated_at'] = nowIso;
    map['is_deleted'] = 0;
    await database.insert('clients', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateClient(Client client) async {
    final database = await db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final map = client.toMap();
    map['updated_at'] = nowIso;
    map['is_deleted'] = 0;
    await database
        .update('clients', map, where: 'id = ?', whereArgs: [client.id]);
  }

  Future<void> deleteClient(String id) async {
    final database = await db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await database.update(
      'clients',
      {'is_deleted': 1, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Client>> getAllClients() async {
    final database = await db;
    final maps = await database.query(
      'clients',
      where: 'is_deleted = 0 OR is_deleted IS NULL',
      orderBy: 'name ASC',
    );
    return maps.map(Client.fromMap).toList();
  }

  Future<Client?> getClientByName(String name) async {
    final database = await db;
    final maps = await database.query(
      'clients',
      where: 'name = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [name],
    );
    if (maps.isEmpty) return null;
    return Client.fromMap(maps.first);
  }

  // ── Sync Helper Methods ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRawInvoicesModifiedSince(
      DateTime? since) async {
    final database = await db;
    if (since == null) {
      return await database.query('invoices');
    }
    return await database.query(
      'invoices',
      where: 'updated_at > ?',
      whereArgs: [since.toUtc().toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> getRawInvoiceItemsModifiedSince(
      DateTime? since) async {
    final database = await db;
    if (since == null) {
      return await database.query('invoice_items');
    }
    return await database.query(
      'invoice_items',
      where: 'updated_at > ?',
      whereArgs: [since.toUtc().toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> getRawClientsModifiedSince(
      DateTime? since) async {
    final database = await db;
    if (since == null) {
      return await database.query('clients');
    }
    return await database.query(
      'clients',
      where: 'updated_at > ?',
      whereArgs: [since.toUtc().toIso8601String()],
    );
  }

  Future<void> upsertSyncedInvoice(Map<String, dynamic> row) async {
    final database = await db;
    final id = row['id'] as String;
    final existing = await database.query(
      'invoices',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (existing.isNotEmpty) {
      final localUpdatedAt =
          DateTime.tryParse(existing.first['updated_at']?.toString() ?? '');
      final remoteUpdatedAt =
          DateTime.tryParse(row['updated_at']?.toString() ?? '');
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          localUpdatedAt.isAfter(remoteUpdatedAt)) {
        return; // Local version is newer, skip cloud overwrite
      }
    }

    final localRow = <String, dynamic>{
      'id': row['id'],
      'invoice_number': row['invoice_number'],
      'client_name': row['client_name'] ?? '',
      'address': row['address'] ?? '',
      'phone': row['phone'] ?? '',
      'bill_to': row['bill_to'] ?? '',
      'date': row['date'],
      'running_hour': row['running_hour'] ?? '',
      'model': row['model'] ?? '',
      'next_service_date': row['next_service_date'],
      'job_description': row['job_description'] ?? '',
      'observations': row['observations'] ?? '',
      'recommendations': row['recommendations'] ?? '',
      'manager_name': row['manager_name'] ?? '',
      'technician_name': row['technician_name'] ?? '',
      'representative_name': row['representative_name'] ?? '',
      'transportation_amount':
          (row['transportation_amount'] as num?)?.toDouble() ?? 0.0,
      'labour_amount': (row['labour_amount'] as num?)?.toDouble() ?? 0.0,
      'other_charges_amount':
          (row['other_charges_amount'] as num?)?.toDouble() ?? 0.0,
      'grand_total': (row['grand_total'] as num?)?.toDouble() ?? 0.0,
      'created_at': row['created_at'],
      'updated_at': row['updated_at'] ?? row['created_at'],
      'is_deleted':
          (row['is_deleted'] == true || row['is_deleted'] == 1) ? 1 : 0,
    };

    if (existing.isNotEmpty) {
      await database
          .update('invoices', localRow, where: 'id = ?', whereArgs: [id]);
    } else {
      await database.insert('invoices', localRow);
    }
  }

  Future<void> upsertSyncedInvoiceItem(Map<String, dynamic> row) async {
    final database = await db;
    final id = row['id'] as String;
    final existing = await database.query(
      'invoice_items',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (existing.isNotEmpty) {
      final localUpdatedAt =
          DateTime.tryParse(existing.first['updated_at']?.toString() ?? '');
      final remoteUpdatedAt =
          DateTime.tryParse(row['updated_at']?.toString() ?? '');
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          localUpdatedAt.isAfter(remoteUpdatedAt)) {
        return; // Local version is newer, skip cloud overwrite
      }
    }

    final localRow = <String, dynamic>{
      'id': row['id'],
      'invoice_id': row['invoice_id'],
      'description': row['description'] ?? '',
      'quantity': (row['quantity'] as num?)?.toDouble() ?? 0.0,
      'price': (row['price'] as num?)?.toDouble() ?? 0.0,
      'updated_at':
          row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'is_deleted':
          (row['is_deleted'] == true || row['is_deleted'] == 1) ? 1 : 0,
    };

    if (existing.isNotEmpty) {
      await database
          .update('invoice_items', localRow, where: 'id = ?', whereArgs: [id]);
    } else {
      // Guard against foreign key failure if parent invoice doesn't exist locally
      final parent = await database.query(
        'invoices',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [localRow['invoice_id']],
      );
      if (parent.isEmpty) return;

      await database.insert('invoice_items', localRow);
    }
  }

  Future<void> upsertSyncedClient(Map<String, dynamic> row) async {
    final database = await db;
    final id = row['id'] as String;
    final existing = await database.query(
      'clients',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (existing.isNotEmpty) {
      final localUpdatedAt =
          DateTime.tryParse(existing.first['updated_at']?.toString() ?? '');
      final remoteUpdatedAt =
          DateTime.tryParse(row['updated_at']?.toString() ?? '');
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          localUpdatedAt.isAfter(remoteUpdatedAt)) {
        return; // Local version is newer, skip cloud overwrite
      }
    }

    final localRow = <String, dynamic>{
      'id': row['id'],
      'name': row['name'] ?? '',
      'bill_to': row['bill_to'] ?? '',
      'address': row['address'] ?? '',
      'phone': row['phone'] ?? '',
      'created_at': row['created_at'],
      'updated_at': row['updated_at'] ?? row['created_at'],
      'is_deleted':
          (row['is_deleted'] == true || row['is_deleted'] == 1) ? 1 : 0,
    };

    if (existing.isNotEmpty) {
      await database
          .update('clients', localRow, where: 'id = ?', whereArgs: [id]);
    } else {
      await database.insert('clients', localRow);
    }
  }
}
