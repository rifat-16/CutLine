import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_password_change_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BarberChangePasswordScreen extends StatefulWidget {
  const BarberChangePasswordScreen({
    super.key,
    this.isRequired = true,
  });

  final bool isRequired;

  @override
  State<BarberChangePasswordScreen> createState() =>
      _BarberChangePasswordScreenState();
}

class _BarberChangePasswordScreenState
    extends State<BarberChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BarberPasswordChangeProvider(
        authProvider: context.read<AuthProvider>(),
      ),
      child: PopScope(
        canPop: !widget.isRequired,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.isRequired ? 'Set New Password' : 'Change Password',
            ),
            automaticallyImplyLeading: !widget.isRequired,
            actions: widget.isRequired
                ? [
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('Logout'),
                    ),
                  ]
                : null,
          ),
          body: Consumer<BarberPasswordChangeProvider>(
            builder: (context, provider, _) => SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_reset, color: Color(0xFF1D4ED8)),
                        const SizedBox(height: 12),
                        Text(
                          widget.isRequired
                              ? 'Change the temporary password before using the barber account.'
                              : 'Update your barber account password.',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isRequired
                              ? 'Use the password shared by the salon owner as the current password. After you set a new one, the owner will no longer see it.'
                              : 'For security, this password stays private after you save it.',
                          style: const TextStyle(
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _PasswordField(
                          controller: _currentPasswordController,
                          label: widget.isRequired
                              ? 'Temporary password'
                              : 'Current password',
                          isVisible: _showCurrentPassword,
                          onToggleVisibility: () => setState(
                            () => _showCurrentPassword = !_showCurrentPassword,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _PasswordField(
                          controller: _newPasswordController,
                          label: 'New password',
                          isVisible: _showNewPassword,
                          onToggleVisibility: () => setState(
                            () => _showNewPassword = !_showNewPassword,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _PasswordField(
                          controller: _confirmPasswordController,
                          label: 'Confirm new password',
                          isVisible: _showConfirmPassword,
                          onToggleVisibility: () => setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (provider.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          provider.isSaving ? null : () => _submit(provider),
                      child: provider.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isRequired
                                  ? 'Change Password & Continue'
                                  : 'Save New Password',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BarberPasswordChangeProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      _showSnack('Current password is required.');
      return;
    }
    if (newPassword.length < 6) {
      _showSnack('New password must be at least 6 characters.');
      return;
    }
    if (newPassword == currentPassword) {
      _showSnack('Choose a different password from the temporary one.');
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnack('New password and confirmation do not match.');
      return;
    }

    final success = await provider.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    if (!mounted || !success) return;

    if (widget.isRequired) {
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.barberHome,
        (_) => false,
      );
      return;
    }

    navigator.pop(true);
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    await auth.signOut();
    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.barberLogin,
      (_) => false,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.isVisible,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final String label;
  final bool isVisible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }
}
