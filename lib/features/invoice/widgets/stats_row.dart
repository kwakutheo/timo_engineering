import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/invoice.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold(0.0, (s, inv) => s + inv.grandTotal);
    final transportTotal = invoices.fold(
        0.0,
        (s, inv) =>
            s +
            inv.transportationAmount +
            inv.labourAmount +
            inv.otherChargesAmount);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final cards = [
      _StatCardData(
        icon: Icons.receipt_long_outlined,
        label: 'Total Invoices',
        value: '${invoices.length}',
        color: AppColors.primaryBlack,
      ),
      _StatCardData(
        icon: Icons.local_shipping_outlined,
        label: 'Transport & Labour',
        value: CurrencyFormatter.format(transportTotal),
        color: AppColors.success,
      ),
      _StatCardData(
        icon: Icons.monetization_on_outlined,
        label: 'Total Revenue',
        value: CurrencyFormatter.format(total),
        color: AppColors.yellowDark,
      ),
    ];

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: cards
                .map((d) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _MobileStatCard(data: d),
                    ))
                .toList(),
          ),
        ),
      );
    }

    // Desktop: existing flex row
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _StatCard(
            icon: cards[0].icon,
            label: cards[0].label,
            value: cards[0].value,
            color: cards[0].color,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: cards[1].icon,
            label: cards[1].label,
            value: cards[1].value,
            color: cards[1].color,
          ),
          const SizedBox(width: 8),
          _StatCard(
            icon: cards[2].icon,
            label: cards[2].label,
            value: cards[2].value,
            color: cards[2].color,
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

// ── Mobile stat card: fixed-width compact pill ────────────────────────────────
class _MobileStatCard extends StatelessWidget {
  const _MobileStatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop stat card (unchanged logic, now private) ──────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
