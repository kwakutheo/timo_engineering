import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/datasources/sync_service.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/invoice_item.dart';
import '../../../data/models/client.dart';
import '../controllers/invoice_controller.dart';
import '../controllers/client_controller.dart';
import '../services/pdf_service.dart';
import '../widgets/client_picker_dialog.dart';
import '../widgets/pdf_document_choice_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  /// Pass an existing invoice to open in edit or read-only view mode.
  final Invoice? existing;

  /// Displays an existing invoice without allowing changes.
  final bool viewOnly;

  /// Pass an existing invoice to duplicate into a new invoice.
  final Invoice? duplicateFrom;

  const InvoiceFormScreen({
    super.key,
    this.existing,
    this.duplicateFrom,
    this.viewOnly = false,
  });

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  // ── Top-level field controllers ──────────────────────────────────────────
  late final TextEditingController _clientName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _billTo;
  late final TextEditingController _runningHour;
  late final TextEditingController _model;
  late final TextEditingController _jobDescription;
  late final TextEditingController _observations;
  late final TextEditingController _recommendations;
  late final TextEditingController _managerName;
  late final TextEditingController _technicianName;
  late final TextEditingController _representativeName;

  // ── Per-row item controllers ─────────────────────────────────────────────
  final List<_RowCtrls> _rowCtrls = [];

  // ── Charges controllers ────────────────────────────────────────────────
  late final TextEditingController _transportation;
  late final TextEditingController _labour;

  // ── Next service date ─────────────────────────────────────────────────
  DateTime? _nextServiceDate;

  bool _isSaving = false;
  Invoice? _lastSavedInvoice;

  bool get _isViewOnly => widget.viewOnly;

  // ── Responsive helper ─────────────────────────────────────────────────────
  bool _isMobile(BuildContext ctx) => MediaQuery.sizeOf(ctx).width < 600;

  @override
  void initState() {
    super.initState();
    _lastSavedInvoice =
        widget.existing; // If null (duplicating/new), we want to save all

    // Seed the Riverpod state with existing or reset to blank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(invoiceFormProvider.notifier);
      if (widget.existing != null) {
        notifier.loadInvoice(widget.existing!);
      } else if (widget.duplicateFrom != null) {
        notifier.loadCopy(Invoice.duplicate(widget.duplicateFrom!));
      } else {
        notifier.reset();
      }
    });

    final src = widget.existing ?? widget.duplicateFrom;
    _clientName = TextEditingController(text: src?.clientName ?? '');
    _address = TextEditingController(text: src?.address ?? '');
    _phone = TextEditingController(text: src?.phone ?? '');
    _billTo = TextEditingController(text: src?.billTo ?? '');
    _runningHour = TextEditingController(text: src?.runningHour ?? '');
    _model = TextEditingController(text: src?.model ?? '');
    _jobDescription = TextEditingController(text: src?.jobDescription ?? '');
    _observations = TextEditingController(text: src?.observations ?? '');
    _recommendations = TextEditingController(text: src?.recommendations ?? '');
    _managerName = TextEditingController(text: src?.managerName ?? '');
    _technicianName = TextEditingController(text: src?.technicianName ?? '');
    _representativeName =
        TextEditingController(text: src?.representativeName ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillPreparedByName();
    });
    _transportation = TextEditingController(
      text: (src?.transportationAmount ?? 0) > 0
          ? src!.transportationAmount.toStringAsFixed(2)
          : '',
    );
    _labour = TextEditingController(
      text: (src?.labourAmount ?? 0) > 0
          ? src!.labourAmount.toStringAsFixed(2)
          : '',
    );
    _nextServiceDate = src?.nextServiceDate;

    final initialItems = src?.items ?? [InvoiceItem()];
    for (final item in initialItems) {
      _rowCtrls.add(_RowCtrls.from(item));
    }
  }

  Future<void> _prefillPreparedByName() async {
    if (_isViewOnly) return;
    if (_managerName.text.trim().isNotEmpty) return;

    final fullName = await AuthService.instance.getUserFullName();
    if (!mounted || fullName == null || _managerName.text.trim().isNotEmpty) {
      return;
    }

    _managerName.text = fullName;
    ref.read(invoiceFormProvider.notifier).updateManagerName(fullName);
  }

  @override
  void dispose() {
    _clientName.dispose();
    _address.dispose();
    _phone.dispose();
    _billTo.dispose();
    _runningHour.dispose();
    _model.dispose();
    _jobDescription.dispose();
    _observations.dispose();
    _recommendations.dispose();
    _managerName.dispose();
    _technicianName.dispose();
    _representativeName.dispose();
    _transportation.dispose();
    _labour.dispose();
    for (final c in _rowCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Item helpers ──────────────────────────────────────────────────────────

  void _addRow() {
    final notifier = ref.read(invoiceFormProvider.notifier);
    if (!notifier.addItem()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An invoice can contain a maximum of 10 items.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _rowCtrls.add(_RowCtrls()));
  }

  Future<void> _removeRow(int index) async {
    if (_rowCtrls.length <= 1) return;

    final ctrl = _rowCtrls[index];
    final isRowEmpty = ctrl.desc.text.trim().isEmpty &&
        ctrl.qty.text.trim().isEmpty &&
        ctrl.price.text.trim().isEmpty;

    // Only ask for confirmation if the row has data
    if (!isRowEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Item'),
          content: const Text('Are you sure you want to remove this item?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL',
                  style: TextStyle(color: AppColors.textDark)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('REMOVE'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final notifier = ref.read(invoiceFormProvider.notifier);
    final deletedItem = ref.read(invoiceFormProvider).items[index];

    setState(() {
      _rowCtrls[index].dispose();
      _rowCtrls.removeAt(index);
    });
    notifier.removeItem(index);

    if (!mounted) return;
    final scaffold = ScaffoldMessenger.of(context);

    final controller = scaffold.showSnackBar(
      SnackBar(
        content:
            const Text('Item removed', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.primaryYellow,
          onPressed: () {
            if (notifier.insertItem(index, deletedItem)) {
              setState(() {
                _rowCtrls.insert(index, _RowCtrls.from(deletedItem));
              });
            }
          },
        ),
      ),
    );

    // Force hide after 5 seconds to bypass Windows infinite-duration accessibility overrides
    Future.delayed(const Duration(seconds: 5), () {
      try {
        controller.close();
      } catch (_) {}
    });
  }

  void _syncItemToState(int index) {
    final ctrl = _rowCtrls[index];
    final qty = double.tryParse(ctrl.qty.text) ?? 0;
    final price = double.tryParse(ctrl.price.text) ?? 0;
    final item = InvoiceItem(
      id: ref.read(invoiceFormProvider).items[index].id,
      description: ctrl.desc.text,
      quantity: qty,
      price: price,
    );
    ref.read(invoiceFormProvider.notifier).updateItem(index, item);
  }

  void _syncTransportToState() {
    ref
        .read(invoiceFormProvider.notifier)
        .updateTransportationAmount(double.tryParse(_transportation.text) ?? 0);
    ref
        .read(invoiceFormProvider.notifier)
        .updateLabourAmount(double.tryParse(_labour.text) ?? 0);
    ref.read(invoiceFormProvider.notifier).updateOtherChargesAmount(0.0);
  }

  // ── Save / export ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    final clientName = _clientName.text.trim();
    final address = _address.text.trim();
    final phone = _phone.text.trim();
    final managerName = _managerName.text.trim();

    String? errorMessage;
    if (clientName.isEmpty) {
      errorMessage = "Please enter the Client's Name.";
    } else if (address.isEmpty) {
      errorMessage = "Please enter the Client's Address.";
    } else if (phone.isEmpty) {
      errorMessage = "Please enter the Client's Telephone number.";
    } else if (managerName.isEmpty) {
      errorMessage = "Please enter the Manager's Name.";
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(errorMessage, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(invoiceFormProvider.notifier).save();
      ref.invalidate(allInvoicesProvider);
      _lastSavedInvoice = ref.read(invoiceFormProvider);
      unawaited(SyncService.instance.sync());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Invoice saved successfully!', AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Error saving invoice: $e', AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _hasUnsavedChanges() {
    final current = ref.read(invoiceFormProvider);
    final saved = _lastSavedInvoice;

    if (saved == null) return true;

    if (current.clientName != saved.clientName ||
        current.address != saved.address ||
        current.phone != saved.phone ||
        current.billTo != saved.billTo ||
        current.runningHour != saved.runningHour ||
        current.model != saved.model ||
        current.nextServiceDate != saved.nextServiceDate ||
        current.jobDescription != saved.jobDescription ||
        current.observations != saved.observations ||
        current.recommendations != saved.recommendations ||
        current.managerName != saved.managerName ||
        current.technicianName != saved.technicianName ||
        current.representativeName != saved.representativeName) {
      return true;
    }

    if (current.transportationAmount != saved.transportationAmount ||
        current.labourAmount != saved.labourAmount ||
        current.otherChargesAmount != saved.otherChargesAmount) {
      return true;
    }

    if (current.items.length != saved.items.length) return true;
    for (int i = 0; i < current.items.length; i++) {
      final a = current.items[i];
      final b = saved.items[i];
      if (a.description != b.description ||
          a.quantity != b.quantity ||
          a.price != b.price) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _promptSaveIfUnsaved() async {
    if (!_hasUnsavedChanges()) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Please save the invoice before performing this action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SAVE NOW'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _save();
      if (!_hasUnsavedChanges()) return true;
    }

    return false;
  }

  Future<void> _print() async {
    if (!await _promptSaveIfUnsaved()) return;
    if (!mounted) return;
    final includeReport = await choosePdfDocumentContents(
      context,
      action: 'Print with Report',
    );
    if (includeReport == null) return;
    final invoice = ref.read(invoiceFormProvider);
    await PdfService.printPdf(invoice, includeServiceReport: includeReport);
  }

  Future<void> _share() async {
    if (!await _promptSaveIfUnsaved()) return;
    if (!mounted) return;
    final includeReport = await choosePdfDocumentContents(
      context,
      action: 'Share with Report',
    );
    if (includeReport == null) return;
    final invoice = ref.read(invoiceFormProvider);
    await PdfService.share(invoice, includeServiceReport: includeReport);
  }

  Future<void> _savePdf() async {
    if (!await _promptSaveIfUnsaved()) return;
    if (!mounted) return;
    final includeReport = await choosePdfDocumentContents(
      context,
      action: 'Save with Report',
    );
    if (includeReport == null) return;
    try {
      final invoice = ref.read(invoiceFormProvider);
      final path = await PdfService.savePdf(invoice,
          includeServiceReport: includeReport);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('PDF Saved to: $path', AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Failed to open save dialog: $e', AppColors.errorRed),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final invoice = ref.watch(invoiceFormProvider);
    final isNew = widget.existing == null;
    final mobile = _isMobile(context);

    final canPop = _isViewOnly || !_hasUnsavedChanges();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text(
                'You have unsaved changes. Do you want to save them before leaving?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('discard'),
                child: const Text('DISCARD',
                    style: TextStyle(color: AppColors.errorRed)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: const Text('CANCEL',
                    style: TextStyle(color: AppColors.textDark)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop('save'),
                child: const Text('SAVE'),
              ),
            ],
          ),
        );

        if (choice == 'discard') {
          if (context.mounted) Navigator.of(context).pop(result);
        } else if (choice == 'save') {
          await _save();
          if (!_hasUnsavedChanges() && context.mounted) {
            Navigator.of(context).pop(result);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: _buildAppBar(isNew),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(mobile ? 10 : 16),
          child: IgnorePointer(
            ignoring: _isViewOnly,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header image ─────────────────────────────────────────────
                _headerImage(),

                const SizedBox(height: 12),

                const SizedBox(height: 12),

                // ── Client + Job Nature ──────────────────────────────────────
                _clientJobCard(invoice, mobile),

                const SizedBox(height: 12),

                // ── Job Info row ─────────────────────────────────────────────
                _jobInfoCard(invoice, mobile),

                const SizedBox(height: 12),

                // ── Items table ──────────────────────────────────────────────
                _itemsCard(invoice, mobile),

                const SizedBox(height: 8),

                // ── Grand Total ──────────────────────────────────────────────
                _grandTotalRow(invoice),

                const SizedBox(height: 12),

                // ── Service Report (PDF page 2) ──────────────────────────────
                _serviceReportCard(),

                const SizedBox(height: 12),

                // ── Signature ────────────────────────────────────────────────
                _signatureCard(),

                const SizedBox(height: 16),

                // ── Footer image ─────────────────────────────────────────────
                _footerImage(),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _isViewOnly ? _viewBottomBar() : _bottomBar(),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isNew) {
    return AppBar(
      iconTheme: const IconThemeData(color: AppColors.primaryBlack),
      title: Text(
          (_isViewOnly
              ? 'View Invoice'
              : (isNew ? 'New Invoice' : 'Edit Invoice')),
          style: const TextStyle(
            color: Colors.black,
          )),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryYellow,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Print',
          icon: const Icon(Icons.print_outlined),
          color: AppColors.primaryBlack,
          onPressed: _print,
        ),
        IconButton(
          tooltip: 'Save PDF',
          icon: const Icon(Icons.download_outlined),
          color: AppColors.primaryBlack,
          onPressed: _savePdf,
        ),
        IconButton(
          tooltip: 'Share',
          icon: const Icon(Icons.share_outlined),
          color: AppColors.primaryBlack,
          onPressed: _share,
        ),
        IconButton(
          tooltip: 'Lock App',
          icon: const Icon(Icons.lock_outline),
          color: AppColors.primaryBlack,
          onPressed: () => ref.read(authProvider.notifier).lock(),
        ),
      ],
    );
  }

  // ── Bottom action bar ────────────────────────────────────────────────────

  Widget _viewBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.yellowLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => InvoiceFormScreen(existing: widget.existing),
              ),
            );
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Invoice'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryYellow,
            foregroundColor: AppColors.primaryBlack,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.yellowLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving…' : 'Save Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Changes'),
        content: const Text(
            'Are you sure you want to cancel? Any unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('NO', style: TextStyle(color: AppColors.textDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Images ────────────────────────────────────────────────────────────────

  Widget _headerImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/full_header.png',
        fit: BoxFit.fitWidth,
        width: double.infinity,
      ),
    );
  }

  Widget _footerImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/full_footer.png',
        fit: BoxFit.fitWidth,
        width: double.infinity,
      ),
    );
  }

  // ── Client + Job Nature ───────────────────────────────────────────────────

  Future<void> _selectClient() async {
    final client = await showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ClientPickerDialog(),
    );

    if (client != null) {
      setState(() {
        _clientName.text = client.name;
        _billTo.text = client.billTo;
        _address.text = client.address;
        _phone.text = client.phone;
      });

      final notifier = ref.read(invoiceFormProvider.notifier);
      notifier.updateClientName(client.name);
      notifier.updateBillTo(client.billTo);
      notifier.updateAddress(client.address);
      notifier.updatePhone(client.phone);
    }
  }

  Future<void> _saveClientAsContact() async {
    final name = _clientName.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client name required to save as contact.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final existingClients = await ref.read(allClientsProvider.future);
    final matchIndex = existingClients
        .indexWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    final existingClient =
        matchIndex != -1 ? existingClients[matchIndex] : null;

    if (existingClient != null && mounted) {
      final action = await showDialog<_ContactConflictAction>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actionsOverflowButtonSpacing: 8,
          title: const Text('Contact Already Exists',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            '"$name" is already in your contacts.\n\n'
            'Would you like to update the existing contact details, or save this as a new contact?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_ContactConflictAction.cancel),
              child: const Text('CANCEL',
                  style: TextStyle(color: AppColors.textDark)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlack,
                side:
                    const BorderSide(color: AppColors.primaryBlack, width: 0.8),
              ),
              onPressed: () =>
                  Navigator.of(ctx).pop(_ContactConflictAction.saveAsNew),
              child: const Text('SAVE AS NEW'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: Colors.black,
              ),
              onPressed: () =>
                  Navigator.of(ctx).pop(_ContactConflictAction.updateExisting),
              child: const Text('UPDATE EXISTING'),
            ),
          ],
        ),
      );

      if (action == null || action == _ContactConflictAction.cancel) {
        return;
      }

      if (action == _ContactConflictAction.updateExisting) {
        final updatedClient = existingClient.copyWith(
          name: name,
          billTo: _billTo.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
        );
        await ref.read(clientRepositoryProvider).update(updatedClient);
        ref.invalidate(allClientsProvider);
        unawaited(SyncService.instance.sync());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated contact "$name".',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return;
      }
    }

    final newClient = Client(
      id: const Uuid().v4(),
      name: name,
      billTo: _billTo.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      createdAt: DateTime.now(),
    );

    await ref.read(clientRepositoryProvider).save(newClient);
    ref.invalidate(allClientsProvider);
    unawaited(SyncService.instance.sync());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $name to contacts.',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _clientJobCard(Invoice invoice, bool mobile) {
    if (mobile) return _clientJobCardMobile(invoice);
    return _clientJobCardDesktop(invoice);
  }

  // ── DESKTOP: Client Details ──────────────────────────────────────────────
  Widget _clientJobCardDesktop(Invoice invoice) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _sectionHeader("CLIENT'S DETAILS")),
                Row(
                  children: [
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.contacts_outlined, size: 16),
                      label: const Text('Select Client',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlack,
                        side: const BorderSide(
                            color: AppColors.primaryBlack, width: 0.8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _selectClient,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text('Save Client',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(
                            color: AppColors.success, width: 0.8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _saveClientAsContact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _formField('Name', _clientName,
                      onChanged: (v) => ref
                          .read(invoiceFormProvider.notifier)
                          .updateClientName(v)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _formField('Bill To', _billTo,
                      onChanged: (v) => ref
                          .read(invoiceFormProvider.notifier)
                          .updateBillTo(v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _formField('Address', _address,
                      onChanged: (v) => ref
                          .read(invoiceFormProvider.notifier)
                          .updateAddress(v)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _formField('Telephone', _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_GhanaPhoneValidator(context)],
                      onChanged: (v) => ref
                          .read(invoiceFormProvider.notifier)
                          .updatePhone(v)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child:
                      _readOnlyField('Invoice Number', invoice.invoiceNumber),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── MOBILE: Client Details stacked vertically ─────────────────────────────
  Widget _clientJobCardMobile(Invoice invoice) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Client header + action buttons ──────────────────
            _sectionHeader("CLIENT'S DETAILS"),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.contacts_outlined, size: 16),
                    label: const Text('Select Client',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlack,
                      side: const BorderSide(
                          color: AppColors.primaryBlack, width: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _selectClient,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Save Client',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(
                          color: AppColors.success, width: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveClientAsContact,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _formField('Name', _clientName,
                onChanged: (v) =>
                    ref.read(invoiceFormProvider.notifier).updateClientName(v)),
            const SizedBox(height: 10),
            _formField('Bill To', _billTo,
                onChanged: (v) =>
                    ref.read(invoiceFormProvider.notifier).updateBillTo(v)),
            const SizedBox(height: 10),
            _formField('Address', _address,
                onChanged: (v) =>
                    ref.read(invoiceFormProvider.notifier).updateAddress(v)),
            const SizedBox(height: 10),
            _formField('Telephone', _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [_GhanaPhoneValidator(context)],
                onChanged: (v) =>
                    ref.read(invoiceFormProvider.notifier).updatePhone(v)),
            const SizedBox(height: 10),
            _readOnlyField('Invoice Number', invoice.invoiceNumber),
          ],
        ),
      ),
    );
  }

  // ── Job Info Row ──────────────────────────────────────────────────────────

  Widget _jobInfoCard(Invoice invoice, bool mobile) {
    final date = _formatDate(invoice.date);

    if (mobile) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _readOnlyField('DATE', date)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _formField('RUNNING HOUR', _runningHour,
                        onChanged: (v) => ref
                            .read(invoiceFormProvider.notifier)
                            .updateRunningHour(v)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _formField('MODEL / MAKE', _model,
                  onChanged: (v) =>
                      ref.read(invoiceFormProvider.notifier).updateModel(v)),
              const SizedBox(height: 10),
              // Next Service Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEXT SERVICE DATE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlack)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _pickNextServiceDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(),
                      child: Text(
                        _nextServiceDate != null
                            ? '${_nextServiceDate!.day.toString().padLeft(2, '0')}/${_nextServiceDate!.month.toString().padLeft(2, '0')}/${_nextServiceDate!.year}'
                            : 'Tap to select…',
                        style: TextStyle(
                          color: _nextServiceDate != null
                              ? AppColors.textDark
                              : AppColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Desktop: single row
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: _readOnlyField('DATE', date)),
            const SizedBox(width: 8),
            Expanded(
              child: _formField('RUNNING HOUR', _runningHour,
                  onChanged: (v) => ref
                      .read(invoiceFormProvider.notifier)
                      .updateRunningHour(v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _formField('MODEL / MAKE', _model,
                  onChanged: (v) =>
                      ref.read(invoiceFormProvider.notifier).updateModel(v)),
            ),
            const SizedBox(width: 8),
            // Next Service Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEXT SERVICE DATE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlack)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _pickNextServiceDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(),
                      child: Text(
                        _nextServiceDate != null
                            ? '${_nextServiceDate!.day.toString().padLeft(2, '0')}/${_nextServiceDate!.month.toString().padLeft(2, '0')}/${_nextServiceDate!.year}'
                            : 'Tap to select…',
                        style: TextStyle(
                          color: _nextServiceDate != null
                              ? AppColors.textDark
                              : AppColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Items Table ───────────────────────────────────────────────────────────

  Widget _itemsCard(Invoice invoice, bool mobile) {
    if (mobile) return _itemsCardMobile(invoice);
    return _itemsCardDesktop(invoice);
  }

  Widget _buildAddItemControl(Invoice invoice, {bool isMobile = false}) {
    final itemCount = invoice.items.length;
    const maxItems = InvoiceFormNotifier.maxItems;
    final atLimit = itemCount >= maxItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$itemCount of $maxItems items — maximum $maxItems items per invoice',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: atLimit ? AppColors.errorRed : AppColors.textGrey,
            fontSize: 11,
            fontWeight: atLimit ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: atLimit ? null : _addRow,
          icon: Icon(Icons.add_circle_outline,
              color: atLimit ? AppColors.textLightGrey : AppColors.primaryBlack,
              size: isMobile ? 20 : null),
          label: Text(
            atLimit ? 'Maximum of $maxItems Items Reached' : 'Add Item',
            style: TextStyle(
              color: atLimit ? AppColors.textLightGrey : AppColors.primaryBlack,
              fontWeight: isMobile ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: atLimit ? AppColors.borderGrey : AppColors.primaryBlack),
            padding: isMobile
                ? const EdgeInsets.symmetric(vertical: 12)
                : EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 10 : 8)),
          ),
        ),
      ],
    );
  }

  // ── DESKTOP items table (original) ────────────────────────────────────────
  Widget _itemsCardDesktop(Invoice invoice) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.blackGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text('DESCRIPTION OF GOODS / SERVICES',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                SizedBox(
                  width: 52,
                  child: Text('QTY',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 80,
                  child: Text('PRICE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 90,
                  child: Text('TOTAL AMT.',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      textAlign: TextAlign.center),
                ),
                SizedBox(width: 32),
              ],
            ),
          ),

          // Item rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: invoice.items.length,
            itemBuilder: (ctx, i) => _itemRowDesktop(i, invoice.items[i]),
          ),

          // Add row button
          Padding(
            padding: const EdgeInsets.all(10),
            child: _buildAddItemControl(invoice),
          ),

          // ── Sub-total row ──────────────────────────────────────────────
          Container(
            color: AppColors.tableRowLight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 32),
                const Expanded(
                  child: Text(
                    'SUB-TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.textDark,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 52), // QTY column placeholder
                const SizedBox(width: 6),
                const SizedBox(width: 80), // PRICE column placeholder
                const SizedBox(width: 6),
                SizedBox(
                  width: 90,
                  child: Text(
                    CurrencyFormatter.formatRaw(invoice.itemsSubTotal),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                ),
                const SizedBox(width: 32), // delete-button placeholder
              ],
            ),
          ),

          // ── Charges rows ──────────────────────────────────────────────────
          _chargesRow(
              'Transportation', _transportation, Icons.local_shipping_outlined),
          _chargesRow('Labour', _labour, Icons.engineering_outlined),
        ],
      ),
    );
  }

  // ── DESKTOP item row (original) ───────────────────────────────────────────
  Widget _itemRowDesktop(int index, InvoiceItem item) {
    if (index >= _rowCtrls.length) return const SizedBox.shrink();

    final ctrl = _rowCtrls[index];
    final bg = index.isEven ? AppColors.tableRowLight : Colors.white;
    final total = (double.tryParse(ctrl.qty.text) ?? 0) *
        (double.tryParse(ctrl.price.text) ?? 0);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Row number
          SizedBox(
            width: 32,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.primaryBlack),
            ),
          ),

          // Description
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TextField(
                controller: ctrl.desc,
                decoration: const InputDecoration(
                  hintText: 'Item description…',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (_) => _syncItemToState(index),
              ),
            ),
          ),

          // QTY
          SizedBox(
            width: 52,
            child: TextField(
              controller: ctrl.qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_NumberInputValidator(context)],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '0',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              onChanged: (_) {
                _syncItemToState(index);
                setState(() {}); // update total display
              },
            ),
          ),

          const SizedBox(width: 6),

          // PRICE
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl.price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_NumberInputValidator(context)],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0.00',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
              onChanged: (_) {
                _syncItemToState(index);
                setState(() {});
              },
            ),
          ),

          const SizedBox(width: 6),

          // TOTAL (read-only)
          SizedBox(
            width: 90,
            child: Text(
              CurrencyFormatter.formatRaw(total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlack,
                  fontSize: 13),
            ),
          ),

          // Delete
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppColors.errorRed, size: 20),
              tooltip: 'Remove row',
              onPressed: _rowCtrls.length > 1 ? () => _removeRow(index) : null,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MOBILE ITEMS — card-based layout
  // ══════════════════════════════════════════════════════════════════════════

  Widget _itemsCardMobile(Invoice invoice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        _sectionHeader('DESCRIPTION OF GOODS / SERVICES'),
        const SizedBox(height: 8),

        // Item cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: invoice.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _itemCardMobile(i, invoice.items[i]),
        ),

        const SizedBox(height: 10),

        // Add item button
        _buildAddItemControl(invoice, isMobile: true),

        const SizedBox(height: 10),

        // Sub-total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.tableRowLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SUB-TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textDark,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                CurrencyFormatter.formatRaw(invoice.itemsSubTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primaryBlack,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Transportation
        _chargesRowMobile(
            'Transportation', _transportation, Icons.local_shipping_outlined),
        const SizedBox(height: 6),
        // Labour
        _chargesRowMobile('Labour', _labour, Icons.engineering_outlined),
      ],
    );
  }

  Widget _itemCardMobile(int index, InvoiceItem item) {
    if (index >= _rowCtrls.length) return const SizedBox.shrink();

    final ctrl = _rowCtrls[index];
    final total = (double.tryParse(ctrl.qty.text) ?? 0) *
        (double.tryParse(ctrl.price.text) ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top bar: item number + delete ────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withValues(alpha: 0.2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                if (_rowCtrls.length > 1)
                  GestureDetector(
                    onTap: () => _removeRow(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: AppColors.errorRed, size: 18),
                    ),
                  ),
              ],
            ),
          ),

          // ── Description ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: ctrl.desc,
              decoration: const InputDecoration(
                hintText: 'Item description…',
                labelText: 'Description',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              onChanged: (_) => _syncItemToState(index),
            ),
          ),

          // ── QTY + Price row ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                // QTY
                Expanded(
                  child: TextField(
                    controller: ctrl.qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_NumberInputValidator(context)],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '0',
                      labelText: 'Qty',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    onChanged: (_) {
                      _syncItemToState(index);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Price
                Expanded(
                  child: TextField(
                    controller: ctrl.price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_NumberInputValidator(context)],
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      labelText: 'Price',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    onChanged: (_) {
                      _syncItemToState(index);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Total
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatRaw(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlack,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Grand Total ───────────────────────────────────────────────────────────

  Widget _grandTotalRow(Invoice invoice) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.blackGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Items sub-total line
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Items Sub-Total:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  CurrencyFormatter.format(invoice.itemsSubTotal),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
            // Transportation + Labour lines
            _totalsSubRow('Transportation:',
                CurrencyFormatter.format(invoice.transportationAmount)),
            _totalsSubRow(
                'Labour:', CurrencyFormatter.format(invoice.labourAmount)),
            // Divider
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(color: Colors.white38, height: 1),
            ),
            // Grand total
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GRAND TOTAL:',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(width: 16),
                Text(
                  CurrencyFormatter.format(invoice.grandTotal),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Service Report ───────────────────────────────────────────────────────

  Widget _serviceReportCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                'GENERATOR SERVICE REPORT & TECHNICAL REMARKS (Second Part)'),
            const SizedBox(height: 10),
            TextField(
              controller: _jobDescription,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Work performed',
                hintText: 'Describe the maintenance or service completed…',
                alignLabelWithHint: true,
              ),
              onChanged: (v) => ref
                  .read(invoiceFormProvider.notifier)
                  .updateJobDescription(v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observations,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observations / condition found',
                hintText:
                    'Record findings, faults, measurements, or equipment condition…',
                alignLabelWithHint: true,
              ),
              onChanged: (v) =>
                  ref.read(invoiceFormProvider.notifier).updateObservations(v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recommendations,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Recommendations / next actions',
                hintText:
                    'State follow-up work, monitoring advice, or replacement needs…',
                alignLabelWithHint: true,
              ),
              onChanged: (v) => ref
                  .read(invoiceFormProvider.notifier)
                  .updateRecommendations(v),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            _sectionHeader('SIGN-OFF & ACCEPTANCE DETAILS'),
            const SizedBox(height: 10),
            if (_isMobile(context)) ...[
              TextField(
                controller: _technicianName,
                readOnly: _isViewOnly,
                decoration: const InputDecoration(
                  labelText: 'Technician name',
                  hintText: 'Enter name of technician (e.g. Kwaku TK)',
                  prefixIcon: Icon(Icons.engineering_outlined),
                ),
                onChanged: (v) => ref
                    .read(invoiceFormProvider.notifier)
                    .updateTechnicianName(v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _representativeName,
                readOnly: _isViewOnly,
                decoration: const InputDecoration(
                  labelText: 'Client representative name',
                  hintText: 'Enter client representative accepting the service',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (v) => ref
                    .read(invoiceFormProvider.notifier)
                    .updateRepresentativeName(v),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _technicianName,
                      readOnly: _isViewOnly,
                      decoration: const InputDecoration(
                        labelText: 'Technician name',
                        hintText: 'Enter name of technician (e.g. Kwaku TK)',
                        prefixIcon: Icon(Icons.engineering_outlined),
                      ),
                      onChanged: (v) => ref
                          .read(invoiceFormProvider.notifier)
                          .updateTechnicianName(v),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _representativeName,
                      readOnly: _isViewOnly,
                      decoration: const InputDecoration(
                        labelText: 'Client representative name',
                        hintText:
                            'Enter client representative accepting the service',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onChanged: (v) => ref
                          .read(invoiceFormProvider.notifier)
                          .updateRepresentativeName(v),
                    ),
                  ),
                ],
              ),
            ],

            // hidden for the mean time -------------
            //  const SizedBox(height: 10),
            //  const Text(
            //    'The parts and consumables section on the report is generated automatically from the invoice items.',
            //    style: TextStyle(color: AppColors.textGrey, fontSize: 12),
            //  ),
          ],
        ),
      ),
    );
  }

  // ── Prepared By ──────────────────────────────────────────────────────────

  Widget _signatureCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('PREPARED BY'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.yellowLight,
                          border: Border.all(color: AppColors.borderYellow),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Text(
                          "Timo's Engineering Service",
                          style: TextStyle(
                            color: AppColors.primaryBlack,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _formField('Name', _managerName, readOnly: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // ── Totals sub-row (in the live blue summary box) ────────────────────────
  Widget _totalsSubRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 12)),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  // ── Charges row – desktop table ───────────────────────────────────────────
  Widget _chargesRow(String label, TextEditingController ctrl, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.yellowLight.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
              color: AppColors.borderYellow.withValues(alpha: 0.5), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            child: Icon(icon, size: 16, color: AppColors.primaryBlack),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          // QTY – blank (N/A)
          const SizedBox(
            width: 52,
            child: Text(
              '—',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          const SizedBox(width: 6),
          // Amount input
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_NumberInputValidator(context)],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0.00',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
              onChanged: (_) {
                _syncTransportToState();
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 6),
          // Display value
          SizedBox(
            width: 90,
            child: Text(
              CurrencyFormatter.formatRaw(double.tryParse(ctrl.text) ?? 0),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlack,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  // ── Charges row – mobile ──────────────────────────────────────────────────
  Widget _chargesRowMobile(
      String label, TextEditingController ctrl, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.yellowLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.borderYellow.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlack),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_NumberInputValidator(context)],
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: '0.00',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: AppColors.borderYellow.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: AppColors.borderYellow.withValues(alpha: 0.5)),
                ),
              ),
              onChanged: (_) {
                _syncTransportToState();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Next Service Date picker ──────────────────────────────────────────────
  Future<void> _pickNextServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _nextServiceDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _nextServiceDate = picked);
      ref.read(invoiceFormProvider.notifier).updateNextServiceDate(picked);
    }
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: const BoxDecoration(
        gradient: AppColors.blackGradient,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _formField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlack)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          decoration: const InputDecoration(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlack)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.yellowLight.withValues(alpha: 0.6),
            border: Border.all(
                color: AppColors.borderYellow.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlack),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  SnackBar _snackBar(String msg, Color color) {
    return SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ── Row controller helper ─────────────────────────────────────────────────────

class _RowCtrls {
  final TextEditingController desc;
  final TextEditingController qty;
  final TextEditingController price;

  _RowCtrls()
      : desc = TextEditingController(),
        qty = TextEditingController(),
        price = TextEditingController();

  _RowCtrls.from(InvoiceItem item)
      : desc = TextEditingController(text: item.description),
        qty = TextEditingController(
            text: item.quantity > 0 ? item.quantity.toString() : ''),
        price = TextEditingController(
            text: item.price > 0 ? item.price.toString() : '');

  void dispose() {
    desc.dispose();
    qty.dispose();
    price.dispose();
  }
}

// ── Number Input Validator ──────────────────────────────────────────────────

class _NumberInputValidator extends TextInputFormatter {
  final BuildContext context;
  _NumberInputValidator(this.context);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Allow digits and up to one decimal point
    final regExp = RegExp(r'^\d*\.?\d*$');
    if (regExp.hasMatch(newValue.text)) {
      return newValue;
    }

    // Invalid character attempted, alert user

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Only numbers and decimals are allowed',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    return oldValue;
  }
}

// ── Ghana Phone Validator ───────────────────────────────────────────────────

class _GhanaPhoneValidator extends TextInputFormatter {
  final BuildContext context;
  _GhanaPhoneValidator(this.context);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    if (newValue.text.contains(RegExp(r'[a-zA-Z]'))) {
      _showAlert('Only numbers are allowed for phone numbers');
      return oldValue;
    }

    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 20) {
      _showAlert('You can only enter up to 2 phone numbers (max 20 digits)');
      return oldValue;
    }

    String formatted = digits;
    if (digits.length > 10) {
      formatted = '${digits.substring(0, 10)}, ${digits.substring(10)}';
    }

    int digitsBeforeCursor = 0;
    for (int i = 0;
        i < newValue.selection.baseOffset && i < newValue.text.length;
        i++) {
      if (RegExp(r'[0-9]').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    int newCursorOffset = 0;
    int digitsCounted = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (digitsCounted == digitsBeforeCursor) {
        newCursorOffset = i;
        break;
      }
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        digitsCounted++;
      }
      newCursorOffset = i + 1;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }

  void _showAlert(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }
}

enum _ContactConflictAction { cancel, saveAsNew, updateExisting }
