import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active top-level navigation tab index:
/// 0: Dashboard
/// 1: Invoices (Invoice Manager)
/// 2: Clients (Client Directory)
final navigationIndexProvider = StateProvider<int>((ref) => 0);

