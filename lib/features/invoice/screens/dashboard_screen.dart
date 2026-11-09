import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/datasources/sync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../auth/services/auth_service.dart';
import '../controllers/client_controller.dart';
import '../controllers/invoice_controller.dart';
import '../controllers/navigation_controller.dart';
import '../models/dashboard_stats.dart';
import '../widgets/monthly_revenue_chart.dart';
import '../widgets/navigation_tab_pills.dart';
import '../widgets/recent_invoices_card.dart';
import '../widgets/service_alerts_card.dart';
import '../widgets/technician_performance_card.dart';
import '../widgets/top_clients_card.dart';
import 'invoice_form_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  StreamSubscription<void>? _syncSubscription;
  String _userFullName = '';

  @override
  void initState() {
    super.initState();
    _loadUserFullName();

    // Auto-refresh when background sync completes
    _syncSubscription = SyncService.instance.onSyncCompleted.listen((_) {
      if (mounted) {
        ref.invalidate(allInvoicesProvider);
        ref.invalidate(allClientsProvider);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SyncService.instance.sync();
    });
  }

  Future<void> _loadUserFullName() async {
    final name = await AuthService.instance.getUserFullName();
    if (mounted && name != null && name.trim().isNotEmpty) {
      setState(() => _userFullName = name.trim());
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
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

  Future<void> _createNewInvoice(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
    );
    ref.invalidate(allInvoicesProvider);
    ref.invalidate(allClientsProvider);
  }

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
        builder: (context, setDialogState) {
          Future<void> save() async {
            final validation =
                AuthService.instance.validateFullName(controller.text);
            if (validation != null) {
              setDialogState(() => error = validation);
              focus.requestFocus();
              return;
            }

            setDialogState(() => isSaving = true);
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
      _loadUserFullName();
      _showSnack(context, 'Full name updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allInvoicesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final isDesktop = width >= 1000;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildSliverAppBar(context, isMobile, isDesktop),
        ],
        body: allAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryYellow),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.errorRed),
                const SizedBox(height: 12),
                Text('Error loading dashboard: $e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(allInvoicesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (allInvoices) {
            final metrics = DashboardMetrics.fromInvoices(allInvoices);

            return RefreshIndicator(
              color: AppColors.primaryBlack,
              onRefresh: () async {
                ref.invalidate(allInvoicesProvider);
                await SyncService.instance.sync();
              },
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 20,
                      16,
                      isMobile ? 12 : 20,
                      100,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Quick Action Bar
                        _buildQuickActionBar(context, metrics, isMobile),
                        const SizedBox(height: 20),

                        // KPI Cards
                        _buildKpiSection(metrics, isMobile, isDesktop),
                        const SizedBox(height: 20),

                        // Row 1: Revenue Chart & Servicing Alerts
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: MonthlyRevenueChart(
                                  trends: metrics.monthlyTrends,
                                  cardHeight: 335,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: ServiceAlertsCard(
                                  alerts: metrics.serviceAlerts,
                                  cardHeight: 335,
                                  onRefreshNeeded: () =>
                                      ref.invalidate(allInvoicesProvider),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          MonthlyRevenueChart(trends: metrics.monthlyTrends),
                          const SizedBox(height: 16),
                          ServiceAlertsCard(
                            alerts: metrics.serviceAlerts,
                            onRefreshNeeded: () =>
                                ref.invalidate(allInvoicesProvider),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Row 2: Technician Performance & Top Clients
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: TechnicianPerformanceCard(
                                    stats: metrics.technicianStats),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 6,
                                child: TopClientsCard(
                                    topClients: metrics.topClients),
                              ),
                            ],
                          )
                        else ...[
                          TechnicianPerformanceCard(
                              stats: metrics.technicianStats),
                          const SizedBox(height: 16),
                          TopClientsCard(topClients: metrics.topClients),
                        ],

                        const SizedBox(height: 20),

                        // Row 3: Recent Invoices Card
                        RecentInvoicesCard(
                          invoices: metrics.recentInvoices,
                          totalCount: metrics.totalInvoices,
                          onViewAll: () {
                            ref.read(navigationIndexProvider.notifier).state =
                                1;
                          },
                          onRefreshNeeded: () =>
                              ref.invalidate(allInvoicesProvider),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Sliver App Bar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(
      BuildContext context, bool isMobile, bool isDesktop) {
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
              _userFullName.isNotEmpty
                  ? 'Dashboard • Welcome, $_userFullName'
                  : 'Executive Dashboard',
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
        _buildSyncButton(context),
        IconButton(
          tooltip: 'Refresh',
          icon:
              const Icon(Icons.refresh_rounded, color: AppColors.primaryBlack),
          onPressed: () {
            ref.invalidate(allInvoicesProvider);
            ref.invalidate(allClientsProvider);
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

  // ── Quick Action Bar ────────────────────────────────────────────────────────

  Widget _buildQuickActionBar(
      BuildContext context, DashboardMetrics metrics, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.today_rounded,
                  size: 18, color: AppColors.textGrey),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primaryBlack,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _createNewInvoice(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: AppColors.primaryBlack,
                  elevation: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(navigationIndexProvider.notifier).state = 1;
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text('Invoices (${metrics.totalInvoices})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlack,
                  side: BorderSide(
                      color: AppColors.borderGrey.withValues(alpha: 0.6)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(navigationIndexProvider.notifier).state = 2;
                },
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: Text('Clients (${metrics.uniqueClientsCount})'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlack,
                  side: BorderSide(
                      color: AppColors.borderGrey.withValues(alpha: 0.6)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Executive KPI Cards ─────────────────────────────────────────────────────

  Widget _buildKpiSection(
      DashboardMetrics metrics, bool isMobile, bool isDesktop) {
    final kpiCards = [
      _buildKpiCard(
        title: 'Total Revenue (All Time)',
        value: CurrencyFormatter.format(metrics.totalRevenue),
        subtitle: '${metrics.totalInvoices} total invoices recorded',
        icon: Icons.account_balance_wallet_rounded,
        iconBg: AppColors.primaryYellow.withValues(alpha: 0.25),
        iconColor: AppColors.primaryBlack,
      ),
      _buildKpiCard(
        title: "This Month's Revenue",
        value: CurrencyFormatter.format(metrics.thisMonthRevenue),
        subtitle: '${metrics.thisMonthInvoices} invoices billed this month',
        icon: Icons.trending_up_rounded,
        iconBg: AppColors.success.withValues(alpha: 0.15),
        iconColor: AppColors.success,
        badgeText: metrics.growthPercentage != null
            ? '${metrics.growthPercentage! >= 0 ? '+' : ''}${metrics.growthPercentage!.toStringAsFixed(1)}% vs last mo'
            : null,
        badgeIsGreen: (metrics.growthPercentage ?? 0) >= 0,
      ),
      _buildKpiCard(
        title: 'Transport & Labour',
        value: CurrencyFormatter.format(metrics.serviceRevenue),
        subtitle:
            'Labour: ${CurrencyFormatter.format(metrics.labourRevenue)} • Transport: ${CurrencyFormatter.format(metrics.transportRevenue)}',
        icon: Icons.handyman_rounded,
        iconBg: AppColors.yellowAmber.withValues(alpha: 0.2),
        iconColor: AppColors.yellowDark,
      ),
      _buildKpiCard(
        title: 'Parts & Materials',
        value: CurrencyFormatter.format(metrics.partsRevenue),
        subtitle: 'Spare parts, consumables & materials',
        icon: Icons.settings_suggest_rounded,
        iconBg: const Color(0xFFE0E7FF),
        iconColor: const Color(0xFF3730A3),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: kpiCards
            .map((card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: card,
                  ),
                ))
            .toList(),
      );
    }

    if (isMobile) {
      return Column(
        children: kpiCards
            .map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card,
                ))
            .toList(),
      );
    }

    // Tablet: 2x2 grid
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: kpiCards[0]),
            const SizedBox(width: 12),
            Expanded(child: kpiCards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: kpiCards[2]),
            const SizedBox(width: 12),
            Expanded(child: kpiCards[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    String? badgeText,
    bool badgeIsGreen = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (badgeText != null)
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeIsGreen
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: badgeIsGreen
                            ? AppColors.success
                            : AppColors.errorRed,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryBlack,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLightGrey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
