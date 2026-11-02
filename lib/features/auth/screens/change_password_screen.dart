import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../services/auth_service.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

enum _ChangeStep { current, newPassword, confirm }

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  _ChangeStep _step = _ChangeStep.current;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isBusy = false;
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _currentFocus.requestFocus());
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyCurrent() async {
    final entered = _currentController.text.trim();
    if (entered.isEmpty) return;
    setState(() => _isBusy = true);
    final result = await AuthService.instance.verifyPassword(entered);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.success) {
      setState(() {
        _step = _ChangeStep.newPassword;
        _errorMessage = null;
      });
      _newFocus.requestFocus();
    } else if (result.locked) {
      _shakeCtrl.forward(from: 0);
      _currentController.clear();
      setState(() => _errorMessage = 'Too many attempts. Please wait before trying again.');
    } else {
      _shakeCtrl.forward(from: 0);
      _currentController.clear();
      setState(() => _errorMessage = 'Incorrect password. Please try again.');
      _currentFocus.requestFocus();
    }
  }

  void _validateNew() {
    final password = _newController.text.trim();
    final error = AuthService.instance.validatePassword(password);
    if (error != null) {
      _shakeCtrl.forward(from: 0);
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _step = _ChangeStep.confirm;
      _errorMessage = null;
    });
    _confirmFocus.requestFocus();
  }

  Future<void> _saveNew() async {
    final newPass = _newController.text.trim();
    final confirmed = _confirmController.text.trim();

    if (newPass != confirmed) {
      _shakeCtrl.forward(from: 0);
      _confirmController.clear();
      setState(() => _errorMessage = 'Passwords do not match. Please re-enter.');
      _confirmFocus.requestFocus();
      return;
    }

    setState(() => _isBusy = true);
    await AuthService.instance.setPassword(newPass);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Password changed successfully.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.of(context).pop();
  }

  void _handleAction() {
    switch (_step) {
      case _ChangeStep.current: _verifyCurrent();
      case _ChangeStep.newPassword: _validateNew();
      case _ChangeStep.confirm: _saveNew();
    }
  }

  String get _stepTitle {
    switch (_step) {
      case _ChangeStep.current: return 'Enter your current password';
      case _ChangeStep.newPassword: return 'Enter your new password';
      case _ChangeStep.confirm: return 'Confirm your new password';
    }
  }

  String get _buttonLabel {
    switch (_step) {
      case _ChangeStep.current: return 'Verify';
      case _ChangeStep.newPassword: return 'Continue';
      case _ChangeStep.confirm: return 'Change Password';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(),
                const SizedBox(height: 24),
                _buildStepTitle(),
                const SizedBox(height: 32),
                _buildFields(),
                const SizedBox(height: 16),
                _buildStatus(),
                const SizedBox(height: 16),
                _buildHint(),
                const SizedBox(height: 28),
                _buildButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: const Icon(Icons.lock_reset_outlined, size: 36, color: Colors.white),
    );
  }

  Widget _buildStepTitle() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        key: ValueKey(_step),
        _stepTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        SlideTransition(
          position: _shakeAnim,
          child: Column(
            children: [
              _textField(
                controller: _currentController,
                focusNode: _currentFocus,
                hint: 'Current password',
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                onSubmit: _step == _ChangeStep.current ? _verifyCurrent : null,
                enabled: _step == _ChangeStep.current && !_isBusy,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _step != _ChangeStep.current
                    ? Column(
                        children: [
                          const SizedBox(height: 16),
                          _textField(
                            controller: _newController,
                            focusNode: _newFocus,
                            hint: 'New password',
                            obscure: _obscureNew,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew),
                            onSubmit: _step == _ChangeStep.newPassword ? _validateNew : null,
                            enabled: _step == _ChangeStep.newPassword && !_isBusy,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _step == _ChangeStep.confirm
                    ? Column(
                        children: [
                          const SizedBox(height: 16),
                          _textField(
                            controller: _confirmController,
                            focusNode: _confirmFocus,
                            hint: 'Confirm new password',
                            obscure: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            onSubmit: _saveNew,
                            enabled: !_isBusy,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textField({
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
      textInputAction: TextInputAction.done,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
          : const SizedBox(key: ValueKey('empty'), height: 14),
    );
  }

  Widget _buildHint() {
    return Text(
      'Min 4 characters • Letters, numbers, or both',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isBusy ? null : _handleAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryBlack,
          disabledBackgroundColor: Colors.white12,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isBusy
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlack),
              )
            : Text(
                _buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}
