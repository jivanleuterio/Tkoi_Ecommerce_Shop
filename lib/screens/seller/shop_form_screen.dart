import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/shop.dart';
import '../../services/shop_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/safe_network_image.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/cart_action.dart';
import '../../widgets/current_location_button.dart';
import '../../widgets/tkoi_button.dart';

class ShopFormScreen extends StatefulWidget {
  final Shop? shop;
  final VoidCallback? onSaved;

  const ShopFormScreen({super.key, this.shop, this.onSaved});

  @override
  State<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends State<ShopFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _ownerName;
  late final TextEditingController _description;
  late final TextEditingController _contact;
  late final TextEditingController _email;
  late final TextEditingController _location;
  XFile? _logo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final shop = widget.shop;
    _name = TextEditingController(text: shop?.name);
    _ownerName = TextEditingController(text: shop?.ownerName);
    _description = TextEditingController(text: shop?.description);
    _contact = TextEditingController(text: shop?.contactNumber);
    _email = TextEditingController(text: shop?.email);
    _location = TextEditingController(text: shop?.location);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _ownerName,
      _description,
      _contact,
      _email,
      _location,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? logoUrl;
      if (_logo != null) {
        logoUrl = await StorageService().uploadImage(
          image: _logo!,
          bucket: 'shop-logos',
          folder: 'logos',
        );
      }
      await ShopService().saveShop(
        id: widget.shop?.id,
        name: _name.text,
        ownerName: _ownerName.text,
        description: _description.text,
        contactNumber: _contact.text,
        email: _email.text,
        location: _location.text,
        logoUrl: logoUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.shop == null ? 'Shop created.' : 'Shop updated.',
          ),
        ),
      );
      widget.onSaved?.call();
      if (widget.shop != null) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator ?? (value) => Validators.text(value, label),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          helperText: helperText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.shop != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit shop' : 'Start selling'),
        actions: const [CartAction(), SizedBox(width: 6)],
      ),
      body: KoiBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: TkoiFormCard(
                child: Form(
                  key: _key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!editing) ...[
                        const Icon(
                          Icons.storefront_rounded,
                          size: 70,
                          color: AppColors.koiOrange,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your fish shop',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Every Tkoi account can buy and sell. You can create one shop.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                      ],
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            SafeNetworkImage(
                              url: widget.shop?.logoUrl,
                              width: 100,
                              height: 100,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            IconButton.filled(
                              onPressed: () async {
                                final selected = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                );
                                if (selected != null) {
                                  setState(() => _logo = selected);
                                }
                              },
                              icon: Icon(
                                _logo == null ? Icons.add_a_photo : Icons.check,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _field(
                        _name,
                        'Shop name',
                        maxLength: 80,
                        validator: (value) => Validators.text(
                          value,
                          'Shop name',
                          min: 3,
                          max: 80,
                        ),
                      ),
                      _field(
                        _ownerName,
                        "Owner's name",
                        maxLength: 80,
                        validator: (value) =>
                            Validators.personName(value, label: "Owner's name"),
                      ),
                      _field(
                        _description,
                        'Shop description',
                        maxLines: 4,
                        maxLength: 1000,
                        validator: (value) => Validators.text(
                          value,
                          'Shop description',
                          min: 20,
                          max: 1000,
                        ),
                      ),
                      _field(
                        _contact,
                        'Contact number',
                        keyboardType: TextInputType.phone,
                        maxLength: 16,
                        validator: Validators.phone,
                      ),
                      _field(
                        _email,
                        'Email address',
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 254,
                        validator: Validators.email,
                      ),
                      _field(
                        _location,
                        'Shop location',
                        maxLines: 2,
                        maxLength: 200,
                        validator: (value) => Validators.text(
                          value,
                          'Shop location',
                          min: 5,
                          max: 200,
                        ),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: CurrentLocationButton(
                          controller: _location,
                          maxLength: 200,
                        ),
                        helperText: 'Use GPS or enter the shop address.',
                      ),
                      const SizedBox(height: 8),
                      TkoiButton(
                        onPressed: _save,
                        loading: _saving,
                        icon: Icons.storefront_rounded,
                        label: _saving
                            ? 'Saving...'
                            : editing
                            ? 'Save changes'
                            : 'Create shop',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
