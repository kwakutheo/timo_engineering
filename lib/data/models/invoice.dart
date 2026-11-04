import 'package:uuid/uuid.dart';
import 'invoice_item.dart';
import '../../core/utils/invoice_number_gen.dart';

class Invoice {
  final String id;
  String invoiceNumber;
  String clientName;
  String address;
  String phone;
  String billTo;
  DateTime date;
  String runningHour;
  String model;
  DateTime? nextServiceDate;
  List<InvoiceItem> items;
  String jobDescription;
  String managerName;
  double transportationAmount;
  double labourAmount;
  double otherChargesAmount;
  final DateTime createdAt;
  DateTime? updatedAt;
  bool isDeleted;

  Invoice({
    String? id,
    String? invoiceNumber,
    this.clientName = '',
    this.address = '',
    this.phone = '',
    this.billTo = '',
    DateTime? date,
    this.runningHour = '',
    this.model = '',
    this.nextServiceDate,
    List<InvoiceItem>? items,
    this.jobDescription = '',
    this.managerName = '',
    this.transportationAmount = 0.0,
    this.labourAmount = 0.0,
    this.otherChargesAmount = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        invoiceNumber = invoiceNumber ?? InvoiceNumberGen.generate(),
        date = date ?? DateTime.now(),
        items = items ?? [InvoiceItem()],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  double get itemsSubTotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get grandTotal =>
      itemsSubTotal + transportationAmount + labourAmount + otherChargesAmount;

  Invoice copyWith({
    String? clientName,
    String? address,
    String? phone,
    String? billTo,
    DateTime? date,
    String? runningHour,
    String? model,
    DateTime? nextServiceDate,
    bool clearNextServiceDate = false,
    List<InvoiceItem>? items,
    String? jobDescription,
    String? managerName,
    double? transportationAmount,
    double? labourAmount,
    double? otherChargesAmount,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      Invoice(
        id: id,
        invoiceNumber: invoiceNumber,
        clientName: clientName ?? this.clientName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        billTo: billTo ?? this.billTo,
        date: date ?? this.date,
        runningHour: runningHour ?? this.runningHour,
        model: model ?? this.model,
        nextServiceDate: clearNextServiceDate
            ? null
            : (nextServiceDate ?? this.nextServiceDate),
        items: items ?? this.items,
        jobDescription: jobDescription ?? this.jobDescription,
        managerName: managerName ?? this.managerName,
        transportationAmount: transportationAmount ?? this.transportationAmount,
        labourAmount: labourAmount ?? this.labourAmount,
        otherChargesAmount: otherChargesAmount ?? this.otherChargesAmount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'client_name': clientName,
        'address': address,
        'phone': phone,
        'bill_to': billTo,
        'date': date.toIso8601String(),
        'running_hour': runningHour,
        'model': model,
        'next_service_date': nextServiceDate?.toIso8601String(),
        'job_description': jobDescription,
        'manager_name': managerName,
        'transportation_amount': transportationAmount,
        'labour_amount': labourAmount,
        'other_charges_amount': otherChargesAmount,
        'grand_total': grandTotal,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Invoice.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) =>
      Invoice(
        id: map['id'] as String,
        invoiceNumber: map['invoice_number'] as String? ?? '',
        clientName: map['client_name'] as String? ?? '',
        address: map['address'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        billTo: map['bill_to'] as String? ?? '',
        date: DateTime.tryParse(map['date']?.toString() ?? '') ??
            DateTime.now(),
        runningHour: map['running_hour'] as String? ?? '',
        model: map['model'] as String? ?? '',
        nextServiceDate: map['next_service_date'] != null
            ? DateTime.tryParse(map['next_service_date'].toString())
            : null,
        items: items,
        jobDescription: map['job_description'] as String? ?? '',
        managerName: map['manager_name'] as String? ?? '',
        transportationAmount:
            (map['transportation_amount'] as num?)?.toDouble() ?? 0.0,
        labourAmount: (map['labour_amount'] as num?)?.toDouble() ?? 0.0,
        otherChargesAmount:
            (map['other_charges_amount'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      );

  factory Invoice.duplicate(Invoice source) => Invoice(
        clientName: source.clientName,
        address: source.address,
        phone: source.phone,
        billTo: source.billTo,
        runningHour: source.runningHour,
        model: source.model,
        nextServiceDate: source.nextServiceDate,
        items: source.items
            .map((i) => InvoiceItem(
                  description: i.description,
                  quantity: i.quantity,
                  price: i.price,
                ))
            .toList(),
        jobDescription: source.jobDescription,
        managerName: source.managerName,
        transportationAmount: source.transportationAmount,
        labourAmount: source.labourAmount,
        otherChargesAmount: source.otherChargesAmount,
      );
}
