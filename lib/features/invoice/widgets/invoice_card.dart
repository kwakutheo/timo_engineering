import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/invoice.dart';

enum _InvoiceAction { view, copy, print, save, share }

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onView,
    required this.onCopy,
    required this.onPrint,
    required this.onSave,
    required this.onShare,
    required this.onDelete,
    required this.onConfirmDismiss,
  });

  final Invoice invoice;
  final VoidCallback onView;
  final VoidCallback onCopy;
  final VoidCallback onPrint;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final Future<bool?> Function() onConfirmDismiss;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    return Dismissible(
      key: Key(invoice.id),
      direction: DismissDirection.endToStart,
      background: _dismissBackground(),
      confirmDismiss: (_) => onConfirmDismiss(),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.primaryYellow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_outlined,
                      color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dateFmt.format(invoice.date),
                      style: const TextStyle(color: Colors.black, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_InvoiceAction>(
                    tooltip: 'Invoice actions',
                    icon: const Icon(Icons.more_vert,
                        color: AppColors.primaryBlack),
                    onSelected: _handleAction,
                    itemBuilder: (_) => [
                      _actionMenuItem(_InvoiceAction.view,
                          Icons.visibility_outlined, 'View/Edit'),
                      _actionMenuItem(
                          _InvoiceAction.copy, Icons.copy_outlined, 'Copy'),
                      _actionMenuItem(
                          _InvoiceAction.print, Icons.print_outlined, 'Print'),
                      _actionMenuItem(_InvoiceAction.save,
                          Icons.download_outlined, 'Save PDF'),
                      _actionMenuItem(
                          _InvoiceAction.share, Icons.share_outlined, 'Share'),
                    ],
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          invoice.clientName.isEmpty
                              ? 'No client name'
                              : invoice.clientName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: invoice.clientName.isEmpty
                                ? AppColors.textGrey
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(invoice.grandTotal),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlack,
                        ),
                      ),
                    ],
                  ),
                  if (invoice.billTo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.warehouse_outlined,
                            size: 14, color: AppColors.textGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            invoice.billTo,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textGrey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.errorRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 26),
          SizedBox(height: 4),
          Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  PopupMenuItem<_InvoiceAction> _actionMenuItem(
    _InvoiceAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primaryBlack),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  void _handleAction(_InvoiceAction action) {
    switch (action) {
      case _InvoiceAction.view:
        onView();
        break;
      case _InvoiceAction.copy:
        onCopy();
        break;
      case _InvoiceAction.print:
        onPrint();
        break;
      case _InvoiceAction.save:
        onSave();
        break;
      case _InvoiceAction.share:
        onShare();
        break;
    }
  }
}
