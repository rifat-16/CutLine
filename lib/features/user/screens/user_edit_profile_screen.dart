import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserEditProfileScreen extends StatefulWidget {
  const UserEditProfileScreen({super.key});

  @override
  State<UserEditProfileScreen> createState() => _UserEditProfileScreenState();
}

class _UserEditProfileScreenState extends State<UserEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final profile = auth.profile;
    final user = auth.currentUser;
    _nameCtrl = TextEditingController(
        text: profile?.name.trim().isNotEmpty == true
            ? profile!.name.trim()
            : (user?.displayName ?? ''));
    _phoneCtrl = TextEditingController(
        text: profile?.phone?.trim().isNotEmpty == true
            ? profile!.phone!.trim()
            : (user?.phoneNumber ?? ''));
    _emailCtrl = TextEditingController(
        text: profile?.email.trim().isNotEmpty == true
            ? profile!.email.trim()
            : (user?.email ?? ''));

    for (final ctrl in [_nameCtrl, _phoneCtrl, _emailCtrl]) {
      ctrl.addListener(() => setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CutlineAppBar(title: 'Edit Profile', centerTitle: true),
      backgroundColor: CutlineColors.secondaryBackground,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: CutlineSpacing.section,
          children: [
            _LabeledField(
              label: 'Full name',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: CutlineSpacing.md),
            _LabeledField(
              label: 'Phone number',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: CutlineSpacing.md),
            _LabeledField(
              label: 'Email address',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Email is required' : null,
            ),
            const SizedBox(height: CutlineSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: CutlineButtons.primary(),
                onPressed: !_dirty || _saving ? null : _onSave,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 14)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
