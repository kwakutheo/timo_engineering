import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/invoice.dart';
import '../screens/invoice_form_screen.dart';
import '../services/pdf_service.dart';
import 'pdf_document_choice_dialog.dart';

class RecentInvoicesCard extends StatelessWidget {
  final List<Invoice> invoices;
  final int totalCount;
  final VoidCallback onViewAll;
  final VoidCallback onRefreshNeeded;

  const RecentInvoicesCard({
    super.key,
    required this.invoices,
    required this.totalCount,
    required this.onViewAll,
    required this.onRefreshNeeded,
  });

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (responsive flexed for small screens)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primaryBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Invoices',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlack,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Latest billing & reports',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.borderGrey.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All ($totalCount)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlack,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppColors.primaryBlack),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Invoices List
          if (invoices.isEmpty)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: const Text(
                'No invoices recorded yet.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                return InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InvoiceFormScreen(
                          existing: inv,
                          viewOnly: true,
                        ),
                      ),
                    );
                    onRefreshNeeded();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.borderGrey.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Invoice Icon Badge
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.borderGrey
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Icon(
                            Icons.receipt_rounded,
                            size: 18,
                            color: AppColors.primaryBlack,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Middle Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      inv.invoiceNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: AppColors.primaryBlack,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(inv.date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLightGrey,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert,
                                          size: 18,
                                          color: AppColors.primaryBlack),
                                      tooltip: 'Actions',
                                      onSelected: (action) {
                                        if (action == 'view') {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => InvoiceFormScreen(
                                                existing: inv,
                                                viewOnly: true,
                                              ),
                                            ),
                                          ).then((_) => onRefreshNeeded());
                                        } else if (action == 'print') {
                                          _print(context, inv);
                                        } else if (action == 'save') {
                                          _savePdf(context, inv);
                                        } else if (action == 'share') {
                                          _share(context, inv);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'view',
                                          child: ListTile(
                                            leading: Icon(
                                                Icons.visibility_outlined,
                                                size: 18),
                                            title: Text('View Invoice'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'print',
                                          child: ListTile(
                                            leading: Icon(Icons.print_outlined,
                                                size: 18),
                                            title: Text('Print PDF'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'save',
                                          child: ListTile(
                                            leading: Icon(Icons.save_alt_rounded,
                                                size: 18),
                                            title: Text('Save PDF'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'share',
                                          child: ListTile(
                                            leading: Icon(Icons.share_outlined,
                                                size: 18),
                                            title: Text('Share PDF'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inv.clientName.isNotEmpty
                                    ? inv.clientName
                                    : 'Unnamed Client',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlack,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (inv.technicianName.isNotEmpty)
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryYellow
                                                    .withValues(alpha: 0.25),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Tech: ${inv.technicianName}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primaryBlack,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  const SizedBox(width: 8),
                                  Text(
                                    CurrencyFormatter.format(inv.grandTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.primaryBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
