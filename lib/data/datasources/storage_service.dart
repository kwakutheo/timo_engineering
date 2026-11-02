import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Centralised service that owns every file-system path the app uses.
///
/// Directory layout under `%LOCALAPPDATA%\Timo Invoice\`:
/// ```
/// Timo Invoice/
/// ├── database/
/// │   └── timos_invoices.db
/// ├── backups/
/// └── exports/
/// ```
///
/// Call [init] once at app startup (before any database access).
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  /// Whether [init] has completed successfully.
  bool _initialised = false;

  late final String _rootPath;
  late final String _databasePath;
  late final String _backupsPath;
  late final String _exportsPath;

  // ── Public getters ──────────────────────────────────────────────────────

  /// Full path to the SQLite database file.
  String get databasePath {
    _assertInit();
    return _databasePath;
  }

  /// Directory for automatic backups.
  String get backupsDir {
    _assertInit();
    return _backupsPath;
  }

  /// Directory for temporary PDF exports (share, etc.).
  String get exportsDir {
    _assertInit();
    return _exportsPath;
  }

  /// The storage root directory path.
  String get rootPath {
    _assertInit();
    return _rootPath;
  }

  // ── Initialisation ──────────────────────────────────────────────────────

  /// Ensures the directory structure exists and migrates legacy data.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialised) return;

    _rootPath = await _resolveRootPath();

    // Build sub-directory paths.
    final dbDir = p.join(_rootPath, 'database');
    _backupsPath = p.join(_rootPath, 'backups');
    _exportsPath = p.join(_rootPath, 'exports');
    _databasePath = p.join(dbDir, 'timos_invoices.db');

    // Create the full directory tree (idempotent).
    await Directory(dbDir).create(recursive: true);
    await Directory(_backupsPath).create(recursive: true);
    await Directory(_exportsPath).create(recursive: true);

    // Migrate legacy database if present and the new one does not exist yet.
    await _migrateLegacyDatabase();

    _initialised = true;
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  void _assertInit() {
    assert(_initialised, 'StorageService.init() must be called before use.');
  }

  /// Resolves the root storage directory.
  ///
  /// On **Windows** we use `%LOCALAPPDATA%\Timo Invoice` directly.
  /// On other desktop platforms we fall back to [getApplicationSupportDirectory].
  /// On mobile we use the default databases path.
  Future<String> _resolveRootPath() async {
    if (Platform.isWindows) {
      // Prefer the explicit env variable for maximum reliability.
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return p.join(localAppData, 'Timo Invoice');
      }
    }

    // Fallback for macOS / Linux / mobile.
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'Timo Invoice');
  }

  /// One-time, idempotent migration of the database from the old
  /// `getApplicationSupportDirectory()/timos_invoices.db` path to the new
  /// structured layout.
  ///
  /// Strategy (safe — no data loss):
  /// 1. If the new database already exists → skip (nothing to do).
  /// 2. Copy the old file to the new path.
  /// 3. Verify the copy (file exists and size matches).
  /// 4. Rename the old file to `.bak` so it won't be migrated again.
  Future<void> _migrateLegacyDatabase() async {
    final newDbFile = File(_databasePath);
    // If we already have a database at the new location, skip migration.
    if (await newDbFile.exists()) return;

    // Locate the old database.
    final oldPath = await _legacyDatabasePath();
    if (oldPath == null) return;

    final oldFile = File(oldPath);
    if (!await oldFile.exists()) return;

    try {
      // Step 1: Copy (not move) first — safest approach.
      await oldFile.copy(_databasePath);

      // Step 2: Verify the copy.
      final oldSize = await oldFile.length();
      final newSize = await newDbFile.length();
      if (newSize != oldSize) {
        // Copy is corrupt — delete it and keep the original untouched.
        await newDbFile.delete();
        return;
      }

      // Step 3: Rename old file to .bak (keeps it around just in case).
      final backupPath = '$oldPath.bak';
      await oldFile.rename(backupPath);
    } catch (_) {
      // If anything goes wrong, ensure we don't leave a partial new file
      // while the original is still intact at the old path.
      if (await newDbFile.exists() && await oldFile.exists()) {
        await newDbFile.delete();
      }
    }
  }

  /// Returns the path where the old database was stored, or `null` if
  /// we can't determine it.
  Future<String?> _legacyDatabasePath() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final candidate = p.join(appDir.path, 'timos_invoices.db');
      if (await File(candidate).exists()) return candidate;
    } catch (_) {
      // path_provider not available or failed — ignore.
    }
    return null;
  }
}
