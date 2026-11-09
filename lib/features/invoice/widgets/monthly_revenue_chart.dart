import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/dashboard_stats.dart';

class MonthlyRevenueChart extends StatelessWidget {
  final List<MonthlyTrendItem> trends;
  final double? cardHeight;

  const MonthlyRevenueChart({
    super.key,
    required this.trends,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final maxRevenue = trends.isEmpty
        ? 0.0
        : trends.map((t) => t.revenue).reduce(math.max);
    final effectiveMax = maxRevenue > 0 ? maxRevenue * 1.15 : 1000.0;
    final totalPeriodRevenue =
        trends.fold(0.0, (sum, t) => sum + t.revenue);

    final headerContent = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryYellow.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.bar_chart_rounded,
            color: AppColors.primaryBlack,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Revenue Trend',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlack,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Last 6 months billing performance',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textGrey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    final totalBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.borderGrey.withValues(alpha: 0.4)),
      ),
      child: Text(
        '6M Total: ${CurrencyFormatter.format(totalPeriodRevenue)}',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBlack,
        ),
      ),
    );

    final chartBars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: trends.map((item) {
        final ratio = (item.revenue / effectiveMax).clamp(0.0, 1.0);
        final isTopMonth = maxRevenue > 0 && item.revenue == maxRevenue;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Tooltip / Amount text
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.revenue > 0
                        ? CurrencyFormatter.format(item.revenue)
                        : '—',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isTopMonth ? FontWeight.w800 : FontWeight.w600,
                      color: isTopMonth
                          ? AppColors.primaryBlack
                          : AppColors.textGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Bar
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: ratio.clamp(0.04, 1.0),
                      widthFactor: 0.75,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: isTopMonth
                              ? const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppColors.yellowDark,
                                    AppColors.primaryYellow,
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    item.revenue > 0
                                        ? AppColors.primaryYellow
                                            .withValues(alpha: 0.5)
                                        : Colors.grey.shade200,
                                    item.revenue > 0
                                        ? AppColors.primaryYellow
                                            .withValues(alpha: 0.85)
                                        : Colors.grey.shade300,
                                  ],
                                ),
                          boxShadow: isTopMonth
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryYellow
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Month Label & Count
                Text(
                  item.monthLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isTopMonth ? FontWeight.w800 : FontWeight.w600,
                    color: isTopMonth
                        ? AppColors.primaryBlack
                        : AppColors.textDark,
                  ),
                ),
                Text(
                  '${item.invoiceCount} ${item.invoiceCount == 1 ? 'inv' : 'invs'}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textLightGrey,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    return Container(
      height: cardHeight,
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
          if (cardHeight != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: headerContent),
                const SizedBox(width: 12),
                totalBadge,
              ],
            )
          else ...[
            headerContent,
            const SizedBox(height: 10),
            totalBadge,
          ],

          const SizedBox(height: 16),

          if (cardHeight != null)
            Expanded(child: chartBars)
          else
            SizedBox(height: 200, child: chartBars),
        ],
      ),
    );
  }
}
