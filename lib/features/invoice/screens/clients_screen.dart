import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/sync_service.dart';
import '../../../data/models/client.dart';
import '../../../data/models/invoice.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/change_password_screen.dart';
import '../controllers/client_controller.dart';
import '../controllers/invoice_controller.dart';
import '../widgets/navigation_tab_pills.dart';
import 'invoice_form_screen.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 50;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _goToPage(int page, int totalPages) {
    final targetPage = page.clamp(1, totalPages);
    if (targetPage == _currentPage) return;
    setState(() {
      _currentPage = targetPage;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
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

  Widget _buildPaginationBar({
    required bool isMobile,
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    final countNoun = totalItems == 1 ? 'client' : 'clients';
    final String rangeText;
    if (totalItems == 0) {
      rangeText = 'No clients found';
    } else if (totalItems <= _pageSize) {
      rangeText = 'Showing all $totalItems $countNoun';
    } else if (startIndex + 1 == endIndex) {
      rangeText = 'Showing client $endIndex of $totalItems';
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
                const Icon(Icons.people_outline_rounded,
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
              const Icon(Icons.people_outline_rounded,
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
                  '50 / page',
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
            ),
        ],
      ),
    );
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

  Future<void> _openClientDialog({Client? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final billToCtrl = TextEditingController(text: existing?.billTo ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'Add New Client' : 'Edit Client',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Client / Contact Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: billToCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Company / Bill To',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location / Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ref.read(clientRepositoryProvider);
              if (existing == null) {
                await repo.save(Client(
                  name: nameCtrl.text.trim(),
                  billTo: billToCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                ));
              } else {
                await repo.update(existing.copyWith(
                  name: nameCtrl.text.trim(),
                  billTo: billToCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: AppColors.primaryBlack,
            ),
            child: const Text('Save Client'),
          ),
        ],
      ),
    );

    if (saved == true) {
      ref.invalidate(allClientsProvider);
      if (mounted) {
        _showSnack(
          context,
          existing == null ? 'Client added successfully.' : 'Client updated.',
        );
      }
    }
  }

  Future<void> _createInvoiceForClient(Client client) async {
    final newInv = Invoice(
      clientName: client.name,
      billTo: client.billTo,
      phone: client.phone,
      address: client.address,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceFormScreen(duplicateFrom: newInv),
      ),
    );
    ref.invalidate(allInvoicesProvider);
    ref.invalidate(allClientsProvider);
  }

  Widget _buildSliverAppBar(BuildContext context, bool isMobile) {
    final expandedHeight = isMobile ? 110.0 : 160.0;
    final logoHeight = isMobile ? 56.0 : 90.0;
    final logoTop = isMobile ? 14.0 : 28.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
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
              'Client Directory',
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
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded,
              color: Color.fromARGB(255, 255, 255, 255)),
          onPressed: () {
            ref.invalidate(allClientsProvider);
            SyncService.instance.sync();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.security_outlined,
              color: Color.fromARGB(255, 255, 255, 255)),
          tooltip: 'Security',
          onSelected: (value) {
            if (value == 'change_pin') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            } else if (value == 'lock_now') {
              ref.read(authProvider.notifier).lock();
            }
          },
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

  @override
  Widget build(BuildContext context) {
    // Reset to page 1 whenever the search query changes
    ref.listen<String>(clientSearchQueryProvider, (previous, next) {
      if (previous != next && _currentPage != 1) {
        setState(() {
          _currentPage = 1;
        });
      }
    });

    final filteredAsync = ref.watch(filteredClientsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildSliverAppBar(context, isMobile),
        ],
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Search Bar & Add Client Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => ref
                            .read(clientSearchQueryProvider.notifier)
                            .state = v,
                        decoration: InputDecoration(
                          hintText:
                              'Search clients by name, company, phone, address…',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.primaryBlack,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                            clientSearchQueryProvider.notifier)
                                        .state = '';
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          hintStyle: const TextStyle(
                              color: AppColors.textGrey, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openClientDialog(),
                      icon:
                          const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: Text(isMobile ? 'Add' : 'Add Client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryYellow,
                        foregroundColor: AppColors.primaryBlack,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Client Cards & Pagination
            ...filteredAsync.when<List<Widget>>(
              loading: () => [
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryYellow),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  child: Center(
                    child: Text('Error loading clients: $e'),
                  ),
                ),
              ],
              data: (clients) {
                if (clients.isEmpty) {
                  return [
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 56, color: AppColors.textGrey),
                            const SizedBox(height: 12),
                            const Text(
                              'No clients found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlack,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add a client to save contact information and speed up invoicing.',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.textGrey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _openClientDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryYellow,
                                foregroundColor: AppColors.primaryBlack,
                              ),
                              child: const Text('Add First Client'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                }

                // 5 cards in a row on desktop/wide screens, responsive fallback for tablet/mobile
                final crossAxisCount =
                    width >= 950 ? 5 : (width >= 700 ? 3 : (isMobile ? 1 : 2));

                final totalItems = clients.length;
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
                final pageClients = totalItems == 0
                    ? <Client>[]
                    : clients.sublist(startIndex, endIndex);

                return [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 165,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final client = pageClients[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.borderGrey
                                      .withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: AppColors.primaryBlack,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (client.billTo.isNotEmpty)
                                            Text(
                                              client.billTo,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textGrey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon:
                                          const Icon(Icons.more_vert, size: 18),
                                      onSelected: (val) async {
                                        if (val == 'edit') {
                                          _openClientDialog(existing: client);
                                        } else if (val == 'delete') {
                                          await ref
                                              .read(clientRepositoryProvider)
                                              .delete(client.id);
                                          ref.invalidate(allClientsProvider);
                                          if (!context.mounted) return;
                                          _showSnack(
                                              context, 'Client deleted.');
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: ListTile(
                                            leading: Icon(Icons.edit_outlined,
                                                size: 18),
                                            title: Text('Edit'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            leading: Icon(Icons.delete_outline,
                                                size: 18,
                                                color: AppColors.errorRed),
                                            title: Text('Delete',
                                                style: TextStyle(
                                                    color: AppColors.errorRed)),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (client.phone.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: client.phone));
                                      _showSnack(context,
                                          'Phone copied: ${client.phone}');
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 14,
                                            color: AppColors.textGrey),
                                        const SizedBox(width: 6),
                                        Text(
                                          client.phone,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textGrey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (client.address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          size: 14, color: AppColors.textGrey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          client.address,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textGrey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _createInvoiceForClient(client),
                                    icon:
                                        const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Create Invoice'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryBlack,
                                      side: BorderSide(
                                        color: AppColors.primaryYellow
                                            .withValues(alpha: 0.8),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: pageClients.length,
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
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
