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
      version: 4,
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
        manager_name TEXT,
        transportation_amount REAL DEFAULT 0,
        labour_amount REAL DEFAULT 0,
        other_charges_amount REAL DEFAULT 0,
        grand_total REAL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        description TEXT,
        quantity REAL NOT NULL DEFAULT 0,
        price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE clients (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          address TEXT,
          phone TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE invoices ADD COLUMN transport_labour_amount REAL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      // Add new fields introduced in the redesigned invoice template.
      await db.execute(
          'ALTER TABLE invoices ADD COLUMN bill_to TEXT');
      await db.execute(
          'ALTER TABLE invoices ADD COLUMN next_service_date TEXT');
      await db.execute(
          'ALTER TABLE invoices ADD COLUMN transportation_amount REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE invoices ADD COLUMN labour_amount REAL DEFAULT 0');
      await db.execute(
          'ALTER TABLE invoices ADD COLUMN other_charges_amount REAL DEFAULT 0');
    }
  }

  // ── Invoice CRUD ─────────────────────────────────────────────────────────

  Future<void> insertInvoice(Invoice invoice) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.insert('invoices', invoice.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in invoice.items) {
        await txn.insert('invoice_items', item.toMap(invoice.id),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.update('invoices', invoice.toMap(),
          where: 'id = ?', whereArgs: [invoice.id]);
      await txn.delete('invoice_items',
          where: 'invoice_id = ?', whereArgs: [invoice.id]);
      for (final item in invoice.items) {
        await txn.insert('invoice_items', item.toMap(invoice.id),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteInvoice(String id) async {
    final database = await db;
    await database.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Invoice>> getAllInvoices() async {
    final database = await db;
    final maps =
        await database.query('invoices', orderBy: 'created_at DESC');
    final invoices = <Invoice>[];
    for (final map in maps) {
      final items = await _getItemsForInvoice(map['id'] as String);
      invoices.add(Invoice.fromMap(map, items));
    }
    return invoices;
  }

  Future<Invoice?> getInvoiceById(String id) async {
    final database = await db;
    final maps =
        await database.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final items = await _getItemsForInvoice(id);
    return Invoice.fromMap(maps.first, items);
  }

  Future<List<InvoiceItem>> _getItemsForInvoice(String invoiceId) async {
    final database = await db;
    final maps = await database.query('invoice_items',
        where: 'invoice_id = ?', whereArgs: [invoiceId]);
    return maps.map(InvoiceItem.fromMap).toList();
  }

  // ── Client CRUD ──────────────────────────────────────────────────────────

  Future<void> insertClient(Client client) async {
    final database = await db;
    await database.insert('clients', client.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateClient(Client client) async {
    final database = await db;
    await database.update('clients', client.toMap(),
        where: 'id = ?', whereArgs: [client.id]);
  }

  Future<void> deleteClient(String id) async {
    final database = await db;
    await database.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Client>> getAllClients() async {
    final database = await db;
    final maps = await database.query('clients', orderBy: 'name ASC');
    return maps.map(Client.fromMap).toList();
  }

  Future<Client?> getClientByName(String name) async {
    final database = await db;
    final maps =
        await database.query('clients', where: 'name = ?', whereArgs: [name]);
    if (maps.isEmpty) return null;
    return Client.fromMap(maps.first);
  }
}
