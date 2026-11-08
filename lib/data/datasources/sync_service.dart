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
          final nextDate = row['next_service_date']?.toString().trim();
          return <String, dynamic>{
            'id': row['id'],
            'invoice_number': row['invoice_number'],
            'client_name': row['client_name'] ?? '',
            'address': row['address'] ?? '',
            'phone': row['phone'] ?? '',
            'bill_to': row['bill_to'] ?? '',
            'date': row['date'],
            'running_hour': row['running_hour'] ?? '',
            'model': row['model'] ?? '',
            'next_service_date':
                (nextDate != null && nextDate.isNotEmpty) ? nextDate : null,
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
            'is_deleted': (row['is_deleted'] == 1 || row['is_deleted'] == true),
          };
        }).toList();

        await client.from('invoices').upsert(sanitizedInvoices);
      }

      // 2. Invoice Items
      final localItems =
          await localDb.getRawInvoiceItemsModifiedSince(previousSyncTime);
      if (localItems.isNotEmpty) {
        final sanitizedItems = localItems.map((row) {
          return <String, dynamic>{
            'id': row['id'],
            'invoice_id': row['invoice_id'],
            'description': row['description'] ?? '',
            'quantity': (row['quantity'] as num?)?.toDouble() ?? 0.0,
            'price': (row['price'] as num?)?.toDouble() ?? 0.0,
            'updated_at':
                row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
            'is_deleted': (row['is_deleted'] == 1 || row['is_deleted'] == true),
          };
        }).toList();

        await client.from('invoice_items').upsert(sanitizedItems);
      }

      // 3. Clients
      final localClients =
          await localDb.getRawClientsModifiedSince(previousSyncTime);
      if (localClients.isNotEmpty) {
        final sanitizedClients = localClients.map((row) {
          return <String, dynamic>{
            'id': row['id'],
            'name': row['name'] ?? '',
            'bill_to': row['bill_to'] ?? '',
            'address': row['address'] ?? '',
            'phone': row['phone'] ?? '',
            'created_at': row['created_at'],
            'updated_at': row['updated_at'] ?? row['created_at'],
            'is_deleted': (row['is_deleted'] == 1 || row['is_deleted'] == true),
          };
        }).toList();

        await client.from('clients').upsert(sanitizedClients);
      }

      // ─────────────────────────────────────────────────────────────────────
      // PHASE 2: PULL (Supabase Changes -> Local SQLite)
      // ─────────────────────────────────────────────────────────────────────
      // Subtract a 5-minute safety window to prevent clock skew between devices
      // from causing missed records.
      final pullSince = previousSyncTime?.subtract(const Duration(minutes: 5));

      // 1. Pull Invoices
      dynamic invoicesQuery = client.from('invoices').select();
      if (pullSince != null) {
        invoicesQuery =
            invoicesQuery.gt('updated_at', pullSince.toUtc().toIso8601String());
      }
      final remoteInvoices = await invoicesQuery as List<dynamic>;
      for (final raw in remoteInvoices) {
        final row = Map<String, dynamic>.from(raw as Map);
        await localDb.upsertSyncedInvoice(row);
      }

      // 2. Pull Invoice Items
      dynamic itemsQuery = client.from('invoice_items').select();
      if (pullSince != null) {
        itemsQuery =
            itemsQuery.gt('updated_at', pullSince.toUtc().toIso8601String());
      }
      final remoteItems = await itemsQuery as List<dynamic>;
      for (final raw in remoteItems) {
        final row = Map<String, dynamic>.from(raw as Map);
        await localDb.upsertSyncedInvoiceItem(row);
      }

      // 3. Pull Clients
      dynamic clientsQuery = client.from('clients').select();
      if (pullSince != null) {
        clientsQuery =
            clientsQuery.gt('updated_at', pullSince.toUtc().toIso8601String());
      }
      final remoteClients = await clientsQuery as List<dynamic>;
      for (final raw in remoteClients) {
        final row = Map<String, dynamic>.from(raw as Map);
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
