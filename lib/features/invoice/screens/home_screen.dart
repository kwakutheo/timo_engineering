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
import '../widgets/navigation_tab_pills.dart';
import '../widgets/pdf_document_choice_dialog.dart';
import '../widgets/search_bar_widget.dart';
import 'invoice_form_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Deleting an invoice is reserved for the software owner. This credential is
  // deliberately separate from the regular app-lock password.
  static const _ownerDeletionPassword = 'Timo_Admin';
  static const int _pageSize = 25;

  int _currentPage = 1;
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

  void _goToPage(int page, int totalPages) {
    final targetPage = page.clamp(1, totalPages);
    if (targetPage == _currentPage) return;
    setState(() {
      _currentPage = targetPage;
    });

    // Scroll smoothly back to top of list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        PrimaryScrollController.maybeOf(context)?.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    });
  }

  List<int?> _getPageNumbers(int current, int total) {
    if (total <= 7) {
      return List<int?>.generate(total, (i) => i + 1);
    }

    final pages = <int>{};
    pages.add(1);
    pages.add(total);

    for (int p = current - 1; p <= current + 1; p++) {
      if (p >= 1 && p <= total) {
        pages.add(p);
      }
    }

    if (current <= 3) {
      pages.add(2);
      pages.add(3);
    }
    if (current >= total - 2) {
      pages.add(total - 1);
      pages.add(total - 2);
    }

    final sorted = pages.toList()..sort();
    final result = <int?>[];

    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] > sorted[i - 1] + 1) {
        result.add(null);
      }
      result.add(sorted[i]);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Reset to page 1 whenever the user searches
    ref.listen<String>(searchQueryProvider, (previous, next) {
      if (previous != next && _currentPage != 1) {
        setState(() {
          _currentPage = 1;
        });
      }
    });

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
            final totalItems = filtered.length;
            final totalPages =
                totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
            final currentPage = _currentPage.clamp(1, totalPages);

            if (_currentPage != currentPage) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _currentPage = currentPage);
                }
              });
            }

            final startIndex = (currentPage - 1) * _pageSize;
            final endIndex = (startIndex + _pageSize).clamp(0, totalItems);
            final pageInvoices = totalItems == 0
                ? <Invoice>[]
                : filtered.sublist(startIndex, endIndex);

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

                  // List
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: HomeEmptyState(
                        onCreateNew: () => _createNew(context),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final invoice = pageInvoices[i];
                            return InvoiceCard(
                              invoice: invoice,
                              onView: () => _openView(context, invoice),
                              onCopy: () => _duplicate(context, invoice),
                              onPrint: () => _print(context, invoice),
                              onSave: () => _savePdf(context, invoice),
                              onShare: () => _share(context, invoice),
                              onDelete: () => _deleteInvoice(context, invoice),
                              onConfirmDismiss: () =>
                                  _confirmDelete(context, invoice),
                            );
                          },
                          childCount: pageInvoices.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isMobile ? 12 : 16,
                          4,
                          isMobile ? 12 : 16,
                          isMobile ? 96 : 88,
                        ),
                        child: _buildPaginationBar(
                          isMobile: isMobile,
                          totalItems: totalItems,
                          currentPage: currentPage,
                          totalPages: totalPages,
                          startIndex: startIndex,
                          endIndex: endIndex,
                        ),
                      ),
                    ),
                  ],
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
      // Keep the header visibly raised even before the user scrolls.
      forceElevated: true,
      elevation: 12,
      scrolledUnderElevation: 12,
      shadowColor: Colors.black87,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.primaryYellow,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TIMO'S ENGINEERING",
              style: TextStyle(
                color: AppColors.primaryBlack,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Invoice Manager',
              style: TextStyle(
                color: AppColors.primaryBlack.withValues(alpha: 0.72),
                fontSize: isMobile ? 9 : 10,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: AppColors.yellowGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
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
                    color: Colors.black.withValues(alpha: 0.2),
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
                    color: Colors.black.withValues(alpha: 0.2),
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
        if (!isMobile) ...[
          const Center(child: NavigationTabPills()),
          const SizedBox(width: 8),
        ],
        _buildSyncButton(context),
        IconButton(
          tooltip: 'Refresh',
          icon:
              const Icon(Icons.refresh_rounded, color: AppColors.primaryBlack),
          onPressed: () {
            ref.invalidate(allInvoicesProvider);
            SyncService.instance.sync();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.security_outlined,
              color: AppColors.primaryBlack),
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
              value: 'edit_full_name',
              child: ListTile(
                leading:
                    Icon(Icons.badge_outlined, color: AppColors.primaryBlack),
                title: Text('Edit full name'),
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
                color: AppColors.primaryBlack,
              ),
            );
            tooltip = 'Syncing with cloud...';
            break;
          case SyncStatus.success:
            icon = const Icon(Icons.cloud_done_rounded,
                color: Color.fromARGB(255, 255, 255, 255), size: 22);
            tooltip = 'Cloud synced';
            break;
          case SyncStatus.offline:
            icon = const Icon(Icons.cloud_off_rounded,
                color: AppColors.textGrey, size: 22);
            tooltip = 'Offline - will sync when connected';
            break;
          case SyncStatus.error:
            icon = const Icon(Icons.sync_problem_rounded,
                color: AppColors.errorRed, size: 22);
            tooltip = 'Sync issue (tap to retry)';
            break;
          case SyncStatus.idle:
            icon = const Icon(Icons.cloud_sync_outlined,
                color: AppColors.primaryBlack, size: 22);
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

  // ── Pagination bar ─────────────────────────────────────────────────────

  Widget _buildPaginationBar({
    required bool isMobile,
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    final countNoun = totalItems == 1 ? 'invoice' : 'invoices';
    final String rangeText;
    if (totalItems == 0) {
      rangeText = 'No invoices found';
    } else if (totalItems <= _pageSize) {
      rangeText = 'Showing all $totalItems $countNoun';
    } else if (startIndex + 1 == endIndex) {
      rangeText = 'Showing invoice $endIndex of $totalItems';
    } else {
      rangeText =
          'Showing ${startIndex + 1}–$endIndex of $totalItems $countNoun';
    }

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.borderGrey.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 16, color: AppColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  rangeText,
                  style: const TextStyle(
                    color: AppColors.primaryBlack,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            if (totalPages > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'First page',
                    icon: const Icon(Icons.first_page_rounded, size: 22),
                    color: AppColors.primaryBlack,
                    disabledColor: AppColors.textGrey.withValues(alpha: 0.35),
                    onPressed:
                        currentPage > 1 ? () => _goToPage(1, totalPages) : null,
                  ),
                  IconButton(
                    tooltip: 'Previous page',
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    color: AppColors.primaryBlack,
                    disabledColor: AppColors.textGrey.withValues(alpha: 0.35),
                    onPressed: currentPage > 1
                        ? () => _goToPage(currentPage - 1, totalPages)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryYellow.withValues(alpha: 0.9),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      'Page $currentPage of $totalPages',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.primaryBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Next page',
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    color: AppColors.primaryBlack,
                    disabledColor: AppColors.textGrey.withValues(alpha: 0.35),
                    onPressed: currentPage < totalPages
                        ? () => _goToPage(currentPage + 1, totalPages)
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Last page',
                    icon: const Icon(Icons.last_page_rounded, size: 22),
                    color: AppColors.primaryBlack,
                    disabledColor: AppColors.textGrey.withValues(alpha: 0.35),
                    onPressed: currentPage < totalPages
                        ? () => _goToPage(totalPages, totalPages)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Desktop / Tablet layout
    final pageNumbers = _getPageNumbers(currentPage, totalPages);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGrey.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 18, color: AppColors.textGrey),
              const SizedBox(width: 8),
              Text(
                rangeText,
                style: const TextStyle(
                  color: AppColors.primaryBlack,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '25 / page',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (totalPages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: currentPage > 1
                      ? () => _goToPage(currentPage - 1, totalPages)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlack,
                    disabledForegroundColor:
                        AppColors.textGrey.withValues(alpha: 0.35),
                    side: BorderSide(
                      color: currentPage > 1
                          ? AppColors.borderGrey
                          : AppColors.borderGrey.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                for (final p in pageNumbers) ...[
                  if (p == null)
                    const SizedBox(
                      width: 26,
                      height: 34,
                      child: Center(
                        child: Text(
                          '…',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else if (p == currentPage)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primaryYellow.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$p',
                        style: const TextStyle(
                          color: AppColors.primaryBlack,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => _goToPage(p, totalPages),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.borderGrey
                                    .withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            '$p',
                            style: const TextStyle(
                              color: AppColors.primaryBlack,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: currentPage < totalPages
                      ? () => _goToPage(currentPage + 1, totalPages)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlack,
                    disabledForegroundColor:
                        AppColors.textGrey.withValues(alpha: 0.35),
                    side: BorderSide(
                      color: currentPage < totalPages
                          ? AppColors.borderGrey
                          : AppColors.borderGrey.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next'),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Page 1 of 1',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _onSecurityAction(BuildContext context, String action) async {
    if (action == 'change_pin') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
      );
    } else if (action == 'edit_full_name') {
      await _editFullName(context);
    } else if (action == 'lock_now') {
      ref.read(authProvider.notifier).lock();
    }
  }

  Future<void> _editFullName(BuildContext context) async {
    final currentName = await AuthService.instance.getUserFullName() ?? '';
    if (!context.mounted) return;

    final controller = TextEditingController(text: currentName);
    final focus = FocusNode();
    String? error;
    bool isSaving = false;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> save() async {
            final validation =
                AuthService.instance.validateFullName(controller.text);
            if (validation != null) {
              setState(() => error = validation);
              focus.requestFocus();
              return;
            }

            setState(() => isSaving = true);
            await AuthService.instance.setUserFullName(controller.text);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit name',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: false,
              enabled: !isSaving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => save(),
              decoration: InputDecoration(
                labelText: 'Full name',
                errorText: error,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: AppColors.primaryBlack,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    focus.dispose();

    if (updated == true && context.mounted) {
      _showSnack(context, 'Full name updated for future invoices.');
    }
  }

  Future<void> _createNew(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
    );
    ref.invalidate(allInvoicesProvider);
  }

  Future<void> _openView(BuildContext context, Invoice invoice) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => InvoiceFormScreen(existing: invoice, viewOnly: true)),
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
              setState(() => isBusy = false);

              if (pwd == _ownerDeletionPassword) {
                Navigator.pop(ctx, true);
              } else {
                attempts++;
                controller.clear();
                if (attempts >= 2) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Incorrect owner password. Please contact the manager for authorization.',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: AppColors.errorRed,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  Navigator.pop(ctx, false);
                } else {
                  setState(() {
                    error =
                        'Incorrect owner password. Contact the manager for authorization. You have 1 attempt remaining.';
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
                      'Enter the owner authorization password to delete this invoice.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    focusNode: focus,
                    obscureText: obscure,
                    autofocus: true,
                    enabled: !isBusy,
                    onSubmitted: (_) => verify(),
                    decoration: InputDecoration(
                      hintText: 'Enter owner password',
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
