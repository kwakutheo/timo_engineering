import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_db.dart';
import 'data/datasources/storage_service.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/widgets/app_lock_wrapper.dart';
import 'features/invoice/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialise SQLite FFI for Windows / Linux / macOS desktop.
  LocalDb.initFfiIfNeeded();

  // 2. Initialise the storage layer:
  //    - Creates %LOCALAPPDATA%\Timo Invoice\database\  (and siblings)
  //    - Migrates legacy database if present (copy → verify → rename to .bak)
  await StorageService.instance.init();

  // 3. Tell LocalDb where its file lives.
  LocalDb.setDatabasePath(StorageService.instance.databasePath);
  await AuthService.instance.setPassword('theo');

  runApp(
    const ProviderScope(
      child: TimosInvoiceApp(),
    ),
  );
}

class TimosInvoiceApp extends StatelessWidget {
  const TimosInvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Timo's Engineering – Invoices",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppLockWrapper(
        child: HomeScreen(),
      ),
    );
  }
}
