import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_review.dart';
import '../services/review_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'safe_network_image.dart';
import 'report_button.dart';

class ProductReviewsSection extends StatefulWidget {
  final Product product;

  const ProductReviewsSection({super.key, required this.product});

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  int? _rating;
  bool _withPhotos = false;
  late Future<List<ProductReview>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ReviewService().getProductReviews(
      productId: widget.product.id,
      rating: _rating,
      withPhotos: _withPhotos,
    );
  }

  void _setFilters({int? rating, bool clearRating = false, bool? photos}) {
    setState(() {
      if (clearRating) {
        _rating = null;
      } else if (rating != null) {
        _rating = rating;
      }
      if (photos != null) _withPhotos = photos;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Buyer reviews',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            compactCount(widget.product.totalReviews),
            style: const TextStyle(
              color: AppColors.softGray,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (widget.product.totalReviews > 0)
        _RatingSummary(product: widget.product),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _rating == null,
              onSelected: (_) => _setFilters(clearRating: true),
            ),
            for (var rating = 5; rating >= 1; rating--) ...[
              const SizedBox(width: 7),
              ChoiceChip(
                avatar: const Icon(Icons.star_rounded, size: 16),
                label: Text('$rating'),
                selected: _rating == rating,
                onSelected: (_) => _setFilters(rating: rating),
              ),
            ],
            const SizedBox(width: 7),
            FilterChip(
              label: const Text('With photos'),
              selected: _withPhotos,
              onSelected: (value) => _setFilters(photos: value),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      FutureBuilder<List<ProductReview>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _InlineMessage(
              icon: Icons.error_outline_rounded,
              message: 'Reviews could not be loaded.',
              action: TextButton(
                onPressed: () => setState(() {
                  _load();
                }),
                child: const Text('Try again'),
              ),
            );
          }
          final reviews = snapshot.data ?? const [];
          if (reviews.isEmpty) {
            return const _InlineMessage(
              icon: Icons.rate_review_outlined,
              message: 'No reviews yet',
            );
          }
          return Column(
            children: [
              for (final review in reviews) ...[
                _ReviewCard(review: review),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _RatingSummary extends StatelessWidget {
  final Product product;

  const _RatingSummary({required this.product});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Column(
            children: [
              Text(
                product.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.sumi,
                ),
              ),
              const Icon(Icons.star_rounded, color: AppColors.gold),
              Text(
                '${compactCount(product.totalReviews)} reviews',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.softGray),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              for (var rating = 5; rating >= 1; rating--)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text('$rating', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: LinearProgressIndicator(
                          value:
                              (product.ratingCounts[rating] ?? 0) /
                              product.totalReviews,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.gold,
                          backgroundColor: AppColors.border,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 28,
                        child: Text(
                          compactCount(product.ratingCounts[rating] ?? 0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  final ProductReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SafeNetworkImage(
              url: review.buyerAvatar,
              width: 38,
              height: 38,
              borderRadius: BorderRadius.circular(19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.buyerName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(review.createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.softGray,
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(
              5,
              (index) => Icon(
                index < review.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 17,
                color: AppColors.gold,
              ),
            ),
            ReportButton(
              targetType: 'review',
              targetId: review.id,
              compact: true,
            ),
          ],
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(review.comment),
        ],
        if (review.images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: review.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) => InkWell(
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ReviewPhotoViewer(
                      urls: review.images.map((image) => image.url).toList(),
                      initialIndex: index,
                    ),
                  ),
                ),
                child: SafeNetworkImage(
                  url: review.images[index].url,
                  width: 78,
                  height: 78,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ReviewPhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _ReviewPhotoViewer({required this.urls, required this.initialIndex});

  @override
  State<_ReviewPhotoViewer> createState() => _ReviewPhotoViewerState();
}

class _ReviewPhotoViewerState extends State<_ReviewPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} / ${widget.urls.length}'),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.urls.length,
      onPageChanged: (value) => setState(() => _index = value),
      itemBuilder: (context, index) => InteractiveViewer(
        minScale: .8,
        maxScale: 4,
        child: Center(
          child: SafeNetworkImage(
            url: widget.urls[index],
            width: double.infinity,
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _InlineMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.mist,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.pondBlue),
        const SizedBox(height: 6),
        Text(message, style: const TextStyle(color: AppColors.softGray)),
        ?action,
      ],
    ),
  );
}
