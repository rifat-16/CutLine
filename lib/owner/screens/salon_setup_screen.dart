import 'package:cutline/owner/screens/owner_home_screen.dart';
import 'package:cutline/owner/utils/constants.dart';
import 'package:cutline/owner/widgets/service_input_field.dart';
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

  List<_SetupStep> get _steps => const [
        _SetupStep(
            label: 'Basics',
            icon: Icons.storefront_outlined,
            state: _StepState.done),
        _SetupStep(
            label: 'Hours',
            icon: Icons.schedule_outlined,
            state: _StepState.current),
        _SetupStep(
            label: 'Services',
            icon: Icons.design_services_outlined,
            state: _StepState.pending),
        _SetupStep(
            label: 'Photos',
            icon: Icons.photo_library_outlined,
            state: _StepState.pending),
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
                      _SetupHero(steps: _steps),
                      const SizedBox(height: 24),
                      _SectionCard(
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
                      _SectionCard(
                        icon: Icons.access_time,
                        title: 'Working Hours',
                        subtitle:
                            'Set daily availability so customers know when to book.',
                        child: _WorkingHoursSection(
                          workingHours: _workingHours,
                          onToggleOpen: (day, isOpen) {
                            setState(
                                () => _workingHours[day]!['open'] = isOpen);
                          },
                          onPickTime: _pickTime,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        icon: Icons.design_services,
                        title: 'Services Offered',
                        subtitle: 'Add your signature services and pricing.',
                        child: ServiceInputFieldList(
                            initialServices: kOwnerDefaultServices),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        icon: Icons.photo_camera_back_outlined,
                        title: 'Salon Photos',
                        subtitle:
                            'Upload a cover and gallery photos to inspire trust.',
                        child: const _PhotoManager(),
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        icon: Icons.people_alt_outlined,
                        title: 'Add Barbers',
                        subtitle:
                            'Barbers use these credentials to access their dashboards.',
                        child: const _AddBarberForm(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _BottomActionBar(onContinue: () => _submit(context)),
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

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _WorkingHoursSection extends StatelessWidget {
  final Map<String, Map<String, dynamic>> workingHours;
  final void Function(String day, bool open) onToggleOpen;
  final Future<void> Function(String day, bool isOpenTime) onPickTime;

  const _WorkingHoursSection({
    required this.workingHours,
    required this.onToggleOpen,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final entries = workingHours.entries.toList();
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries
              .map((entry) => _DayChip(
                    day: entry.key,
                    isOpen: entry.value['open'] as bool,
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        ...entries.map((entry) {
          final day = entry.key;
          final data = entry.value;
          final isOpen = data['open'] as bool;
          final openTime = data['openTime'] as TimeOfDay;
          final closeTime = data['closeTime'] as TimeOfDay;

          return AnimatedContainer(
            key: ValueKey(day),
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isOpen
                  ? const LinearGradient(
                      colors: [Color(0xFFE8F7EE), Color(0xFFF4FBF7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isOpen ? null : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOpen
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(day,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    _StatusBadge(isOpen: isOpen),
                    const SizedBox(width: 10),
                    Switch(
                      value: isOpen,
                      onChanged: (value) => onToggleOpen(day, value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: isOpen
                      ? Row(
                          key: ValueKey('$day-open'),
                          children: [
                            Expanded(
                              child: _TimePickerTile(
                                label: 'Opens',
                                time: openTime,
                                onPick: () => onPickTime(day, true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimePickerTile(
                                label: 'Closes',
                                time: closeTime,
                                onPick: () => onPickTime(day, false),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          key: ValueKey('$day-closed'),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Marked as closed',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  final bool isOpen;

  const _DayChip({required this.day, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOpen ? Icons.check_circle : Icons.pause_circle_filled,
              size: 16, color: isOpen ? Colors.green : Colors.grey),
          const SizedBox(width: 6),
          Text(
            day.substring(0, 3),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isOpen ? Colors.green.shade900 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;

  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final Color color = isOpen ? Colors.green : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style:
            TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onPick;

  const _TimePickerTile(
      {required this.label, required this.time, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final String formatted = time.format(context);
    final parts = formatted.split(' ');
    final String mainTime = parts.isNotEmpty ? parts.first : formatted;
    final String period = parts.length > 1 ? parts.last : '';
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: mainTime,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (period.isNotEmpty)
                          TextSpan(
                            text: ' $period',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _PhotoManager extends StatelessWidget {
  const _PhotoManager();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CoverUploadCard(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Gallery',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Manage library')),
          ],
        ),
        const SizedBox(height: 12),
        const _GalleryUploadField(),
      ],
    );
  }
}

class _CoverUploadCard extends StatelessWidget {
  const _CoverUploadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child:
                const Icon(Icons.image_outlined, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cover Photo',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 6),
                const Text('High-quality cover boosts bookings by 42%.',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload cover'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryUploadField extends StatelessWidget {
  const _GalleryUploadField();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
          color: Colors.blueAccent.withValues(alpha: 0.04),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                color: Colors.blueAccent.shade200, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Drop or select multiple gallery photos',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Max 10 files • JPG/PNG • 1200x800 recommended',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Upload gallery'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBarberForm extends StatefulWidget {
  const _AddBarberForm();

  @override
  State<_AddBarberForm> createState() => _AddBarberFormState();
}

class _AddBarberFormState extends State<_AddBarberForm> {
  final List<_BarberFieldData> _barbers = [];

  @override
  void initState() {
    super.initState();
    _addBarber();
  }

  @override
  void dispose() {
    for (final barber in _barbers) {
      barber.dispose();
    }
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );

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
    setState(() {
      _barbers.add(_BarberFieldData());
    });
  }

  void _removeBarber(int index) {
    setState(() {
      final removed = _barbers.removeAt(index);
      removed.dispose();
    });
  }
}

class _BarberCard extends StatefulWidget {
  final _BarberFieldData data;
  final InputDecoration Function(String, IconData) decorationBuilder;
  final VoidCallback? onRemove;

  const _BarberCard({
    required this.data,
    required this.decorationBuilder,
    this.onRemove,
  });

  @override
  State<_BarberCard> createState() => _BarberCardState();
}

class _BarberCardState extends State<_BarberCard> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.data.nameController,
                  decoration: widget.decorationBuilder(
                      'Barber name', Icons.person_outline),
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.data.emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: widget.decorationBuilder('Email', Icons.email_outlined),
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
                        color: Colors.grey.shade600),
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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
  }
}

class _SetupHero extends StatelessWidget {
  final List<_SetupStep> steps;

  const _SetupHero({required this.steps});

  @override
  Widget build(BuildContext context) {
    final completed =
        steps.where((step) => step.state == _StepState.done).length;
    final inProgress =
        steps.where((step) => step.state == _StepState.current).length;
    final progress = (completed + (inProgress * 0.5)) / steps.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Step ${completed + 1} of ${steps.length}',
                  style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'Need help?',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Let’s make your salon shine',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
              'Complete the essentials so customers can discover you in CutLine.',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: steps.map((step) => _StepChip(step: step)).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final _SetupStep step;

  const _StepChip({required this.step});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData iconData;
    switch (step.state) {
      case _StepState.done:
        bg = Colors.white;
        fg = Colors.green;
        iconData = Icons.check_circle;
        break;
      case _StepState.current:
        bg = Colors.white.withValues(alpha: 0.15);
        fg = Colors.white;
        iconData = step.icon;
        break;
      case _StepState.pending:
        bg = Colors.white.withValues(alpha: 0.08);
        fg = Colors.white70;
        iconData = step.icon;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(step.label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SetupStep {
  final String label;
  final IconData icon;
  final _StepState state;

  const _SetupStep(
      {required this.label, required this.icon, required this.state});
}

enum _StepState { done, current, pending }

class _BottomActionBar extends StatelessWidget {
  final VoidCallback onContinue;

  const _BottomActionBar({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Save & Continue',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
