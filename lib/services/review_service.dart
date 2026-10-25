import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_review.dart';
import 'storage_service.dart';

class PreparedReviewImage {
  final Uint8List bytes;
  final String extension;
  final String contentType;

  const PreparedReviewImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });
}

class ReviewService {
  static const int maxPhotos = 5;
  static const int maxBytes = 5 * 1024 * 1024;

  final SupabaseClient _client = Supabase.instance.client;
  final StorageService _storage = StorageService();

  void validateSource(XFile image) {
    final extension = image.name.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw Exception('Review photos must be JPG, PNG, or WebP files.');
    }
  }

  Future<PreparedReviewImage> prepareImage(XFile image) async {
    validateSource(image);
    final source = await image.readAsBytes();
    Uint8List compressed = await FlutterImageCompress.compressWithList(
      source,
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    for (final quality in const [70, 58, 46]) {
      if (compressed.lengthInBytes <= maxBytes) break;
      compressed = await FlutterImageCompress.compressWithList(
        source,
        minWidth: 1400,
        minHeight: 1400,
        quality: quality,
        format: CompressFormat.jpeg,
      );
    }
    if (compressed.lengthInBytes > maxBytes) {
      throw Exception('A compressed review photo is larger than 5 MB.');
    }
    return PreparedReviewImage(
      bytes: compressed,
      extension: 'jpg',
      contentType: 'image/jpeg',
    );
  }

  Future<StoredImageUpload> uploadReviewImage({
    required String orderItemId,
    required PreparedReviewImage image,
  }) => _storage.uploadBytes(
    bytes: image.bytes,
    bucket: 'review-images',
    folder: 'reviews/$orderItemId',
    extension: image.extension,
    contentType: image.contentType,
  );

  Future<void> submitReview({
    required String orderItemId,
    required int rating,
    required String comment,
    required List<StoredImageUpload> images,
  }) async {
    await _client.rpc(
      'submit_product_review',
      params: {
        'p_order_item_id': orderItemId,
        'p_rating': rating,
        'p_comment': comment.trim(),
        'p_image_urls': images.map((image) => image.url).toList(),
        'p_storage_paths': images.map((image) => image.path).toList(),
      },
    );
  }

  Future<void> removeUploads(List<StoredImageUpload> images) => _storage
      .removeFiles('review-images', images.map((image) => image.path).toList());

  Future<List<ProductReview>> getProductReviews({
    required String productId,
    int? rating,
    bool withPhotos = false,
  }) async {
    final rows = await _client.rpc(
      'get_product_reviews',
      params: {
        'p_product_id': productId,
        'p_rating': rating,
        'p_with_photos': withPhotos,
      },
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(ProductReview.fromMap)
        .toList();
  }
}
