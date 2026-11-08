import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/invoice.dart';

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onEdit,
    required this.onCopy,
    required this.onPrint,
    required this.onSave,
    required this.onShare,
    required this.onDelete,
    required this.onConfirmDismiss,
  });

  final Invoice invoice;
  final VoidCallback onEdit;
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: AppColors.yellowGradient,
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
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dateFmt.format(invoice.date),
                      style: const TextStyle(color: Colors.black, fontSize: 11),
                    ),
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
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          color: AppColors.primaryBlack,
                          onTap: onEdit,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.copy_outlined,
                          label: 'Copy',
                          color: AppColors.primaryBlack,
                          onTap: onCopy,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.print_outlined,
                          label: 'Print',
                          color: AppColors.primaryBlack,
                          onTap: onPrint,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.download_outlined,
                          label: 'Save',
                          color: AppColors.primaryBlack,
                          onTap: onSave,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          color: AppColors.primaryBlack,
                          onTap: onShare,
                        ),
                      ],
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
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
