import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/sync_service.dart';
import '../../../data/models/invoice.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../auth/services/auth_service.dart';
import '../controllers/invoice_controller.dart';
import '../controllers/client_controller.dart';
import '../services/pdf_service.dart';
import '../widgets/home_empty_state.dart';
import '../widgets/invoice_card.dart';
import '../widgets/pdf_document_choice_dialog.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/stats_row.dart';
import 'invoice_form_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();

    // Auto-refresh UI whenever background sync finishes
    _syncSubscription = SyncService.instance.onSyncCompleted.listen((_) {
      if (mounted) {
        ref.invalidate(allInvoicesProvider);
        ref.invalidate(allClientsProvider);
      }
    });

    // Trigger initial background sync on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SyncService.instance.sync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allInvoicesProvider);
    final filteredAsync = ref.watch(filteredInvoicesProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, isMobile),
        ],
        body: allAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryYellow),
          ),
          error: (e, _) => _errorView(e.toString()),
          data: (allInvoices) {
            final filtered = filteredAsync.valueOrNull ?? allInvoices;

            return RefreshIndicator(
              color: AppColors.primaryBlack,
              onRefresh: () async {
                ref.invalidate(allInvoicesProvider);
                await SyncService.instance.sync();
              },
              child: CustomScrollView(
                slivers: [
                  // Search bar
                  const SliverToBoxAdapter(child: InvoiceSearchBar()),

                  // Stats
                  if (allInvoices.isNotEmpty)
                    SliverToBoxAdapter(child: StatsRow(invoices: allInvoices)),

                  // List
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: HomeEmptyState(
                        onCreateNew: () => _createNew(context),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => InvoiceCard(
                            invoice: filtered[i],
                            onEdit: () => _openEdit(context, filtered[i]),
                            onCopy: () => _duplicate(context, filtered[i]),
                            onPrint: () => _print(context, filtered[i]),
                            onSave: () => _savePdf(context, filtered[i]),
                            onShare: () => _share(context, filtered[i]),
                            onDelete: () =>
                                _deleteInvoice(context, filtered[i]),
                            onConfirmDismiss: () =>
                                _confirmDelete(context, filtered[i]),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      // Mobile: icon-only FAB; Desktop: extended FAB
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _createNew(context),
              backgroundColor: AppColors.primaryYellow,
              elevation: 6,
              shape: const CircleBorder(),
              tooltip: 'New Invoice',
              child: const Icon(Icons.add,
                  color: AppColors.primaryBlack, size: 28),
            )
          : FloatingActionButton.extended(
              onPressed: () => _createNew(context),
              mouseCursor: SystemMouseCursors.click,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add, color: AppColors.primaryBlack),
              label: const Text(
                'New Invoice',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primaryBlack,
                ),
              ),
              backgroundColor: AppColors.primaryYellow,
              elevation: 6,
            ),
    );
  }

  // ── Sliver App Bar ──────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context, bool isMobile) {
    final expandedHeight = isMobile ? 110.0 : 160.0;
    final logoHeight = isMobile ? 56.0 : 90.0;
    final logoTop = isMobile ? 14.0 : 28.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primaryBlack,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TIMO'S ENGINEERING",
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Invoice Manager',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isMobile ? 9 : 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.blackGradient),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -30,
                top: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                right: 60,
                bottom: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // Logo watermark
              Positioned(
                right: 16,
                top: logoTop,
                child: Image.asset(
                  'assets/timo_icon.png',
                  height: logoHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _buildSyncButton(context),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () {
            ref.invalidate(allInvoicesProvider);
            SyncService.instance.sync();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.security_outlined, color: Colors.white),
          tooltip: 'Security',
          onSelected: (value) => _onSecurityAction(context, value),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'change_pin',
              child: ListTile(
                leading: Icon(Icons.lock_reset_outlined,
                    color: AppColors.primaryBlack),
                title: Text('Change password'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'lock_now',
              child: ListTile(
                leading: Icon(Icons.lock_outlined, color: AppColors.errorRed),
                title: Text('Lock Now'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.status,
      builder: (context, status, _) {
        Widget icon;
        String tooltip;

        switch (status) {
          case SyncStatus.syncing:
            icon = const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryYellow,
              ),
            );
            tooltip = 'Syncing with cloud...';
            break;
          case SyncStatus.success:
            icon = const Icon(Icons.cloud_done_rounded,
                color: AppColors.success, size: 22);
            tooltip = 'Cloud synced';
            break;
          case SyncStatus.offline:
            icon = const Icon(Icons.cloud_off_rounded,
                color: Colors.white54, size: 22);
            tooltip = 'Offline - will sync when connected';
            break;
          case SyncStatus.error:
            icon = const Icon(Icons.sync_problem_rounded,
                color: AppColors.errorRed, size: 22);
            tooltip = 'Sync issue (tap to retry)';
            break;
          case SyncStatus.idle:
            icon = const Icon(Icons.cloud_sync_outlined,
                color: Colors.white, size: 22);
            tooltip = 'Sync with cloud';
            break;
        }

        return IconButton(
          icon: icon,
          tooltip: tooltip,
          onPressed: () async {
            final scaffold = ScaffoldMessenger.of(context);
            scaffold.hideCurrentSnackBar();
            scaffold.showSnackBar(
              const SnackBar(
                content:
                    Text('Synchronizing invoices and clients with cloud...'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            final ok = await SyncService.instance.sync(force: true);
            if (mounted) {
              final lastTime = SyncService.instance.lastSyncTime.value;
              final timeStr = lastTime != null
                  ? DateFormat('h:mm a').format(lastTime.toLocal())
                  : 'Just now';
              scaffold.hideCurrentSnackBar();
              scaffold.showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Sync complete ($timeStr)'
                      : (SyncService.instance.lastErrorMessage.value ??
                          'Could not reach cloud. Offline mode active.')),
                  backgroundColor:
                      ok ? AppColors.success : AppColors.yellowDark,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }

  // ── Error view ────────────────────────────────────────────────────────

  Widget _errorView(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 50, color: AppColors.errorRed),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(allInvoicesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────

  void _onSecurityAction(BuildContext context, String action) {
    if (action == 'change_pin') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
      );
    } else if (action == 'lock_now') {
      ref.read(authProvider.notifier).lock();
    }
  }

  Future<void> _createNew(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
    );
    ref.invalidate(allInvoicesProvider);
  }

  Future<void> _openEdit(BuildContext context, Invoice invoice) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoiceFormScreen(existing: invoice)),
    );
    ref.invalidate(allInvoicesProvider);
  }

  Future<void> _duplicate(BuildContext context, Invoice invoice) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => InvoiceFormScreen(duplicateFrom: invoice)),
    );
    ref.invalidate(allInvoicesProvider);
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppColors.errorRed : AppColors.primaryBlack,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _print(BuildContext context, Invoice invoice) async {
    final includeReport = await choosePdfDocumentContents(
      context,
      action: 'Print with Report',
    );
    if (includeReport == null || !context.mounted) return;
    _showSnack(context, 'Preparing document for printing...');
    try {
      await PdfService.printPdf(invoice, includeServiceReport: includeReport);
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'Printing failed. Please try again.', isError: true);
    }
  }

  Future<void> _share(BuildContext context, Invoice invoice) async {
    final includeReport = await choosePdfDocumentContents(
      context,
      action: 'Share with Report',
    );
    if (includeReport == null || !context.mounted) return;
    _showSnack(context, 'Preparing document for sharing...');
    try {
      await PdfService.share(invoice, includeServiceReport: includeReport);
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'Sharing failed. Please try again.', isError: true);
    }
  }

  Future<void> _savePdf(BuildContext context, Invoice invoice) async {
    final includeReport = await choosePdfDocumentContents(
      context,
      action: 'Save with Report',
    );
    if (includeReport == null || !context.mounted) return;
    _showSnack(context, 'Preparing document to save...');
    try {
      final path = await PdfService.savePdf(invoice,
          includeServiceReport: includeReport);
      if (!context.mounted) return;
      if (path != null) {
        _showSnack(context, 'Saved to: $path');
      } else {
        _showSnack(context, 'Save canceled.');
      }
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'Saving failed. Please try again.', isError: true);
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Invoice',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Delete invoice ${invoice.invoiceNumber}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    if (!context.mounted) return false;
    return await _promptForDeletePassword(context);
  }

  Future<bool> _promptForDeletePassword(BuildContext context) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    int attempts = 0;
    bool obscure = true;
    String? error;
    bool isBusy = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void verify() async {
              final pwd = controller.text.trim();
              if (pwd.isEmpty) return;

              setState(() => isBusy = true);
              final res = await AuthService.instance.verifyPassword(pwd);
              if (!ctx.mounted) return;
              setState(() => isBusy = false);

              if (res.success) {
                Navigator.pop(ctx, true);
              } else {
                attempts++;
                controller.clear();
                if (attempts >= 2) {
                  Navigator.pop(ctx, false);
                } else {
                  setState(() {
                    error = 'Incorrect password. You have 1 attempt remaining.';
                  });
                  focus.requestFocus();
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.security, color: AppColors.errorRed),
                  SizedBox(width: 8),
                  Text('Security Verification',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Please enter your password to authorize this deletion.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    focusNode: focus,
                    obscureText: obscure,
                    autofocus: true,
                    enabled: !isBusy,
                    onSubmitted: (_) => verify(),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      errorText: error,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isBusy ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isBusy ? null : verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
                    foregroundColor: Colors.white,
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteInvoice(BuildContext context, Invoice invoice) async {
    final repo = ref.read(invoiceRepositoryProvider);
    await repo.delete(invoice.id);
    ref.invalidate(allInvoicesProvider);
    unawaited(SyncService.instance.sync());

    if (!context.mounted) return;
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();

    final controller = scaffold.showSnackBar(
      SnackBar(
        content: Text('Invoice ${invoice.invoiceNumber} deleted.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorRed,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () async {
            await repo.save(invoice);
            ref.invalidate(allInvoicesProvider);
            unawaited(SyncService.instance.sync());
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
}
