import 'package:uuid/uuid.dart';

class InvoiceItem {
  final String id;
  String description;
  double quantity;
  double price;
  DateTime? updatedAt;
  bool isDeleted;

  InvoiceItem({
    String? id,
    this.description = '',
    this.quantity = 0,
    this.price = 0,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now();

  double get total => quantity * price;

  InvoiceItem copyWith({
    String? description,
    double? quantity,
    double? price,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return InvoiceItem(
      id: id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap(String invoiceId) => {
        'id': id,
        'invoice_id': invoiceId,
        'description': description,
        'quantity': quantity,
        'price': price,
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] as String,
        description: map['description'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      );
}
