import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys used in flutter_secure_storage.
class _Keys {
  static const hash = 'pin_hash';
  static const salt = 'pin_salt';
  static const attempts = 'pin_attempts';
  static const lockUntil = 'pin_lock_until';
  static const hintHash = 'pin_hint_hash';
  static const hintSalt = 'pin_hint_salt';

  /// The hint question text (stored in plaintext — it's a question, not a secret).
  static const hintQuestion = 'pin_hint_question';

  /// Tracks which password-reset version is active on this device.
  static const passwordResetVersion = 'pin_reset_version';

  /// The device user's name, used to prefill "Prepared By" on new invoices.
  static const userFullName = 'user_full_name';
}

/// Banned weak passwords.
const _bannedPasswords = {
  '1234',
  '4321',
  '0000',
  '1111',
  '2222',
  '3333',
  '4444',
  '5555',
  '6666',
  '7777',
  '8888',
  '9999',
  '1122',
  '1212',
  '1231',
  '2345',
  '3456',
  '4567',
  'password',
  'pass123',
  'admin123',
  'abc123',
  'abcdef',
  'qwerty',
  'letmein',
  'welcome',
  'admin',
  'master',
  'monkey',
  'dragon',
  'shadow',
  'sunshine',
  'princess',
  'football',
  'iloveyou',
};

/// Brute-force lockout thresholds: {attempts → lockout seconds}
const _lockoutPolicy = {
  5: 30,
  7: 120,
  10: 600,
  15: 3600,
};

/// Provides all cryptographic operations for the app PIN lock.
///
/// Password storage: PBKDF2-HMAC-SHA256, 10 000 iterations, 32-byte random salt.
/// Legacy passwords (200 000 iterations) are migrated on first successful login.
/// Brute-force: exponential lockout stored in secure storage.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage(
    wOptions: WindowsOptions(),
  );

  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 10000,
    bits: 256, // 32 bytes output
  );

  /// Legacy hasher for migrating passwords created with 200k iterations.
  final _pbkdf2Legacy = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 200000,
    bits: 256,
  );

  // ─── Public API ──────────────────────────────────────────────────────────

  /// True if a PIN has been set.
  Future<bool> hasPassword() async {
    final h = await _storage.read(key: _Keys.hash);
    return h != null && h.isNotEmpty;
  }

  /// Returns the stored password-reset version token, or null if none stored.
  Future<String?> getPasswordResetVersion() async {
    return _storage.read(key: _Keys.passwordResetVersion);
  }

  /// Saves the current password-reset version token to secure storage.
  Future<void> savePasswordResetVersion(String version) async {
    await _storage.write(key: _Keys.passwordResetVersion, value: version);
  }

  /// Validate password strength; returns an error message or null if OK.
  /// Accepts: letters, digits, and common symbols (@, _, -, .).
  String? validatePassword(String password) {
    if (password.length < 4) return 'Password must be at least 4 characters.';
    if (!RegExp(r'^[a-zA-Z0-9@_\-\.]+$').hasMatch(password)) {
      return 'Password may only contain letters, numbers, and @ _ - . symbols.';
    }
    if (_bannedPasswords.contains(password.toLowerCase())) {
      return 'Password is too common. Please choose a stronger one.';
    }
    // Reject all-same characters (e.g. aaaaaa, 111111)
    if (password.split('').every((c) => c == password[0])) {
      return 'Password cannot be all the same character.';
    }
    return null;
  }

  /// Validates the per-device user's full name.
  String? validateFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (fullName.trim().isEmpty || parts.length < 2) {
      return 'Please enter your full name.';
    }
    return null;
  }

  /// Hash and store a new password. Resets attempt counter.
  /// [hint] is the answer to [hintQuestion]. The question is stored in
  /// plaintext so it can be shown to the user; only the answer is hashed.
  Future<void> setPassword(String password,
      {String? hint, String? hintQuestion, String? fullName}) async {
    final saltBytes = _randomBytes(32);
    final saltB64 = base64.encode(saltBytes);

    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: saltBytes,
    );
    final hashB64 = base64.encode(await secretKey.extractBytes());

    await _storage.write(key: _Keys.hash, value: hashB64);
    await _storage.write(key: _Keys.salt, value: saltB64);

    if (fullName != null && fullName.trim().isNotEmpty) {
      await _storage.write(key: _Keys.userFullName, value: fullName.trim());
    }

    // Store hint question (plaintext) and hash the answer.
    if (hint != null && hint.isNotEmpty) {
      await _hashAndStoreHint(hint);
      if (hintQuestion != null && hintQuestion.isNotEmpty) {
        await _storage.write(
            key: _Keys.hintQuestion, value: hintQuestion.trim());
      } else {
        try {
          await _storage.delete(key: _Keys.hintQuestion);
        } catch (_) {}
      }
    } else {
      try {
        await _storage.delete(key: _Keys.hintHash);
      } catch (_) {}
      try {
        await _storage.delete(key: _Keys.hintSalt);
      } catch (_) {}
      try {
        await _storage.delete(key: _Keys.hintQuestion);
      } catch (_) {}
    }

    await _storage.write(key: _Keys.attempts, value: '0');
    try {
      await _storage.delete(key: _Keys.lockUntil);
    } catch (_) {}
  }

  /// Returns the stored hint question text, or null if none was set.
  Future<String?> getHintQuestion() async {
    final q = await _storage.read(key: _Keys.hintQuestion);
    return (q != null && q.isNotEmpty) ? q : null;
  }

  /// Returns the device user's name for pre-filling new invoices.
  Future<String?> getUserFullName() async {
    final name = await _storage.read(key: _Keys.userFullName);
    return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
  }

  /// Updates the per-device user name shown as the preparer on new invoices.
  Future<void> setUserFullName(String fullName) async {
    final error = validateFullName(fullName);
    if (error != null) throw ArgumentError(error);
    await _storage.write(key: _Keys.userFullName, value: fullName.trim());
  }

  /// Hash and securely store a password hint answer.
  Future<void> _hashAndStoreHint(String hint) async {
    final hintSaltBytes = _randomBytes(32);
    final hintSaltB64 = base64.encode(hintSaltBytes);

    final hintSecretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(hint.trim().toLowerCase())),
      nonce: hintSaltBytes,
    );
    final hintHashB64 = base64.encode(await hintSecretKey.extractBytes());

    await _storage.write(key: _Keys.hintHash, value: hintHashB64);
    await _storage.write(key: _Keys.hintSalt, value: hintSaltB64);
  }

  /// Verify a PIN attempt. Returns [VerifyResult] with outcome details.
  Future<VerifyResult> verifyPassword(String pin) async {
    // Check lockout first.
    final lockout = await _getLockoutRemaining();
    if (lockout > 0) {
      return VerifyResult(
        success: false,
        locked: true,
        lockoutSeconds: lockout,
      );
    }

    final storedHash = await _storage.read(key: _Keys.hash);
    final storedSalt = await _storage.read(key: _Keys.salt);
    if (storedHash == null || storedSalt == null) {
      return const VerifyResult(
          success: false, locked: false, lockoutSeconds: 0);
    }

    final saltBytes = base64.decode(storedSalt);
    final pinBytes = utf8.encode(pin);

    // Fast path: try current 10k-iteration hash.
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(pinBytes),
      nonce: saltBytes,
    );
    final computedHash = base64.encode(await secretKey.extractBytes());

    bool matched = computedHash == storedHash;

    // Legacy path: if fast hash didn't match, try the old 200k-iteration hash.
    if (!matched) {
      final legacyKey = await _pbkdf2Legacy.deriveKey(
        secretKey: SecretKey(pinBytes),
        nonce: saltBytes,
      );
      final legacyHash = base64.encode(await legacyKey.extractBytes());
      if (legacyHash == storedHash) {
        matched = true;
        // Migrate: re-hash with the fast 10k iterations so future logins
        // are instant. Salt stays the same, only the stored hash changes.
        final newKey = await _pbkdf2.deriveKey(
          secretKey: SecretKey(pinBytes),
          nonce: saltBytes,
        );
        final newHash = base64.encode(await newKey.extractBytes());
        await _storage.write(key: _Keys.hash, value: newHash);
      }
    }

    if (matched) {
      // Success → reset attempts.
      await Future.wait([
        _storage.write(key: _Keys.attempts, value: '0'),
        _storage.delete(key: _Keys.lockUntil),
      ]);
      return const VerifyResult(
          success: true, locked: false, lockoutSeconds: 0);
    }

    // Failed → increment attempts, apply lockout if needed.
    final attempts = await _incrementAttempts();
    final newLockout = await _getLockoutRemaining();
    return VerifyResult(
      success: false,
      locked: newLockout > 0,
      lockoutSeconds: newLockout,
      failedAttempts: attempts,
    );
  }

  /// Seconds remaining in current lockout (0 = not locked).
  Future<int> getLockoutRemaining() => _getLockoutRemaining();

  /// Current failed attempt count.
  Future<int> getAttemptCount() async {
    final a = await _storage.read(key: _Keys.attempts);
    return int.tryParse(a ?? '0') ?? 0;
  }

  /// Verify the password hint answer securely using hashed comparison.
  /// Supports legacy hints hashed with 200k iterations.
  Future<bool> verifyPasswordHint(String input) async {
    final storedHintHash = await _storage.read(key: _Keys.hintHash);
    final storedHintSalt = await _storage.read(key: _Keys.hintSalt);

    if (storedHintHash == null || storedHintSalt == null) return false;

    final hintSaltBytes = base64.decode(storedHintSalt);
    final hintBytes = utf8.encode(input.trim().toLowerCase());

    // Try current 10k iterations first.
    final inputSecretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(hintBytes),
      nonce: hintSaltBytes,
    );
    final computedHintHash = base64.encode(await inputSecretKey.extractBytes());

    if (computedHintHash == storedHintHash) return true;

    // Fallback: try legacy 200k iterations.
    final legacyKey = await _pbkdf2Legacy.deriveKey(
      secretKey: SecretKey(hintBytes),
      nonce: hintSaltBytes,
    );
    final legacyHintHash = base64.encode(await legacyKey.extractBytes());

    return legacyHintHash == storedHintHash;
  }

  /// Wipe all auth data (for password reset).
  Future<void> wipeAuth() async {
    for (final key in [
      _Keys.hash,
      _Keys.salt,
      _Keys.attempts,
      _Keys.lockUntil,
      _Keys.hintHash,
      _Keys.hintSalt,
      _Keys.hintQuestion,
      _Keys.userFullName,
      // Note: passwordResetVersion is NOT wiped here — it is managed separately
      // by savePasswordResetVersion() in auth_provider.dart.
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
    }
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  Future<int> _getLockoutRemaining() async {
    final raw = await _storage.read(key: _Keys.lockUntil);
    if (raw == null) return 0;
    final lockUntil = DateTime.tryParse(raw);
    if (lockUntil == null) return 0;
    final remaining = lockUntil.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<int> _incrementAttempts() async {
    final raw = await _storage.read(key: _Keys.attempts);
    final count = (int.tryParse(raw ?? '0') ?? 0) + 1;
    await _storage.write(key: _Keys.attempts, value: count.toString());

    // Apply lockout policy.
    int lockSeconds = 0;
    for (final entry in _lockoutPolicy.entries) {
      if (count >= entry.key) lockSeconds = entry.value;
    }
    if (lockSeconds > 0) {
      final until = DateTime.now().add(Duration(seconds: lockSeconds));
      await _storage.write(
          key: _Keys.lockUntil, value: until.toIso8601String());
    }
    return count;
  }

  List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List.generate(length, (_) => rng.nextInt(256));
  }
}

/// Result returned by [AuthService.verifyPassword].
class VerifyResult {
  final bool success;
  final bool locked;
  final int lockoutSeconds;
  final int failedAttempts;

  const VerifyResult({
    required this.success,
    required this.locked,
    required this.lockoutSeconds,
    this.failedAttempts = 0,
  });
}
