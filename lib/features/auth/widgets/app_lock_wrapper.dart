import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/lock_screen.dart';
import '../screens/set_password_screen.dart';

/// Wraps the entire app content to provide:
/// 1. Show lock/setup screen on startup.
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
    if ((auth.isLocked || auth.isFirstLaunch) && !_lockScreenVisible) {
      _pushLockScreen(auth.isFirstLaunch);
    }
  }

  Future<void> _pushLockScreen(bool isSetup) async {
    if (_lockScreenVisible) return;
    _lockScreenVisible = true;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) =>
            isSetup ? const SetPasswordScreen() : const LockScreen(),
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

    // Show lock/setup on initial load.
    if (!auth.isLoading && (auth.isLocked || auth.isFirstLaunch)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLockIfNeeded();
      });
    }

    return widget.child;
  }
}
