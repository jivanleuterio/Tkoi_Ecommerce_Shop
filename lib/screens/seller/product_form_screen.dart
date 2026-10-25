import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/product.dart';
import '../../models/shop.dart';
import '../../services/product_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_visuals.dart';
import '../../utils/formatters.dart';
import '../../utils/fish_categories.dart';
import '../../utils/validators.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/safe_network_image.dart';
import '../../widgets/tkoi_button.dart';

class ProductFormScreen extends StatefulWidget {
  final Shop shop;
  final Product? product;

  const ProductFormScreen({super.key, required this.shop, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _species;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _quantity;
  late final TextEditingController _size;
  late final TextEditingController _age;
  late final TextEditingController _health;
  late final TextEditingController _location;
  late String _category;
  late String _sex;
  late String _status;
  List<XFile> _images = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name);
    _species = TextEditingController(text: product?.species);
    _description = TextEditingController(text: product?.description);
    _price = TextEditingController(text: product?.price.toStringAsFixed(2));
    _quantity = TextEditingController(
      text: product?.quantity.toString() ?? '1',
    );
    _size = TextEditingController(text: product?.size);
    _age = TextEditingController(text: product?.ageMonths?.toString());
    _health = TextEditingController(
      text: product?.healthCondition ?? 'Healthy',
    );
    _location = TextEditingController(
      text: product?.sellerLocation ?? widget.shop.location,
    );
    _category = product?.category ?? 'Koi';
    _sex = product?.sex ?? 'Unknown';
    _status = product?.status ?? 'available';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _species,
      _description,
      _price,
      _quantity,
      _size,
      _age,
      _health,
      _location,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final selected = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (selected.isNotEmpty) {
      setState(() => _images = selected.take(6).toList());
    }
  }

  void _removeSelectedImage(int index) {
    setState(() => _images = [..._images]..removeAt(index));
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    // Existing listings may use Tkoi's bundled fish visual when they do not
    // have an uploaded product_images row. Editing text or stock must not
    // force the seller to upload a replacement image.
    if (_images.isEmpty && widget.product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one fish image.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uploaded = <String>[];
      for (final image in _images) {
        uploaded.add(
          await StorageService().uploadImage(
            image: image,
            bucket: 'product-images',
            folder: 'listings',
          ),
        );
      }
      final quantity = int.parse(_quantity.text.trim());
      await ProductService().saveProduct(
        id: widget.product?.id,
        shopId: widget.shop.id,
        values: {
          'name': _name.text.trim(),
          'species': _species.text.trim(),
          'category': _category,
          'description': _description.text.trim(),
          'price': double.parse(_price.text.trim()),
          'quantity': quantity,
          'size': _size.text.trim(),
          'age_months': _age.text.trim().isEmpty
              ? null
              : int.parse(_age.text.trim()),
          'sex': _sex,
          'health_condition': _health.text.trim(),
          'seller_location': _location.text.trim(),
          'status': quantity == 0 ? 'sold_out' : _status,
        },
        newImageUrls: uploaded,
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

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator ?? (value) => Validators.text(value, label),
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit fish listing' : 'Add fish listing'),
      ),
      body: KoiBackdrop(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.waterGradient,
                      borderRadius: BorderRadius.circular(AppRadii.large),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.set_meal_rounded,
                            color: AppColors.koiOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                editing
                                    ? 'Update your listing'
                                    : 'Create a new listing',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Clear details help buyers choose confidently.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .78),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _field(
                    _name,
                    'Fish name',
                    maxLength: 100,
                    validator: (value) =>
                        Validators.text(value, 'Fish name', min: 2, max: 100),
                  ),
                  _field(
                    _species,
                    'Fish species',
                    maxLength: 100,
                    validator: (value) => Validators.text(
                      value,
                      'Fish species',
                      min: 2,
                      max: 100,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: fishCategories
                        .where((item) => item != 'All')
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _description,
                    'Description',
                    maxLines: 4,
                    maxLength: 2000,
                    validator: (value) => Validators.text(
                      value,
                      'Description',
                      min: 20,
                      max: 2000,
                    ),
                  ),
                  _field(
                    _price,
                    'Price',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: Validators.price,
                  ),
                  _field(
                    _quantity,
                    'Available quantity',
                    keyboardType: TextInputType.number,
                    validator: Validators.quantity,
                  ),
                  _field(
                    _size,
                    'Size (for example: 15 cm)',
                    maxLength: 50,
                    validator: (value) =>
                        Validators.text(value, 'Size', min: 2, max: 50),
                  ),
                  _field(
                    _age,
                    'Age in months (optional)',
                    keyboardType: TextInputType.number,
                    validator: Validators.age,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _sex,
                    decoration: const InputDecoration(labelText: 'Sex'),
                    items: const ['Male', 'Female', 'Unknown']
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _sex = value!),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _health,
                    'Health condition',
                    maxLines: 2,
                    maxLength: 300,
                    validator: (value) => Validators.text(
                      value,
                      'Health condition',
                      min: 5,
                      max: 300,
                    ),
                  ),
                  _field(
                    _location,
                    'Seller location',
                    maxLines: 2,
                    maxLength: 200,
                    validator: (value) => Validators.text(
                      value,
                      'Seller location',
                      min: 5,
                      max: 200,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Availability status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('Available'),
                      ),
                      DropdownMenuItem(
                        value: 'sold_out',
                        child: Text('Sold out'),
                      ),
                      DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
                    ],
                    onChanged: (value) => setState(() => _status = value!),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _images.isEmpty
                          ? editing
                                ? 'Add more fish images'
                                : 'Choose fish images'
                          : '${_images.length} image(s) selected',
                    ),
                  ),
                  if (_images.isNotEmpty || editing) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 104,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (editing && widget.product!.imageUrls.isNotEmpty)
                            for (final imageUrl in widget.product!.imageUrls)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: SafeNetworkImage(
                                  url: imageUrl,
                                  fallbackAsset: FishVisuals.forFish(
                                    category: _category,
                                    species: _species.text,
                                    name: _name.text,
                                  ),
                                  width: 104,
                                  height: 104,
                                ),
                              ),
                          if (editing && widget.product!.imageUrls.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.medium,
                                ),
                                child: Image.asset(
                                  FishVisuals.forFish(
                                    category: _category,
                                    species: _species.text,
                                    name: _name.text,
                                  ),
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          for (final entry in _images.indexed)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.medium,
                                    ),
                                    child: Image.file(
                                      File(entry.$2.path),
                                      width: 104,
                                      height: 104,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Material(
                                    color: Colors.black.withValues(alpha: .62),
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Remove selected image',
                                      onPressed: _saving
                                          ? null
                                          : () =>
                                                _removeSelectedImage(entry.$1),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.product!.imageUrls.isEmpty
                            ? 'The current Tkoi fish visual will be kept.'
                            : '${widget.product!.imageUrls.length} existing image(s) will be kept.',
                      ),
                    ),
                  const SizedBox(height: 22),
                  TkoiButton(
                    onPressed: _save,
                    loading: _saving,
                    icon: Icons.publish_rounded,
                    label: _saving ? 'Saving listing...' : 'Save listing',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
