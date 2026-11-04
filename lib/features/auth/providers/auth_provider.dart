import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FORCE-RESET CONTROL
///
/// Bump this token whenever you want ALL devices to discard their current
/// password and revert to [_kDefaultPassword] on the next app launch.
///
/// Examples:
///   'v1'  → current build
///   'v2'  → next forced reset (just change the string, rebuild & deploy)
/// ─────────────────────────────────────────────────────────────────────────────
const _kPasswordResetVersion = 'v2';
const _kDefaultPassword = 'timo@admin';

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
    // ── Check if the stored password-reset version matches the app's current
    //    version token. If not (e.g. developer bumped _kPasswordResetVersion),
    //    wipe ALL auth data and re-set the default password. This resets the
    //    password on every device the moment they open the updated app.
    final storedVersion = await _service.getPasswordResetVersion();
    if (storedVersion != _kPasswordResetVersion) {
      // Version mismatch → force reset to default password.
      await _service.wipeAuth();
      await _service.setPassword(_kDefaultPassword);
      await _service.savePasswordResetVersion(_kPasswordResetVersion);
    } else {
      // Version matches → ensure a password exists (handles truly fresh installs).
      final hasPin = await _service.hasPassword();
      if (!hasPin) {
        await _service.setPassword(_kDefaultPassword);
      }
    }

    state = const AuthState(
      isLocked: true,
      isFirstLaunch: false,
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
    state = const AuthState(isLocked: false, isFirstLaunch: false, isLoading: false);
  }

  /// Called after completely wiping all auth data to return to password creation.
  void resetToSetup() {
    state = const AuthState(isLocked: false, isFirstLaunch: true, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
