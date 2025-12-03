import 'package:flutter/material.dart';
import 'package:cutline/features/owner/providers/salon_setup_provider.dart';

class AddBarberForm extends StatefulWidget {
  const AddBarberForm({super.key, this.onChanged});

  final ValueChanged<List<BarberInput>>? onChanged;

  @override
  State<AddBarberForm> createState() => _AddBarberFormState();
}

class _AddBarberFormState extends State<AddBarberForm> {
  final List<_BarberFieldData> _barbers = [];

  @override
  void initState() {
    super.initState();
    _addBarber();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onChanged?.call(_collect()));
  }

  @override
  void dispose() {
    for (final barber in _barbers) {
      barber.dispose();
    }
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.blueAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Share these credentials with your barbers. They will use this email and password to log into their dashboards.',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._barbers.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _BarberCard(
              data: data,
              decorationBuilder: _inputDecoration,
              onRemove: _barbers.length > 1 ? () => _removeBarber(index) : null,
              onChanged: () =>
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onChanged?.call(_collect());
              }),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addBarber,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add another barber'),
          ),
        ),
      ],
    );
  }

  void _addBarber() {
    setState(() => _barbers.add(_BarberFieldData()));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onChanged?.call(_collect()));
  }

  void _removeBarber(int index) {
    setState(() {
      final removed = _barbers.removeAt(index);
      removed.dispose();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onChanged?.call(_collect()));
  }

  List<BarberInput> _collect() {
    return _barbers
        .map((b) => BarberInput(
              name: b.nameController.text,
              specialization: b.specializationController.text,
              email: b.emailController.text,
              phone: b.phoneController.text,
              password: b.passwordController.text,
            ))
        .where((b) =>
            b.email.trim().isNotEmpty &&
            b.password.trim().isNotEmpty &&
            b.name.trim().isNotEmpty)
        .toList();
  }
}

class _BarberCard extends StatefulWidget {
  final _BarberFieldData data;
  final InputDecoration Function(String label, IconData icon) decorationBuilder;
  final VoidCallback? onRemove;
  final VoidCallback? onChanged;

  const _BarberCard({
    required this.data,
    required this.decorationBuilder,
    this.onRemove,
    this.onChanged,
  });

  @override
  State<_BarberCard> createState() => _BarberCardState();
}

class _BarberCardState extends State<_BarberCard> {
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    widget.data.nameController.addListener(_emit);
    widget.data.specializationController.addListener(_emit);
    widget.data.emailController.addListener(_emit);
    widget.data.phoneController.addListener(_emit);
    widget.data.passwordController.addListener(_emit);
  }

  void _emit() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onChanged?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Barber account',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (widget.onRemove != null)
                IconButton(
                  onPressed: widget.onRemove,
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.data.nameController,
            decoration:
                widget.decorationBuilder('Full name', Icons.person_outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.data.specializationController,
            decoration:
                widget.decorationBuilder('Specialist', Icons.cut_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.data.emailController,
            keyboardType: TextInputType.emailAddress,
            decoration:
                widget.decorationBuilder('Email address', Icons.email_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.data.phoneController,
            keyboardType: TextInputType.phone,
            decoration:
                widget.decorationBuilder('Phone number', Icons.phone_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.data.passwordController,
            obscureText: !_showPassword,
            decoration: widget
                .decorationBuilder('Password', Icons.lock_outline)
                .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _BarberFieldData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController specializationController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void dispose() {
    nameController.dispose();
    specializationController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
  }
}
