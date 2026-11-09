import 'package:intl/intl.dart';
import '../../../data/models/invoice.dart';

class ServiceAlertItem {
  final Invoice invoice;
  final String clientName;
  final String model;
  final String runningHour;
  final String phone;
  final DateTime dueDate;
  final int daysRemaining;
  final bool isOverdue;
  final bool isDueSoon;

  ServiceAlertItem({
    required this.invoice,
    required this.clientName,
    required this.model,
    required this.runningHour,
    required this.phone,
    required this.dueDate,
    required this.daysRemaining,
    required this.isOverdue,
    required this.isDueSoon,
  });
}

class MonthlyTrendItem {
  final DateTime date;
  final String monthLabel;
  final String yearLabel;
  final double revenue;
  final int invoiceCount;

  MonthlyTrendItem({
    required this.date,
    required this.monthLabel,
    required this.yearLabel,
    required this.revenue,
    required this.invoiceCount,
  });
}

class TechnicianStat {
  final String name;
  final int jobCount;
  final double totalRevenue;
  final double percentage;

  TechnicianStat({
    required this.name,
    required this.jobCount,
    required this.totalRevenue,
    required this.percentage,
  });
}

class ClientStat {
  final String name;
  final String billTo;
  final String phone;
  int invoiceCount;
  double totalSpent;
  DateTime lastServiceDate;

  ClientStat({
    required this.name,
    required this.billTo,
    required this.phone,
    required this.invoiceCount,
    required this.totalSpent,
    required this.lastServiceDate,
  });
}

class DashboardMetrics {
  final double totalRevenue;
  final int totalInvoices;
  final double thisMonthRevenue;
  final int thisMonthInvoices;
  final double lastMonthRevenue;
  final double? growthPercentage;
  final double partsRevenue;
  final double labourRevenue;
  final double transportRevenue;
  final double serviceRevenue;
  final int uniqueClientsCount;
  final List<ServiceAlertItem> serviceAlerts;
  final List<MonthlyTrendItem> monthlyTrends;
  final List<TechnicianStat> technicianStats;
  final List<ClientStat> topClients;
  final List<Invoice> recentInvoices;

  DashboardMetrics({
    required this.totalRevenue,
    required this.totalInvoices,
    required this.thisMonthRevenue,
    required this.thisMonthInvoices,
    required this.lastMonthRevenue,
    required this.growthPercentage,
    required this.partsRevenue,
    required this.labourRevenue,
    required this.transportRevenue,
    required this.serviceRevenue,
    required this.uniqueClientsCount,
    required this.serviceAlerts,
    required this.monthlyTrends,
    required this.technicianStats,
    required this.topClients,
    required this.recentInvoices,
  });

  factory DashboardMetrics.fromInvoices(List<Invoice> invoices) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double totalRev = 0.0;
    double thisMonthRev = 0.0;
    int thisMonthCount = 0;
    double lastMonthRev = 0.0;
    double partsRev = 0.0;
    double labourRev = 0.0;
    double transportRev = 0.0;

    final uniqueClients = <String>{};
    final alerts = <ServiceAlertItem>[];
    final techMap = <String, _MutableTechStat>{};
    final clientMap = <String, ClientStat>{};

    final lastMonthTarget = DateTime(now.year, now.month - 1, 1);

    for (final inv in invoices) {
      final grand = inv.grandTotal;
      totalRev += grand;
      partsRev += inv.itemsSubTotal;
      labourRev += inv.labourAmount;
      transportRev += inv.transportationAmount;

      if (inv.clientName.trim().isNotEmpty) {
        uniqueClients.add(inv.clientName.trim().toLowerCase());
      }

      // Monthly aggregates
      if (inv.date.year == now.year && inv.date.month == now.month) {
        thisMonthRev += grand;
        thisMonthCount++;
      } else if (inv.date.year == lastMonthTarget.year &&
          inv.date.month == lastMonthTarget.month) {
        lastMonthRev += grand;
      }

      // Next service date alerts
      if (inv.nextServiceDate != null) {
        final due = DateTime(
          inv.nextServiceDate!.year,
          inv.nextServiceDate!.month,
          inv.nextServiceDate!.day,
        );
        final diffDays = due.difference(today).inDays;
        alerts.add(ServiceAlertItem(
          invoice: inv,
          clientName: inv.clientName.trim().isEmpty
              ? 'Unnamed Client'
              : inv.clientName.trim(),
          model: inv.model.trim().isEmpty ? 'General Equipment' : inv.model.trim(),
          runningHour: inv.runningHour.trim(),
          phone: inv.phone.trim(),
          dueDate: inv.nextServiceDate!,
          daysRemaining: diffDays,
          isOverdue: diffDays < 0,
          isDueSoon: diffDays >= 0 && diffDays <= 30,
        ));
      }

      // Technician stats
      final techName = inv.technicianName.trim().isEmpty
          ? 'Unassigned'
          : inv.technicianName.trim();
      final currentTech =
          techMap.putIfAbsent(techName, () => _MutableTechStat(name: techName));
      currentTech.jobCount++;
      currentTech.totalRevenue += grand;

      // Client leaderboard
      final clientKey = inv.clientName.trim().isEmpty
          ? 'Unnamed Client'
          : inv.clientName.trim();
      final existingClient = clientMap[clientKey];
      if (existingClient != null) {
        existingClient.invoiceCount++;
        existingClient.totalSpent += grand;
        if (inv.date.isAfter(existingClient.lastServiceDate)) {
          existingClient.lastServiceDate = inv.date;
        }
      } else {
        clientMap[clientKey] = ClientStat(
          name: clientKey,
          billTo: inv.billTo.trim(),
          phone: inv.phone.trim(),
          invoiceCount: 1,
          totalSpent: grand,
          lastServiceDate: inv.date,
        );
      }
    }

    // Sort service alerts (overdue first, then soonest due)
    alerts.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // Growth percentage
    double? growth;
    if (lastMonthRev > 0) {
      growth = ((thisMonthRev - lastMonthRev) / lastMonthRev) * 100.0;
    }

    // Monthly trends for the last 6 months
    final trends = <MonthlyTrendItem>[];
    for (int i = 5; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final monthInvoices = invoices.where((inv) =>
          inv.date.year == targetDate.year && inv.date.month == targetDate.month);
      final monthRev =
          monthInvoices.fold(0.0, (sum, inv) => sum + inv.grandTotal);
      trends.add(MonthlyTrendItem(
        date: targetDate,
        monthLabel: DateFormat('MMM').format(targetDate),
        yearLabel: DateFormat("''yy").format(targetDate),
        revenue: monthRev,
        invoiceCount: monthInvoices.length,
      ));
    }

    // Technician list sorted by jobs descending
    final totalJobs = invoices.length;
    final techList = techMap.values.map((t) {
      final pct = totalJobs > 0 ? (t.jobCount / totalJobs) * 100.0 : 0.0;
      return TechnicianStat(
        name: t.name,
        jobCount: t.jobCount,
        totalRevenue: t.totalRevenue,
        percentage: pct,
      );
    }).toList()
      ..sort((a, b) => b.jobCount.compareTo(a.jobCount));

    // Top clients sorted by total spent
    final topClientsList = clientMap.values.toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    // Recent 5 invoices (sorted by date descending)
    final recent = List<Invoice>.from(invoices)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentFive = recent.take(5).toList();

    return DashboardMetrics(
      totalRevenue: totalRev,
      totalInvoices: invoices.length,
      thisMonthRevenue: thisMonthRev,
      thisMonthInvoices: thisMonthCount,
      lastMonthRevenue: lastMonthRev,
      growthPercentage: growth,
      partsRevenue: partsRev,
      labourRevenue: labourRev,
      transportRevenue: transportRev,
      serviceRevenue: labourRev + transportRev,
      uniqueClientsCount: uniqueClients.length,
      serviceAlerts: alerts,
      monthlyTrends: trends,
      technicianStats: techList,
      topClients: topClientsList,
      recentInvoices: recentFive,
    );
  }
}

class _MutableTechStat {
  final String name;
  int jobCount = 0;
  double totalRevenue = 0.0;

  _MutableTechStat({required this.name});
}

