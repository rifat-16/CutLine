import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../providers/salon_provider.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';

class SalonSetupScreen extends StatefulWidget {
  const SalonSetupScreen({super.key});

  @override
  State<SalonSetupScreen> createState() => _SalonSetupScreenState();
}

class _SalonSetupScreenState extends State<SalonSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  File? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    // TODO: Implement image picker
  }

  Future<void> _handleCreateSalon() async {
    if (!_formKey.currentState!.validate()) return;

    final salonProvider = Provider.of<SalonProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final salonId = await salonProvider.createSalon(
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      ownerId: authProvider.currentUser!.id,
      image: _selectedImage,
    );

    if (!mounted) return;

    if (salonId != null) {
      // Update user with salonId
      // TODO: Implement this
      
      Navigator.of(context).pushReplacementNamed(AppRoutes.ownerDashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(salonProvider.error ?? 'Failed to create salon'),
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
        title: const Text('Setup Your Salon'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _selectImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate, size: 40),
                              const SizedBox(height: 8),
                              const Text('Add Photo', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              CustomInput(
                label: 'Salon Name',
                hint: 'Enter salon name',
                controller: _nameController,
                validator: (value) => Validators.validateRequired(value, 'Salon name'),
              ),
              const SizedBox(height: 20),

              CustomInput(
                label: 'Location',
                hint: 'Enter salon location',
                controller: _locationController,
                validator: (value) => Validators.validateRequired(value, 'Location'),
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'Create Salon',
                onPressed: _handleCreateSalon,
                isLoading: salonProvider.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
