import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/invoice_item.dart';
import '../../../data/repositories/invoice_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (_) => InvoiceRepository(),
);

// ── All invoices list (for home screen) ───────────────────────────────────

final allInvoicesProvider = FutureProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).getAll();
});

// ── Search query state ────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((_) => '');

// ── Filtered invoices (reactive, no setState needed) ─────────────────────

final filteredInvoicesProvider = Provider<AsyncValue<List<Invoice>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final invoicesAsync = ref.watch(allInvoicesProvider);

  return invoicesAsync.whenData((invoices) {
    if (query.isEmpty) return invoices;
    return invoices
        .where((inv) =>
            inv.clientName.toLowerCase().contains(query) ||
            inv.invoiceNumber.toLowerCase().contains(query) ||
            inv.billTo.toLowerCase().contains(query) ||
            inv.phone.toLowerCase().contains(query))
        .toList();
  });
});

// ── Single invoice form notifier ──────────────────────────────────────────

class InvoiceFormNotifier extends StateNotifier<Invoice> {
  final InvoiceRepository _repo;
  bool _isEditing = false;

  InvoiceFormNotifier(this._repo) : super(Invoice());

  bool get isEditing => _isEditing;

  /// Load existing invoice for editing.
  void loadInvoice(Invoice invoice) {
    _isEditing = true;
    state = invoice;
  }

  /// Load a duplicated invoice as a new invoice.
  void loadCopy(Invoice invoice) {
    _isEditing = false;
    state = invoice;
  }

  /// Reset to a brand-new blank invoice.
  void reset() {
    _isEditing = false;
    state = Invoice();
  }

  // ── Field updates ──────────────────────────────────────────────────────

  void updateClientName(String v) => state = state.copyWith(clientName: v);
  void updateAddress(String v) => state = state.copyWith(address: v);
  void updatePhone(String v) => state = state.copyWith(phone: v);
  void updateBillTo(String v) => state = state.copyWith(billTo: v);
  void updateRunningHour(String v) => state = state.copyWith(runningHour: v);
  void updateModel(String v) => state = state.copyWith(model: v);
  void updateNextServiceDate(DateTime? v) =>
      state = state.copyWith(nextServiceDate: v);
  void updateJobDescription(String v) =>
      state = state.copyWith(jobDescription: v);
  void updateObservations(String v) => state = state.copyWith(observations: v);
  void updateRecommendations(String v) =>
      state = state.copyWith(recommendations: v);
  void updateManagerName(String v) => state = state.copyWith(managerName: v);
  void updateTransportationAmount(double v) =>
      state = state.copyWith(transportationAmount: v);
  void updateLabourAmount(double v) => state = state.copyWith(labourAmount: v);
  void updateOtherChargesAmount(double v) =>
      state = state.copyWith(otherChargesAmount: v);

  // ── Items management ───────────────────────────────────────────────────

  void addItem() {
    final updated = List<InvoiceItem>.from(state.items)..add(InvoiceItem());
    state = state.copyWith(items: updated);
  }

  void updateItem(int index, InvoiceItem item) {
    final updated = List<InvoiceItem>.from(state.items);
    updated[index] = item;
    state = state.copyWith(items: updated);
  }

  void removeItem(int index) {
    if (state.items.length <= 1) return; // keep at least one row
    final updated = List<InvoiceItem>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void insertItem(int index, InvoiceItem item) {
    final updated = List<InvoiceItem>.from(state.items)..insert(index, item);
    state = state.copyWith(items: updated);
  }

  // ── Persistence ────────────────────────────────────────────────────────

  Future<void> save() async {
    if (_isEditing) {
      await _repo.update(state);
    } else {
      await _repo.save(state);
      _isEditing = true; // subsequent saves are updates
    }
  }
}

final invoiceFormProvider =
    StateNotifierProvider<InvoiceFormNotifier, Invoice>((ref) {
  final repo = ref.watch(invoiceRepositoryProvider);
  return InvoiceFormNotifier(repo);
});
