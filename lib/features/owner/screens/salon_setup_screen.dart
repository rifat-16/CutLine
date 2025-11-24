import 'package:cutline/features/owner/screens/owner_home_screen.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/service_input_field.dart';
import 'package:cutline/features/owner/widgets/setup/add_barber_form.dart';
import 'package:cutline/features/owner/widgets/setup/photo_manager.dart';
import 'package:cutline/features/owner/widgets/setup/setup_bottom_action_bar.dart';
import 'package:cutline/features/owner/widgets/setup/setup_hero.dart';
import 'package:cutline/features/owner/widgets/setup/setup_section_card.dart';
import 'package:cutline/features/owner/widgets/setup/working_hours_section.dart';
import 'package:flutter/material.dart';

class SalonSetupScreen extends StatefulWidget {
  const SalonSetupScreen({super.key});

  @override
  State<SalonSetupScreen> createState() => _SalonSetupScreenState();
}

class _SalonSetupScreenState extends State<SalonSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: kOwnerSalonName);
  final _addressController = TextEditingController(text: kOwnerSalonAddress);
  final _contactController = TextEditingController(text: kOwnerSalonPhone);
  final _emailController = TextEditingController(text: kOwnerSalonEmail);

  late Map<String, Map<String, dynamic>> _workingHours;

  @override
  void initState() {
    super.initState();
    _workingHours = {
      'Monday': {
        'open': true,
        'openTime': const TimeOfDay(hour: 9, minute: 0),
        'closeTime': const TimeOfDay(hour: 21, minute: 0)
      },
      'Tuesday': {
        'open': true,
        'openTime': const TimeOfDay(hour: 9, minute: 0),
        'closeTime': const TimeOfDay(hour: 21, minute: 0)
      },
      'Wednesday': {
        'open': true,
        'openTime': const TimeOfDay(hour: 9, minute: 0),
        'closeTime': const TimeOfDay(hour: 21, minute: 0)
      },
      'Thursday': {
        'open': true,
        'openTime': const TimeOfDay(hour: 9, minute: 0),
        'closeTime': const TimeOfDay(hour: 21, minute: 0)
      },
      'Friday': {
        'open': true,
        'openTime': const TimeOfDay(hour: 9, minute: 0),
        'closeTime': const TimeOfDay(hour: 21, minute: 0)
      },
      'Saturday': {
        'open': true,
        'openTime': const TimeOfDay(hour: 10, minute: 0),
        'closeTime': const TimeOfDay(hour: 22, minute: 0)
      },
      'Sunday': {
        'open': false,
        'openTime': const TimeOfDay(hour: 10, minute: 0),
        'closeTime': const TimeOfDay(hour: 20, minute: 0)
      },
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  List<SalonSetupStep> get _steps => const [
        SalonSetupStep(
            label: 'Basics',
            icon: Icons.storefront_outlined,
            state: SalonSetupStepState.done),
        SalonSetupStep(
            label: 'Hours',
            icon: Icons.schedule_outlined,
            state: SalonSetupStepState.current),
        SalonSetupStep(
            label: 'Services',
            icon: Icons.design_services_outlined,
            state: SalonSetupStepState.pending),
        SalonSetupStep(
            label: 'Photos',
            icon: Icons.photo_library_outlined,
            state: SalonSetupStepState.pending),
      ];

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      hintStyle: const TextStyle(color: Colors.black45),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SalonSetupHero(steps: _steps),
                      const SizedBox(height: 24),
                      SetupSectionCard(
                        icon: Icons.store_outlined,
                        title: 'Salon Basics',
                        subtitle:
                            'Tell clients how they can find and contact you.',
                        child: Column(
                          children: [
                            TextFormField(
                                controller: _nameController,
                                decoration: _fieldDecoration(
                                    'Salon Name', Icons.badge_outlined)),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _addressController,
                                decoration: _fieldDecoration(
                                    'Address', Icons.location_on_outlined)),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contactController,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration(
                                  'Contact Number', Icons.phone_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldDecoration(
                                  'Email', Icons.email_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SetupSectionCard(
                        icon: Icons.access_time,
                        title: 'Working Hours',
                        subtitle:
                            'Set daily availability so customers know when to book.',
                        child: WorkingHoursSection(
                          workingHours: _workingHours,
                          onToggleOpen: (day, isOpen) {
                            setState(
                                () => _workingHours[day]!['open'] = isOpen);
                          },
                          onPickTime: _pickTime,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SetupSectionCard(
                        icon: Icons.design_services,
                        title: 'Services Offered',
                        subtitle: 'Add your signature services and pricing.',
                        child: ServiceInputFieldList(
                            initialServices: kOwnerDefaultServices),
                      ),
                      const SizedBox(height: 20),
                      SetupSectionCard(
                        icon: Icons.photo_camera_back_outlined,
                        title: 'Salon Photos',
                        subtitle:
                            'Upload a cover and gallery photos to inspire trust.',
                        child: const SalonPhotoManager(),
                      ),
                      const SizedBox(height: 20),
                      SetupSectionCard(
                        icon: Icons.people_alt_outlined,
                        title: 'Add Barbers',
                        subtitle:
                            'Barbers use these credentials to access their dashboards.',
                        child: const AddBarberForm(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SetupBottomActionBar(onContinue: () => _submit(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(String day, bool isOpenTime) async {
    final initial = isOpenTime
        ? _workingHours[day]!['openTime'] as TimeOfDay
        : _workingHours[day]!['closeTime'] as TimeOfDay;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _workingHours[day]!['openTime'] = picked;
        } else {
          _workingHours[day]!['closeTime'] = picked;
        }
      });
    }
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const OwnerHomeScreen()));
    }
  }
}
