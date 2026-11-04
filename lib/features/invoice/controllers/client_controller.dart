import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/client.dart';
import '../../../data/repositories/client_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────

final clientRepositoryProvider = Provider<ClientRepository>(
  (_) => ClientRepository(),
);

// ── All clients list ──────────────────────────────────────────────────────

final allClientsProvider = FutureProvider<List<Client>>((ref) {
  return ref.watch(clientRepositoryProvider).getAll();
});

// ── Search query state ────────────────────────────────────────────────────

final clientSearchQueryProvider = StateProvider<String>((_) => '');

// ── Filtered clients ──────────────────────────────────────────────────────

final filteredClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final query = ref.watch(clientSearchQueryProvider).toLowerCase().trim();
  final clientsAsync = ref.watch(allClientsProvider);

  return clientsAsync.whenData((clients) {
    if (query.isEmpty) return clients;
    return clients
        .where((c) =>
            c.name.toLowerCase().contains(query) ||
            c.billTo.toLowerCase().contains(query) ||
            c.phone.toLowerCase().contains(query) ||
            c.address.toLowerCase().contains(query))
        .toList();
  });
});
