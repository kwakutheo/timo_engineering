import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/dashboard_stats.dart';
import '../screens/invoice_form_screen.dart';

class ServiceAlertsCard extends StatefulWidget {
  final List<ServiceAlertItem> alerts;
  final VoidCallback onRefreshNeeded;
  final double? cardHeight;

  const ServiceAlertsCard({
    super.key,
    required this.alerts,
    required this.onRefreshNeeded,
    this.cardHeight,
  });

  @override
  State<ServiceAlertsCard> createState() => _ServiceAlertsCardState();
}

class _ServiceAlertsCardState extends State<ServiceAlertsCard> {
  // 0: All, 1: Overdue, 2: Due Soon (<= 30 days)
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final overdueCount = widget.alerts.where((a) => a.isOverdue).length;
    final dueSoonCount =
        widget.alerts.where((a) => a.isDueSoon && !a.isOverdue).length;

    List<ServiceAlertItem> filteredAlerts;
    if (_filterIndex == 1) {
      filteredAlerts = widget.alerts.where((a) => a.isOverdue).toList();
    } else if (_filterIndex == 2) {
      filteredAlerts =
          widget.alerts.where((a) => a.isDueSoon && !a.isOverdue).toList();
    } else {
      filteredAlerts = widget.alerts;
    }

    return Container(
      height: widget.cardHeight,
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
                  color: overdueCount > 0
                      ? AppColors.errorRed.withValues(alpha: 0.15)
                      : AppColors.primaryYellow.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  overdueCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.build_circle_outlined,
                  color: overdueCount > 0
                      ? AppColors.errorRed
                      : AppColors.primaryBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Servicing & Maintenance',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlack,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Upcoming machinery schedule',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (overdueCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.errorRed.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$overdueCount Overdue',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.errorRed,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Filter chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFilterChip(0, 'All (${widget.alerts.length})'),
              _buildFilterChip(1, 'Overdue ($overdueCount)',
                  highlightRed: overdueCount > 0),
              _buildFilterChip(2, 'Due Soon ($dueSoonCount)'),
            ],
          ),

          const SizedBox(height: 14),

          // List body
          if (filteredAlerts.isEmpty)
            widget.cardHeight != null
                ? Expanded(child: _buildEmptyState())
                : _buildEmptyState()
          else if (widget.cardHeight != null)
            Expanded(child: _buildAlertsList(filteredAlerts))
          else
            SizedBox(
              height: 200,
              child: _buildAlertsList(filteredAlerts),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success.withValues(alpha: 0.8),
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text(
            'No servicing alerts in this category',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'All scheduled client machinery is on track.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(List<ServiceAlertItem> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final alert = items[index];
        final isOverdue = alert.isOverdue;
        final days = alert.daysRemaining;

        String badgeText;
        Color badgeBg;
        Color badgeTextCol;

        if (isOverdue) {
          final absDays = days.abs();
          badgeText = absDays == 0
              ? 'Overdue today'
              : '$absDays ${absDays == 1 ? 'day' : 'days'} overdue';
          badgeBg = AppColors.errorRed.withValues(alpha: 0.12);
          badgeTextCol = AppColors.errorRed;
        } else if (days == 0) {
          badgeText = 'Due today!';
          badgeBg = AppColors.yellowAmber.withValues(alpha: 0.2);
          badgeTextCol = AppColors.yellowDark;
        } else if (days <= 7) {
          badgeText = 'In $days ${days == 1 ? 'day' : 'days'}';
          badgeBg = AppColors.primaryYellow.withValues(alpha: 0.25);
          badgeTextCol = AppColors.primaryBlack;
        } else {
          badgeText = 'In $days days';
          badgeBg = AppColors.scaffoldBg;
          badgeTextCol = AppColors.textGrey;
        }

        return InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InvoiceFormScreen(
                  existing: alert.invoice,
                  viewOnly: true,
                ),
              ),
            );
            widget.onRefreshNeeded();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isOverdue ? const Color(0xFFFFF5F5) : AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOverdue
                    ? AppColors.errorRed.withValues(alpha: 0.3)
                    : AppColors.borderGrey.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.clientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primaryBlack,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                                color: badgeTextCol,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.settings_outlined,
                              size: 13, color: AppColors.textGrey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              alert.model.isNotEmpty
                                  ? alert.model
                                  : 'General Equipment',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textGrey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (alert.runningHour.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.timer_outlined,
                                size: 13, color: AppColors.textGrey),
                            const SizedBox(width: 3),
                            Text(
                              '${alert.runningHour} hrs',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textGrey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(int index, String label, {bool highlightRed = false}) {
    final isSelected = _filterIndex == index;
    return InkWell(
      onTap: () => setState(() => _filterIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (highlightRed
                  ? AppColors.errorRed
                  : AppColors.primaryYellow)
              : AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppColors.borderGrey.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (highlightRed ? Colors.white : AppColors.primaryBlack)
                : AppColors.textGrey,
          ),
        ),
      ),
    );
  }
}
