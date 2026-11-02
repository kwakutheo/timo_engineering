import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart' show AuthService;

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _isVerifying = false;
  bool _obscure = true;
  String? _errorMessage;
  int _lockoutSeconds = 0;
  int _failedAttempts = 0;
  Timer? _countdownTimer;

  late final AnimationController _shakeController;
  late final Animation<Offset> _shakeAnimation;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)),
          weight: 1),
      TweenSequenceItem(
          tween:
              Tween(begin: const Offset(-0.04, 0), end: const Offset(0.04, 0)),
          weight: 2),
      TweenSequenceItem(
          tween:
              Tween(begin: const Offset(0.04, 0), end: const Offset(-0.04, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-0.04, 0), end: Offset.zero),
          weight: 1),
    ]).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _loadLockoutState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLockoutState() async {
    final secs = await AuthService.instance.getLockoutRemaining();
    final attempts = await AuthService.instance.getAttemptCount();

    if (mounted) {
      setState(() {
        _lockoutSeconds = secs;
        _failedAttempts = attempts;
      });
      if (secs > 0) {
        _startCountdown();
      } else {
        _focusNode.requestFocus();
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      final secs = await AuthService.instance.getLockoutRemaining();
      setState(() => _lockoutSeconds = secs);
      if (secs <= 0) {
        t.cancel();
        setState(() => _errorMessage = null);
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _verify() async {
    final entered = _controller.text.trim();
    if (entered.isEmpty || _isVerifying || _lockoutSeconds > 0) return;

    setState(() => _isVerifying = true);
    final result = await ref.read(authProvider.notifier).unlock(entered);
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop();
      return;
    }

    await _shakeController.forward(from: 0);
    _controller.clear();
    setState(() {
      _isVerifying = false;
      _failedAttempts = result.failedAttempts;
      if (result.locked) {
        _lockoutSeconds = result.lockoutSeconds;
        _errorMessage =
            'Too many attempts. Locked for ${_formatDuration(result.lockoutSeconds)}.';
        _startCountdown();
      } else {
        final next = 5 - _failedAttempts;
        _errorMessage = next > 0
            ? 'Incorrect password. $next attempt${next == 1 ? '' : 's'} before lockout.'
            : 'Incorrect password.';
        _focusNode.requestFocus();
      }
    });
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    }
    if (seconds >= 60) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds}s';
  }



  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primaryBlack,
        resizeToAvoidBottomInset: true,
        body: FadeTransition(
          opacity: _fadeController,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLockIcon(),
                    const SizedBox(height: 32),
                    _buildTitle(),
                    const SizedBox(height: 40),
                    _buildPasswordField(),
                    const SizedBox(height: 16),
                    _buildStatus(),
                    const SizedBox(height: 28),
                    _buildUnlockButton(),

                    const SizedBox(height: 16),
                    _buildForgotButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: const Icon(Icons.lock_outlined, size: 42, color: Colors.white),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          "TIMO'S ENGINEERING",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _lockoutSeconds > 0
              ? 'Locked – retry in ${_formatDuration(_lockoutSeconds)}'
              : 'Enter your password to continue',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return SlideTransition(
      position: _shakeAnimation,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        obscureText: _obscure,
        enabled: _lockoutSeconds == 0 && !_isVerifying,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, letterSpacing: 2),
        cursorColor: Colors.white70,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _verify(),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white54, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.white38,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _errorMessage != null
          ? Text(
              key: ValueKey(_errorMessage),
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 13),
            )
          : const SizedBox(key: ValueKey('empty'), height: 16),
    );
  }

  Widget _buildUnlockButton() {
    final locked = _lockoutSeconds > 0;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: locked || _isVerifying ? null : _verify,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryBlack,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white30,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isVerifying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryBlack),
              )
            : Text(
                locked
                    ? 'Locked (${_formatDuration(_lockoutSeconds)})'
                    : 'Unlock',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildForgotButton() {
    return TextButton(
      onPressed: _showForgotDialog,
      child: const Text('Forgot Password?',
          style: TextStyle(color: Colors.white54)),
    );
  }

  void _showForgotDialog() {
    final hintController = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          backgroundColor: AppColors.primaryBlack,
          title: const Text('Reset Password',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the recovery hint you provided during registration to reset your password securely.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hintController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Recovery Hint Answer',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (localError != null) ...[
                const SizedBox(height: 12),
                Text(localError!,
                    style: const TextStyle(
                        color: Color(0xFFFFCDD2), fontSize: 13)),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                final match = await AuthService.instance
                    .verifyPasswordHint(hintController.text);
                if (match) {
                  // Only wipe auth data (invoices are kept safe!)
                  await AuthService.instance.wipeAuth();
                  if (context.mounted) {
                    ref.read(authProvider.notifier).resetToSetup();
                    Navigator.of(context).pop(); // pop dialog
                    Navigator.of(context).pop(); // pop lock screen
                  }
                } else {
                  setStateBuilder(() =>
                      localError = 'Incorrect hint. Cannot reset password.');
                }
              },
              child: const Text('Verify & Reset',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
