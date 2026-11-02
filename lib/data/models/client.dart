import 'package:uuid/uuid.dart';

class Client {
  final String id;
  final String name;
  final String address;
  final String phone;
  final DateTime createdAt;

  Client({
    String? id,
    required this.name,
    this.address = '',
    this.phone = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Client copyWith({
    String? name,
    String? address,
    String? phone,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'created_at': createdAt.toIso8601String(),
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        name: map['name'] as String,
        address: map['address'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
