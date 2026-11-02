import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

enum _SetStep { create, confirm }

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _createController = TextEditingController();
  final _confirmController = TextEditingController();
  final _hintController = TextEditingController();
  final _createFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _hintFocus = FocusNode();

  _SetStep _step = _SetStep.create;
  bool _obscureCreate = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  late final AnimationController _shakeCtrl;
  late final Animation<Offset> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.04, 0), end: const Offset(0.04, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.04, 0), end: const Offset(-0.04, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.04, 0), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _createFocus.requestFocus());
  }

  @override
  void dispose() {
    _createController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    _createFocus.dispose();
    _confirmFocus.dispose();
    _hintFocus.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onCreateSubmit() {
    final password = _createController.text.trim();
    final error = AuthService.instance.validatePassword(password);
    if (error != null) {
      _shakeCtrl.forward(from: 0);
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _step = _SetStep.confirm;
      _errorMessage = null;
    });
    _confirmFocus.requestFocus();
  }

  Future<void> _onConfirmSubmit() async {
    final password = _createController.text.trim();
    final confirmed = _confirmController.text.trim();

    if (password != confirmed) {
      _shakeCtrl.forward(from: 0);
      _confirmController.clear();
      setState(() => _errorMessage = 'Passwords do not match. Please re-enter.');
      _confirmFocus.requestFocus();
      return;
    }

    final hint = _hintController.text.trim();
    if (hint.isEmpty) {
      _shakeCtrl.forward(from: 0);
      setState(() => _errorMessage = 'A recovery hint is mandatory.');
      _hintFocus.requestFocus();
      return;
    }

    setState(() => _isSaving = true);
    await AuthService.instance.setPassword(password, hint: _hintController.text.trim());
    if (mounted) {
      ref.read(authProvider.notifier).onPasswordSet();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primaryBlueDark,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(),
                  const SizedBox(height: 32),
                  _buildTitle(),
                  const SizedBox(height: 40),
                  _buildCreateField(),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _step == _SetStep.confirm
                        ? Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildConfirmField(),
                              const SizedBox(height: 16),
                              _buildHintField(),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  _buildStatus(),
                  const SizedBox(height: 28),
                  _buildHint(),
                  const SizedBox(height: 16),
                  _buildButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: const Icon(Icons.security_outlined, size: 42, color: Colors.white),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            key: ValueKey(_step),
            _step == _SetStep.create
                ? 'Set a password to protect your data'
                : 'Confirm your password',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateField() {
    return SlideTransition(
      position: _shakeAnim,
      child: _passwordTextField(
        controller: _createController,
        focusNode: _createFocus,
        hint: 'Create password',
        obscure: _obscureCreate,
        onToggle: () => setState(() => _obscureCreate = !_obscureCreate),
        onSubmit: _step == _SetStep.create ? _onCreateSubmit : null,
        enabled: !_isSaving,
      ),
    );
  }

  Widget _buildConfirmField() {
    return SlideTransition(
      position: _shakeAnim,
      child: _passwordTextField(
        controller: _confirmController,
        focusNode: _confirmFocus,
        hint: 'Confirm password',
        obscure: _obscureConfirm,
        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        onSubmit: null, // Let user tab to hint field instead of submit
        enabled: !_isSaving,
      ),
    );
  }

  Widget _buildHintField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _hintController,
          focusNode: _hintFocus,
          enabled: !_isSaving,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: Colors.white70,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _onConfirmSubmit(),
          decoration: InputDecoration(
            hintText: 'Recovery Hint Answer (Required)',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Important: This exact answer is the only way to recover your account without losing your data if you forget your password.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required VoidCallback? onSubmit,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: Colors.white70,
      textInputAction: onSubmit != null ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.white38,
          ),
          onPressed: onToggle,
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

  Widget _buildHint() {
    return Text(
      'Min 4 characters • Letters, numbers, or both',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving
            ? null
            : () {
                if (_step == _SetStep.create) {
                  _onCreateSubmit();
                } else {
                  _onConfirmSubmit();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryBlueDark,
          disabledBackgroundColor: Colors.white12,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlueDark),
              )
            : Text(
                _step == _SetStep.create ? 'Continue' : 'Set Password',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}
