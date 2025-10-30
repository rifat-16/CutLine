import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/salon_provider.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';

class AddBarberScreen extends StatefulWidget {
  const AddBarberScreen({super.key});

  @override
  State<AddBarberScreen> createState() => _AddBarberScreenState();
}

class _AddBarberScreenState extends State<AddBarberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleAddBarber() async {
    if (!_formKey.currentState!.validate()) return;

    final salonProvider = Provider.of<SalonProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final salon = salonProvider.currentSalon;

    if (salon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No salon found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Create auth account for barber first
    // For now, use a temporary ID
    final barberId = 'temp_barber_id_${DateTime.now().millisecondsSinceEpoch}';

    final success = await salonProvider.addBarber(
      salonId: salon.id,
      barberId: barberId,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      image: null,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barber added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(salonProvider.error ?? 'Failed to add barber'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final salonProvider = Provider.of<SalonProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Barber'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomInput(
                label: 'Barber Name',
                hint: 'Enter barber name',
                controller: _nameController,
                validator: Validators.validateName,
              ),
              const SizedBox(height: 20),

              CustomInput(
                label: 'Phone',
                hint: 'Enter phone number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: 20),

              CustomInput(
                label: 'Email',
                hint: 'Enter email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.validateEmail,
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'Add Barber',
                onPressed: _handleAddBarber,
                isLoading: salonProvider.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
