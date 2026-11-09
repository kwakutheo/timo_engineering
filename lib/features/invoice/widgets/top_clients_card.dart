import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/dashboard_stats.dart';

class TopClientsCard extends StatelessWidget {
  final List<ClientStat> topClients;

  const TopClientsCard({
    super.key,
    required this.topClients,
  });

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
                  Icons.star_rounded,
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
                      'Top Clients',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlack,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Highest billing client accounts',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${topClients.length} ${topClients.length == 1 ? 'Account' : 'Accounts'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlack,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Body
          if (topClients.isEmpty)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: const Text(
                'No client billing history available.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topClients.length.clamp(0, 5),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final client = topClients[index];
                final rank = index + 1;

                Color rankBg;
                Color rankTextCol;
                if (rank == 1) {
                  rankBg = AppColors.primaryYellow;
                  rankTextCol = AppColors.primaryBlack;
                } else if (rank == 2) {
                  rankBg = const Color(0xFFE0E0E0);
                  rankTextCol = AppColors.primaryBlack;
                } else if (rank == 3) {
                  rankBg = const Color(0xFFFFE0B2);
                  rankTextCol = const Color(0xFFE65100);
                } else {
                  rankBg = AppColors.scaffoldBg;
                  rankTextCol = AppColors.textGrey;
                }

                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rankBg,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: rankTextCol,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.primaryBlack,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            client.billTo.isNotEmpty
                                ? client.billTo
                                : '${client.invoiceCount} ${client.invoiceCount == 1 ? 'invoice' : 'invoices'} • Last: ${DateFormat('dd MMM yyyy').format(client.lastServiceDate)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(client.totalSpent),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: AppColors.primaryBlack,
                          ),
                        ),
                        Text(
                          '${client.invoiceCount} ${client.invoiceCount == 1 ? 'job' : 'jobs'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textLightGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
