import '../datasources/local_db.dart';
import '../models/invoice.dart';

class InvoiceRepository {
  final LocalDb _db;

  InvoiceRepository({LocalDb? db}) : _db = db ?? LocalDb();

  Future<void> save(Invoice invoice) => _db.insertInvoice(invoice);
  Future<void> update(Invoice invoice) => _db.updateInvoice(invoice);
  Future<void> delete(String id) => _db.deleteInvoice(id);
  Future<List<Invoice>> getAll() => _db.getAllInvoices();
  Future<Invoice?> getById(String id) => _db.getInvoiceById(id);
}
