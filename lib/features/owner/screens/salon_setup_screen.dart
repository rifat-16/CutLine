import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/salon_setup_provider.dart';
import 'package:cutline/features/owner/widgets/service_input_field.dart';
import 'package:cutline/features/owner/widgets/setup/add_barber_form.dart';
import 'package:cutline/features/owner/widgets/setup/photo_manager.dart';
import 'package:cutline/features/owner/widgets/setup/setup_bottom_action_bar.dart';
import 'package:cutline/features/owner/widgets/setup/working_hours_section.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SalonSetupScreen extends StatefulWidget {
  const SalonSetupScreen({super.key});

  @override
  State<SalonSetupScreen> createState() => _SalonSetupScreenState();
}

class _SalonSetupScreenState extends State<SalonSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SalonSetupProvider(
        authProvider: context.read<AuthProvider>(),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: SafeArea(
          child: Consumer<SalonSetupProvider>(
            builder: (context, provider, _) {
              return Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StepHeader(provider: provider),
                                const SizedBox(height: 24),
                                _buildStepContent(provider),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SetupBottomActionBar(
                        onContinue: () => _handleStep(provider),
                        onBack: provider.currentStep == SetupStep.basics
                            ? null
                            : () => _handleBack(provider),
                        isLoading: provider.isSaving || _isProcessing,
                      ),
                    ],
                  ),
                  if (_isProcessing || provider.isSaving)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.05),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime(
      SalonSetupProvider provider, String day, bool isOpenTime) async {
    final initial = isOpenTime
        ? provider.workingHours[day]!['openTime'] as TimeOfDay
        : provider.workingHours[day]!['closeTime'] as TimeOfDay;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      if (isOpenTime) {
        provider.updateWorkingHours(day, openTime: picked);
      } else {
        provider.updateWorkingHours(day, closeTime: picked);
      }
    }
  }

  Widget _buildStepContent(SalonSetupProvider provider) {
    switch (provider.currentStep) {
      case SetupStep.basics:
        return _basicsSection();
      case SetupStep.hours:
        return _hoursSection(provider);
      case SetupStep.services:
        return _servicesSection(provider);
      case SetupStep.photos:
        return _photosSection(provider);
      case SetupStep.barbers:
        return _barbersSection(provider);
    }
  }

  Widget _basicsSection() {
    return _CardSection(
      icon: Icons.store_outlined,
      title: 'Salon Basics',
      subtitle: 'Tell clients how they can find and contact you.',
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _fieldDecoration('Salon Name', Icons.badge_outlined),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: _fieldDecoration('Address', Icons.location_on_outlined),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration:
                _fieldDecoration('Contact Number', Icons.phone_outlined),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration('Email', Icons.email_outlined),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Required';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _hoursSection(SalonSetupProvider provider) {
    return _CardSection(
      icon: Icons.access_time,
      title: 'Working Hours',
      subtitle: 'Set daily availability so customers know when to book.',
      child: WorkingHoursSection(
        workingHours: provider.workingHours,
        onToggleOpen: (day, isOpen) {
          provider.updateWorkingHours(day, open: isOpen);
        },
        onPickTime: (day, isOpenTime) => _pickTime(
          provider,
          day,
          isOpenTime,
        ),
      ),
    );
  }

  Widget _servicesSection(SalonSetupProvider provider) {
    return _CardSection(
      icon: Icons.design_services,
      title: 'Services Offered',
      subtitle: 'Add your signature services and pricing.',
      child: ServiceInputFieldList(
        initialServices: provider.services,
        onChanged: provider.updateServices,
      ),
    );
  }

  Widget _photosSection(SalonSetupProvider provider) {
    return _CardSection(
      icon: Icons.photo_camera_back_outlined,
      title: 'Salon Photos',
      subtitle:
          'Upload a cover and gallery photos to inspire trust. You can skip for now.',
      child: const SalonPhotoManager(),
    );
  }

  Widget _barbersSection(SalonSetupProvider provider) {
    return _CardSection(
      icon: Icons.people_alt_outlined,
      title: 'Add Barbers',
      subtitle: 'Barbers use these credentials to access their dashboards.',
      child: AddBarberForm(onChanged: provider.updateBarbers),
    );
  }

  Future<void> _handleStep(SalonSetupProvider provider) async {
    setState(() => _isProcessing = true);
    switch (provider.currentStep) {
      case SetupStep.basics:
        if (!(_formKey.currentState?.validate() ?? false)) {
          setState(() => _isProcessing = false);
          return;
        }
        provider.markCurrentComplete();
        provider.nextStep();
        setState(() => _isProcessing = false);
        break;
      case SetupStep.hours:
        provider.markCurrentComplete();
        provider.nextStep();
        setState(() => _isProcessing = false);
        break;
      case SetupStep.services:
        if (provider.services.isEmpty) {
          _showSnack('Add at least one service to continue.');
          setState(() => _isProcessing = false);
          return;
        }
        provider.markCurrentComplete();
        provider.nextStep();
        setState(() => _isProcessing = false);
        break;
      case SetupStep.photos:
        provider.markCurrentComplete();
        provider.goToStep(SetupStep.barbers);
        setState(() => _isProcessing = false);
        break;
      case SetupStep.barbers:
        await _saveAndFinish(provider);
        break;
    }
  }

  void _handleBack(SalonSetupProvider provider) {
    if (provider.currentStep == SetupStep.basics) return;
    setState(() => _isProcessing = true);
    provider.goToStep(SetupStep.values[provider.currentStep.index - 1]);
    setState(() => _isProcessing = false);
  }

  Future<void> _saveAndFinish(SalonSetupProvider provider) async {
    final success = await provider.saveSalon(
      name: _nameController.text,
      address: _addressController.text,
      contact: _contactController.text,
      email: _emailController.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.ownerHome,
        (_) => false,
      );
    } else if (provider.error != null) {
      _showSnack(provider.error!);
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
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
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.provider});

  final SalonSetupProvider provider;

  @override
  Widget build(BuildContext context) {
    final steps = SetupStep.values;
    final currentIndex = steps.indexOf(provider.currentStep);
    final progress = (currentIndex + 1) / steps.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step ${currentIndex + 1} of ${steps.length}',
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Complete each section to finish your salon setup.',
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white,
            color: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}
