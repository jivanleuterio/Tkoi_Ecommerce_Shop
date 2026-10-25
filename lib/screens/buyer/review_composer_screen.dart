import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/market_order.dart';
import '../../services/review_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/tkoi_button.dart';

class ReviewComposerScreen extends StatefulWidget {
  final OrderLine item;

  const ReviewComposerScreen({super.key, required this.item});

  @override
  State<ReviewComposerScreen> createState() => _ReviewComposerScreenState();
}

class _ReviewComposerScreenState extends State<ReviewComposerScreen> {
  final _comment = TextEditingController();
  final _picker = ImagePicker();
  final _service = ReviewService();
  final List<XFile> _photos = [];
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _addValidated(Iterable<XFile> images) {
    try {
      for (final image in images) {
        if (_photos.length >= ReviewService.maxPhotos) break;
        _service.validateSource(image);
        _photos.add(image);
      }
      setState(() {});
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  Future<void> _pickGallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 100);
    if (images.isNotEmpty) _addValidated(images);
  }

  Future<void> _takePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (image != null) _addValidated([image]);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final uploaded = <StoredImageUpload>[];
    try {
      for (final photo in _photos) {
        final prepared = await _service.prepareImage(photo);
        uploaded.add(
          await _service.uploadReviewImage(
            orderItemId: widget.item.id,
            image: prepared,
          ),
        );
      }
      await _service.submitReview(
        orderItemId: widget.item.id,
        rating: _rating,
        comment: _comment.text,
        images: uploaded,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      try {
        await _service.removeUploads(uploaded);
      } catch (_) {
        // The user-owned files can still be cleaned up from Supabase Storage.
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review purchased fish')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.item.productName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Your review helps other fish keepers buy confidently.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.softGray),
        ),
        const SizedBox(height: 24),
        const Text(
          'Rating',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            5,
            (index) => IconButton(
              tooltip: '${index + 1} stars',
              onPressed: _submitting
                  ? null
                  : () => setState(() => _rating = index + 1),
              icon: Icon(
                index < _rating ? Icons.star_rounded : Icons.star_border,
                color: AppColors.gold,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _comment,
          enabled: !_submitting,
          maxLength: 1000,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comment (optional)',
            hintText: 'Share the condition, quality, and delivery experience.',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _submitting || _photos.length >= ReviewService.maxPhotos
                    ? null
                    : _pickGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _submitting || _photos.length >= ReviewService.maxPhotos
                    ? null
                    : _takePhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_photos.length}/5 photos • JPG, PNG, or WebP • 5 MB after compression',
          style: const TextStyle(fontSize: 12, color: AppColors.softGray),
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    child: Image.file(
                      File(_photos[index].path),
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 3,
                    top: 3,
                    child: IconButton.filled(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      tooltip: 'Remove photo',
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _photos.removeAt(index)),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        TkoiButton(
          onPressed: _submitting ? null : _submit,
          loading: _submitting,
          icon: Icons.star_rounded,
          label: _submitting ? 'Uploading review...' : 'Submit review',
        ),
      ],
    ),
  );
}
