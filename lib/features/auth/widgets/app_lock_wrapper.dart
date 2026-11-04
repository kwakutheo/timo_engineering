import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/lock_screen.dart';

/// Wraps the entire app content to provide:
/// 1. Show lock screen on startup.
/// 2. Re-lock when the app is re-opened after being locked.
class AppLockWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper> {
  bool _lockScreenVisible = false;

  void _showLockIfNeeded() {
    final auth = ref.read(authProvider);
    if (auth.isLocked && !_lockScreenVisible) {
      _pushLockScreen();
    }
  }

  Future<void> _pushLockScreen() async {
    if (_lockScreenVisible) return;
    _lockScreenVisible = true;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const LockScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    _lockScreenVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Show lock screen on initial load or when re-locked.
    if (!auth.isLoading && auth.isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLockIfNeeded();
      });
    }

    return widget.child;
  }
}
