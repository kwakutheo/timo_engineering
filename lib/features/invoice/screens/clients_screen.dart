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

  @override
  void dispose() {
    _searchController.dispose();
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
    final filteredAsync = ref.watch(filteredClientsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final isDesktop = width >= 1000;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildSliverAppBar(context, isMobile),
        ],
        body: CustomScrollView(
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
                          hintText: 'Search clients by name, company, phone…',
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

            // Client Cards
            filteredAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryYellow),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Text('Error loading clients: $e'),
                ),
              ),
              data: (clients) {
                if (clients.isEmpty) {
                  return SliverFillRemaining(
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
                  );
                }

                final crossAxisCount = isDesktop ? 3 : (isMobile ? 1 : 2);

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 180,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final client = clients[index];
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
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primaryYellow
                                        .withValues(alpha: 0.3),
                                    child: Text(
                                      client.name.isNotEmpty
                                          ? client.name[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryBlack,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    onSelected: (val) async {
                                      if (val == 'edit') {
                                        _openClientDialog(existing: client);
                                      } else if (val == 'delete') {
                                        await ref
                                            .read(clientRepositoryProvider)
                                            .delete(client.id);
                                        ref.invalidate(allClientsProvider);
                                        if (!context.mounted) return;
                                        _showSnack(context, 'Client deleted.');
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
                              const Spacer(),
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
                                          size: 14, color: AppColors.textGrey),
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
                                  icon: const Icon(Icons.add_rounded, size: 16),
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
                      childCount: clients.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
