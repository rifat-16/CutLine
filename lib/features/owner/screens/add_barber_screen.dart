import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/add_barber_provider.dart';
import 'package:cutline/features/owner/providers/salon_setup_provider.dart';
import 'package:cutline/features/owner/widgets/setup/add_barber_form.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddBarberScreen extends StatefulWidget {
  const AddBarberScreen({super.key});

  @override
  State<AddBarberScreen> createState() => _AddBarberScreenState();
}

class _AddBarberScreenState extends State<AddBarberScreen> {
  List<BarberInput> _barbers = [];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          AddBarberProvider(authProvider: context.read<AuthProvider>()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          title: const Text('Add barber'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Consumer<AddBarberProvider>(
          builder: (context, provider, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _FormSection(
                title: 'Barber account',
                helper:
                    'Share these credentials with your barbers. They will use this email and password to log into their dashboards.',
                children: [
                  AddBarberForm(
                    onChanged: (list) => setState(() => _barbers = list),
                  ),
                ],
              ),
              if (provider.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              _SubmitButton(
                onPressed: provider.isSaving ? null : () => _submit(provider),
                isLoading: provider.isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AddBarberProvider provider) async {
    if (_barbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in barber details first.')),
      );
      return;
    }
    final barber = _barbers.first;
    if (barber.name.trim().isEmpty ||
        barber.email.trim().isEmpty ||
        barber.password.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name, email, and password are required.')),
      );
      return;
    }

    final success = await provider.createBarber(input: barber);
    if (!mounted) return;
    if (success && provider.result != null) {
      Navigator.pop(context, provider.result);
    }
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final String? helper;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    this.helper,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 12))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(helper!, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SubmitButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: const Color(0xFF1D4ED8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 10),
          Text(isLoading ? 'Saving...' : 'Save & Invite',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
