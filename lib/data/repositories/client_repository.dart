import '../datasources/local_db.dart';
import '../models/client.dart';

class ClientRepository {
  final LocalDb _db;

  ClientRepository({LocalDb? db}) : _db = db ?? LocalDb();

  Future<void> save(Client client) => _db.insertClient(client);
  Future<void> update(Client client) => _db.updateClient(client);
  Future<void> delete(String id) => _db.deleteClient(id);
  Future<List<Client>> getAll() => _db.getAllClients();
  Future<Client?> getByName(String name) => _db.getClientByName(name);
}
