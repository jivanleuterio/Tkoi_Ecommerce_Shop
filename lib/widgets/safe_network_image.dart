import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final String? fallbackAsset;

  const SafeNetworkImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(gradient: AppColors.creamGradient),
      child: const Center(
        child: Icon(
          Icons.set_meal_rounded,
          size: 42,
          color: AppColors.pondBlue,
        ),
      ),
    );

    final fallback = fallbackAsset == null
        ? placeholder
        : Image.asset(
            fallbackAsset!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => placeholder,
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(
              url!,
              width: width,
              height: height,
              fit: fit,
              frameBuilder: (context, child, frame, syncLoaded) {
                if (syncLoaded || frame != null) return child;
                return placeholder;
              },
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
