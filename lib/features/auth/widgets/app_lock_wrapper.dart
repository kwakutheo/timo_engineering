import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/lock_screen.dart';
import '../screens/set_password_screen.dart';

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
  bool _setupScreenVisible = false;

  void _showAuthScreenIfNeeded() {
    final auth = ref.read(authProvider);
    if (auth.isFirstLaunch && !_setupScreenVisible) {
      _pushPasswordSetupScreen();
    } else if (auth.isLocked && !_lockScreenVisible) {
      _pushLockScreen();
    }
  }

  Future<void> _pushPasswordSetupScreen() async {
    if (_setupScreenVisible) return;
    _setupScreenVisible = true;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const SetPasswordScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) setState(() => _setupScreenVisible = false);
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

    // Show password setup on a fresh/migrated install, otherwise lock normally.
    if (!auth.isLoading && (auth.isFirstLaunch || auth.isLocked)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAuthScreenIfNeeded();
      });
    }

    // Do not reveal invoice information before password setup or unlock.
    if (auth.isLoading || auth.isFirstLaunch || auth.isLocked) {
      return const SizedBox.shrink();
    }

    return widget.child;
  }
}
