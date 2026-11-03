import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db.dart';
import 'storage_service.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  offline,
  error,
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const String supabaseUrl = 'https://pgysnqsimewpwgmztjom.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_GmPFw0LOQYBIHHBgn9TK6Q_5Hby5EMj';

  final ValueNotifier<SyncStatus> status = ValueNotifier(SyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier(null);
  final ValueNotifier<String?> lastErrorMessage = ValueNotifier(null);

  final StreamController<void> _onSyncCompletedController =
      StreamController<void>.broadcast();
  Stream<void> get onSyncCompleted => _onSyncCompletedController.stream;

  bool _isSyncing = false;
  bool _initialized = false;
  File? _metaFile;

  /// Call once during app startup to load previous sync metadata and initialize.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final root = StorageService.instance.rootPath;
      _metaFile = File(p.join(root, 'sync_meta.json'));

      if (await _metaFile!.exists()) {
        final content = await _metaFile!.readAsString();
        if (content.isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          if (json['last_sync'] != null) {
            lastSyncTime.value =
                DateTime.tryParse(json['last_sync'].toString());
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService.init metadata warning: $e');
    }

    _initialized = true;
  }

  bool get isSupabaseConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Run bidirectional synchronization.
  /// Safe to call at any time; catches and logs network or offline errors
  /// without disrupting app flow.
  Future<bool> sync({bool force = false}) async {
    if (_isSyncing) {
      debugPrint('Sync already in progress. Skipping.');
      return false;
    }

    if (!isSupabaseConfigured) {
      debugPrint('Supabase is not initialized. Skipping sync.');
      return false;
    }

    _isSyncing = true;
    status.value = SyncStatus.syncing;
    lastErrorMessage.value = null;

    final client = Supabase.instance.client;
    final localDb = LocalDb();
    final previousSyncTime = force ? null : lastSyncTime.value;
    final syncStartTime = DateTime.now().toUtc();

    try {
      // ─────────────────────────────────────────────────────────────────────
      // PHASE 1: PUSH (Local Changes -> Supabase)
      // ─────────────────────────────────────────────────────────────────────

      // 1. Invoices
      final localInvoices =
          await localDb.getRawInvoicesModifiedSince(previousSyncTime);
      if (localInvoices.isNotEmpty) {
        final sanitizedInvoices = localInvoices.map((row) {
          final m = Map<String, dynamic>.from(row);
          m['is_deleted'] = (m['is_deleted'] == 1 || m['is_deleted'] == true);
          if (m['next_service_date'] != null &&
              m['next_service_date'].toString().trim().isEmpty) {
            m['next_service_date'] = null;
          }
          m['transportation_amount'] =
              (m['transportation_amount'] as num?)?.toDouble() ?? 0.0;
          m['labour_amount'] = (m['labour_amount'] as num?)?.toDouble() ?? 0.0;
          m['other_charges_amount'] =
              (m['other_charges_amount'] as num?)?.toDouble() ?? 0.0;
          m['grand_total'] = (m['grand_total'] as num?)?.toDouble() ?? 0.0;
          return m;
        }).toList();

        await client.from('invoices').upsert(sanitizedInvoices);
      }

      // 2. Invoice Items
      final localItems =
          await localDb.getRawInvoiceItemsModifiedSince(previousSyncTime);
      if (localItems.isNotEmpty) {
        final sanitizedItems = localItems.map((row) {
          final m = Map<String, dynamic>.from(row);
          m['is_deleted'] = (m['is_deleted'] == 1 || m['is_deleted'] == true);
          m['quantity'] = (m['quantity'] as num?)?.toDouble() ?? 0.0;
          m['price'] = (m['price'] as num?)?.toDouble() ?? 0.0;
          return m;
        }).toList();

        await client.from('invoice_items').upsert(sanitizedItems);
      }

      // 3. Clients
      final localClients =
          await localDb.getRawClientsModifiedSince(previousSyncTime);
      if (localClients.isNotEmpty) {
        final sanitizedClients = localClients.map((row) {
          final m = Map<String, dynamic>.from(row);
          m['is_deleted'] = (m['is_deleted'] == 1 || m['is_deleted'] == true);
          return m;
        }).toList();

        await client.from('clients').upsert(sanitizedClients);
      }

      // ─────────────────────────────────────────────────────────────────────
      // PHASE 2: PULL (Supabase Changes -> Local SQLite)
      // ─────────────────────────────────────────────────────────────────────

      // 1. Pull Invoices
      dynamic invoicesQuery = client.from('invoices').select();
      if (previousSyncTime != null) {
        invoicesQuery = invoicesQuery.gt(
            'updated_at', previousSyncTime.toUtc().toIso8601String());
      }
      final remoteInvoices = await invoicesQuery as List<dynamic>;
      for (final raw in remoteInvoices) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['is_deleted'] =
            (row['is_deleted'] == true || row['is_deleted'] == 1) ? 1 : 0;
        await localDb.upsertSyncedInvoice(row);
      }

      // 2. Pull Invoice Items
      dynamic itemsQuery = client.from('invoice_items').select();
      if (previousSyncTime != null) {
        itemsQuery = itemsQuery.gt(
            'updated_at', previousSyncTime.toUtc().toIso8601String());
      }
      final remoteItems = await itemsQuery as List<dynamic>;
      for (final raw in remoteItems) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['is_deleted'] =
            (row['is_deleted'] == true || row['is_deleted'] == 1) ? 1 : 0;
        await localDb.upsertSyncedInvoiceItem(row);
      }

      // 3. Pull Clients
      dynamic clientsQuery = client.from('clients').select();
      if (previousSyncTime != null) {
        clientsQuery = clientsQuery.gt(
            'updated_at', previousSyncTime.toUtc().toIso8601String());
      }
      final remoteClients = await clientsQuery as List<dynamic>;
      for (final raw in remoteClients) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['is_deleted'] =
            (row['is_deleted'] == true || row['is_deleted'] == 1) ? 1 : 0;
        await localDb.upsertSyncedClient(row);
      }

      // ─────────────────────────────────────────────────────────────────────
      // PHASE 3: FINALIZE
      // ─────────────────────────────────────────────────────────────────────
      lastSyncTime.value = syncStartTime;
      await _persistMetadata(syncStartTime);

      status.value = SyncStatus.success;
      _onSyncCompletedController.add(null);
      debugPrint('Sync completed successfully at $syncStartTime');
      return true;
    } catch (e, stack) {
      debugPrint('Sync encountered error: $e\n$stack');

      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('connection refused') ||
          errStr.contains('network is unreachable') ||
          errStr.contains('handshakeexception')) {
        status.value = SyncStatus.offline;
        lastErrorMessage.value = 'Offline - will sync when internet reconnects';
      } else {
        status.value = SyncStatus.error;
        lastErrorMessage.value = e.toString();
      }
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _persistMetadata(DateTime time) async {
    try {
      if (_metaFile != null) {
        final json = {'last_sync': time.toIso8601String()};
        await _metaFile!.writeAsString(jsonEncode(json));
      }
    } catch (e) {
      debugPrint('Could not save sync metadata: $e');
    }
  }
}
