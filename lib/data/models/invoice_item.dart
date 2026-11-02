import 'package:uuid/uuid.dart';

class InvoiceItem {
  final String id;
  String description;
  double quantity;
  double price;

  InvoiceItem({
    String? id,
    this.description = '',
    this.quantity = 0,
    this.price = 0,
  }) : id = id ?? const Uuid().v4();

  double get total => quantity * price;

  InvoiceItem copyWith({
    String? description,
    double? quantity,
    double? price,
  }) {
    return InvoiceItem(
      id: id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toMap(String invoiceId) => {
        'id': id,
        'invoice_id': invoiceId,
        'description': description,
        'quantity': quantity,
        'price': price,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] as String,
        description: map['description'] as String? ?? '',
        quantity: (map['quantity'] as num).toDouble(),
        price: (map['price'] as num).toDouble(),
      );
}
