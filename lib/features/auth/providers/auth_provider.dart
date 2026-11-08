import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AUTHENTICATION MIGRATION CONTROL
///
/// Bump this token only when the authentication data format changes. A version
/// mismatch never creates a known default password; it routes the user through
/// the password-setup flow instead.
/// ─────────────────────────────────────────────────────────────────────────────
const _kPasswordResetVersion = 'v3';

/// The observable lock state of the app.
class AuthState {
  final bool isLocked;
  final bool isFirstLaunch; // no password set yet
  final bool isLoading;

  const AuthState({
    this.isLocked = true,
    this.isFirstLaunch = false,
    this.isLoading = true,
  });

  AuthState copyWith({bool? isLocked, bool? isFirstLaunch, bool? isLoading}) {
    return AuthState(
      isLocked: isLocked ?? this.isLocked,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  final _service = AuthService.instance;

  Future<void> _init() async {
    // A version mismatch removes only authentication secrets and routes the
    // user to secure setup. Invoice data is kept in the separate SQLite store.
    final storedVersion = await _service.getPasswordResetVersion();
    if (storedVersion != _kPasswordResetVersion) {
      await _service.wipeAuth();
      await _service.savePasswordResetVersion(_kPasswordResetVersion);
      state = const AuthState(
        isLocked: false,
        isFirstLaunch: true,
        isLoading: false,
      );
      return;
    }

    final hasPassword = await _service.hasPassword();
    final hasFullName = (await _service.getUserFullName()) != null;
    state = AuthState(
      isLocked: hasPassword && hasFullName,
      isFirstLaunch: !hasPassword || !hasFullName,
      isLoading: false,
    );
  }

  /// Verify the entered PIN. Returns [VerifyResult].
  Future<VerifyResult> unlock(String pin) async {
    final result = await _service.verifyPassword(pin);
    if (result.success) {
      state = state.copyWith(isLocked: false);
    }
    return result;
  }

  /// Lock the app immediately.
  void lock() {
    state = state.copyWith(isLocked: true);
  }

  /// Called after setting a password for the first time.
  void onPasswordSet() {
    state = const AuthState(
        isLocked: false, isFirstLaunch: false, isLoading: false);
  }

  /// Called after completely wiping all auth data to return to password creation.
  void resetToSetup() {
    state =
        const AuthState(isLocked: false, isFirstLaunch: true, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
