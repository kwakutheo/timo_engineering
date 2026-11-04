import 'package:uuid/uuid.dart';

class Client {
  final String id;
  final String name;
  final String billTo;
  final String address;
  final String phone;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  Client({
    String? id,
    required this.name,
    this.billTo = '',
    this.address = '',
    this.phone = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  Client copyWith({
    String? name,
    String? billTo,
    String? address,
    String? phone,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        billTo: billTo ?? this.billTo,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'bill_to': billTo,
        'address': address,
        'phone': phone,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        billTo: map['bill_to'] as String? ?? '',
        address: map['address'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      );
}
