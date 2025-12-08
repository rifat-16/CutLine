import 'dart:io';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_edit_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? _imageFile;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  bool _prefilled = false;
  bool _hasChanges = false;
  bool _isPrefilling = false;
  String _initialName = '';
  String _initialTitle = '';
  String _initialPhone = '';

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(_updateChangeFlag);
    titleCtrl.addListener(_updateChangeFlag);
    phoneCtrl.addListener(_updateChangeFlag);
  }

  @override
  void dispose() {
    nameCtrl
      ..removeListener(_updateChangeFlag)
      ..dispose();
    titleCtrl
      ..removeListener(_updateChangeFlag)
      ..dispose();
    phoneCtrl
      ..removeListener(_updateChangeFlag)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = BarberEditProfileProvider(
          authProvider: context.read<AuthProvider>(),
        );
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BarberEditProfileProvider>();
        _prefill(provider);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Edit Profile"),
            centerTitle: true,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (provider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _Avatar(
                              imageFile: _imageFile,
                              photoUrl: provider.photoUrl,
                              isUploading: provider.isUploadingPhoto,
                            ),
                            InkWell(
                              onTap: provider.isUploadingPhoto
                                  ? null
                                  : () => _pickImage(provider),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      _inputField("Full Name", nameCtrl),
                      const SizedBox(height: 15),
                      _inputField("Title", titleCtrl),
                      const SizedBox(height: 15),
                      _inputField("Phone Number", phoneCtrl,
                          keyboard: TextInputType.phone),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                          ),
                          onPressed: provider.isSaving ||
                                  provider.isUploadingPhoto ||
                                  !_hasChanges
                              ? null
                              : () => _save(provider),
                          child: provider.isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Save Changes",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      )
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  void _prefill(BarberEditProfileProvider provider) {
    if (_prefilled) return;
    final profile = provider.profile;
    if (profile == null) return;
    _isPrefilling = true;
    nameCtrl.text = profile.name;
    titleCtrl.text = profile.specialization;
    phoneCtrl.text = profile.phone;
    _initialName = profile.name;
    _initialTitle = profile.specialization;
    _initialPhone = profile.phone;
    _isPrefilling = false;
    _updateChangeFlag();
    _prefilled = true;
  }

  Future<void> _pickImage(BarberEditProfileProvider provider) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _imageFile = file;
    });
    final url = await provider.uploadProfilePhoto(file);
    if (!mounted) return;
    if (url == null && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _save(BarberEditProfileProvider provider) async {
    final success = await provider.save(
      name: nameCtrl.text,
      specialization: titleCtrl.text,
      phone: phoneCtrl.text,
    );
    if (!mounted) return;
    if (success) {
      _initialName = nameCtrl.text;
      _initialTitle = titleCtrl.text;
      _initialPhone = phoneCtrl.text;
      _updateChangeFlag();
      Navigator.pop(context, true);
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  void _updateChangeFlag() {
    if (_isPrefilling) return;
    final changed = nameCtrl.text != _initialName ||
        titleCtrl.text != _initialTitle ||
        phoneCtrl.text != _initialPhone;
    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }
}

class _Avatar extends StatelessWidget {
  final File? imageFile;
  final String? photoUrl;
  final bool isUploading;

  const _Avatar({
    required this.imageFile,
    required this.photoUrl,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (imageFile != null) {
      avatarImage = FileImage(imageFile!);
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(photoUrl!);
    }
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: avatarImage,
          child: avatarImage == null
              ? const Icon(Icons.person, size: 60, color: Colors.white)
              : null,
        ),
        if (isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
