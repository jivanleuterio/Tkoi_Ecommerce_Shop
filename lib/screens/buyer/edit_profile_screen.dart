import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/safe_network_image.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/current_location_button.dart';
import '../../widgets/tkoi_button.dart';

class EditProfileScreen extends StatefulWidget {
  final AppProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _username;
  late final TextEditingController _mobile;
  late final TextEditingController _address;
  XFile? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.profile.fullName);
    _username = TextEditingController(text: widget.profile.username);
    _mobile = TextEditingController(text: widget.profile.mobileNumber);
    _address = TextEditingController(text: widget.profile.address);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _mobile.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? avatarUrl;
      if (_image != null) {
        avatarUrl = await StorageService().uploadImage(
          image: _image!,
          bucket: 'profile-pictures',
          folder: 'avatars',
        );
      }
      await ProfileService().updateProfile(
        fullName: _fullName.text,
        username: _username.text,
        mobileNumber: _mobile.text,
        address: _address.text,
        avatarUrl: avatarUrl,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: KoiBackdrop(
        child: Form(
          key: _key,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          SafeNetworkImage(
                            url: widget.profile.avatarUrl,
                            width: 110,
                            height: 110,
                            borderRadius: BorderRadius.circular(55),
                          ),
                          IconButton.filled(
                            onPressed: () async {
                              final image = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 80,
                              );
                              if (image != null) setState(() => _image = image);
                            },
                            icon: Icon(
                              _image == null ? Icons.camera_alt : Icons.check,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_image != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'New photo selected',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _fullName,
                maxLength: 80,
                validator: Validators.personName,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                maxLength: 30,
                validator: Validators.username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                enabled: !AuthService().isPhoneVerified,
                maxLength: 16,
                validator: Validators.phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile number',
                  helperText: AuthService().isPhoneVerified
                      ? 'Verified numbers cannot be changed here.'
                      : 'You will verify this number before selling.',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                maxLength: 300,
                validator: Validators.address,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Complete address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: CurrentLocationButton(controller: _address),
                  helperText: 'Use GPS or enter your complete address.',
                ),
              ),
              const SizedBox(height: 20),
              TkoiButton(
                onPressed: _save,
                loading: _saving,
                icon: Icons.save_outlined,
                label: _saving ? 'Saving...' : 'Save profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
